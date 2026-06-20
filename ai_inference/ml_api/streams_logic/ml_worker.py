"""
ML Worker Process  with YOLO .track(persist=True) and identity caching.
-------------------------------------------------------------------------
Key upgrades over the previous version:

1.  YOLO Tracking  (.track(persist=True))
    Instead of model(frame) which gives nameless boxes, we now call:
        person_model.track(small, persist=True, classes=[0])
    YOLO gives each person a stable integer ID (e.g. ID=7) that persists
    across frames as long as the person stays visible.  When they leave
    and re-enter, a new ID is assigned  but while they are in frame they
    are always "person 7", never flickering.

2.  _try_assign_identity()  (face recognition runs once per person)
    _identity_cache maps  track_id  label string.
    The first time we see a new track_id we run face recognition.
    Every frame after that we just do dict[track_id]  instant lookup.
    Face recognition never runs redundantly on an already-identified person.

3.  alert_queue  (cross-process alert delivery)
    Whenever a notable event occurs the worker drops a dict into
    alert_queue.  The stream router thread drains this queue and serves
    it via  GET /stream/alerts  so the frontend can poll every 2 s.
    Alerts are throttled per-track/per-event with a _alert_cooldown dict
    so they never spam (same event fires at most once every 30 s).
"""

from __future__ import annotations

import multiprocessing as _mp
import queue
import time
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
from shapely.geometry import Polygon


def _box_center(x1, y1, x2, y2) -> Tuple[float, float]:
    return (x1 + x2) / 2.0, (y1 + y2) / 2.0


def _scale_xyxy(x1: float, y1: float, x2: float, y2: float, sx: float, sy: float) -> Tuple[int, int, int, int]:
    """Scale a box from inference-space back to original frame space."""
    return (
        int(round(x1 / sx)),
        int(round(y1 / sy)),
        int(round(x2 / sx)),
        int(round(y2 / sy)),
    )


def _pad_bbox(bbox: Tuple[int, int, int, int], frame_shape: Tuple[int, int, int], pad_ratio: float = 0.25) -> Tuple[int, int, int, int]:
    x1, y1, x2, y2 = bbox
    frame_h, frame_w = frame_shape[:2]
    box_w = max(1, x2 - x1)
    box_h = max(1, y2 - y1)
    pad_x = int(box_w * pad_ratio)
    pad_y = int(box_h * pad_ratio)
    return (
        max(0, x1 - pad_x),
        max(0, y1 - pad_y),
        min(frame_w, x2 + pad_x),
        min(frame_h, y2 + pad_y),
    )


def _apply_motion_smoothing(track_id: int, current_bbox: Tuple[int, int, int, int], frame_shape: Tuple[int, int, int]) -> Tuple[int, int, int, int]:
    """Apply velocity-based Kalman-like smoothing to reduce perceived box lag."""
    if not hasattr(_apply_motion_smoothing, '_track_history'):
        _apply_motion_smoothing._track_history = {}
    
    history = _apply_motion_smoothing._track_history
    frame_h, frame_w = frame_shape[:2]
    
    if track_id not in history:
        history[track_id] = {'prev': current_bbox, 'smoothed': current_bbox, 'velocity': (0, 0, 0, 0)}
    
    # Compute velocity from previous to current
    prev_x1, prev_y1, prev_x2, prev_y2 = history[track_id]['prev']
    curr_x1, curr_y1, curr_x2, curr_y2 = current_bbox
    vx1, vy1, vx2, vy2 = (curr_x1 - prev_x1) * 0.7, (curr_y1 - prev_y1) * 0.7, (curr_x2 - prev_x2) * 0.7, (curr_y2 - prev_y2) * 0.7
    
    # Blend: 70% new detection, 30% predicted from velocity
    smoothed = tuple(int(c + v * 0.3) for c, v in zip(current_bbox, (vx1, vy1, vx2, vy2)))
    smoothed = (max(0, smoothed[0]), max(0, smoothed[1]), min(frame_w, smoothed[2]), min(frame_h, smoothed[3]))
    
    history[track_id] = {'prev': current_bbox, 'smoothed': smoothed, 'velocity': (vx1, vy1, vx2, vy2)}
    return smoothed


def _bbox_iou(a: Tuple[int, int, int, int], b: Tuple[int, int, int, int]) -> float:
    """Compute IoU between two xyxy boxes."""
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0, ix2 - ix1), max(0, iy2 - iy1)
    inter = float(iw * ih)
    if inter <= 0:
        return 0.0
    a_area = float(max(0, ax2 - ax1) * max(0, ay2 - ay1))
    b_area = float(max(0, bx2 - bx1) * max(0, by2 - by1))
    union = a_area + b_area - inter
    if union <= 0:
        return 0.0
    return inter / union


# ---------------------------------------------------------------------------
# Worker entry-point
# ---------------------------------------------------------------------------

def worker_fn(
    frame_queue:   _mp.Queue,
    result_queue:  _mp.Queue,
    flags_dict,                # multiprocessing Manager dict
    safe_zone_pts,             # multiprocessing Manager list
    alert_queue:   _mp.Queue,  # alert delivery to stream process
):
    """
    Long-running ML inference loop.  Runs in a child process.

            if best_label == "Unknown" and _track_fail_hits.get(track_id, 0) >= _UNAUTH_HITS_REQUIRED:
                _identity_cache[track_id] = "Unknown (UNAUTHORIZED)"
                _identity_hold_until[track_id] = time.time() + _IDENTITY_HOLD_SECONDS
                print(f" Track #{track_id} locked  'Unknown (UNAUTHORIZED)' after {_track_fail_hits[track_id]} Unknown hits")
                return "Unknown (UNAUTHORIZED)"
    safe_zone_pts : shared list  safe zone polygon [(x,y), ...]
    alert_queue   : shared queue  alert dicts pushed to frontend via /stream/alerts
    """
    import os as _os
    import sys as _sys

    _root = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))
    if _root not in _sys.path:
        _sys.path.insert(0, _root)

    print(f" ML worker process started (PID {_os.getpid()})")

    # ------------------------------------------------------------------
    # Import heavy libs inside the child process only
    # ------------------------------------------------------------------
    try:
        from models_logic.face_recognition import (
            FaceTrackManager,
            reset_face_tracker,
        )
    except Exception as e:
        print(f"    Face tracking module unavailable, using fallback tracker: {e}")

        class _FallbackTrack:
            def __init__(self, track_id: int, bbox: Tuple[int, int, int, int]):
                self.track_id = track_id
                self.bbox = bbox
                self.missed_frames = 0

        class FaceTrackManager:  # type: ignore[no-redef]
            def __init__(self):
                self._next_id = 1
                self.tracks: Dict[int, _FallbackTrack] = {}

            @staticmethod
            def _center(bbox: Tuple[int, int, int, int]) -> Tuple[float, float]:
                x1, y1, x2, y2 = bbox
                return (x1 + x2) / 2.0, (y1 + y2) / 2.0

            def _match(self, bbox: Tuple[int, int, int, int], used: set) -> Optional[int]:
                cx, cy = self._center(bbox)
                best_id = None
                best_dist = float("inf")
                for tid, track in self.tracks.items():
                    if tid in used:
                        continue
                    tcx, tcy = self._center(track.bbox)
                    dist = float(np.hypot(cx - tcx, cy - tcy))
                    if dist < best_dist and dist <= 80:
                        best_dist = dist
                        best_id = tid
                return best_id

            def update(self, detections: List[Tuple[int, int, int, int]]) -> List[Any]:
                used = set()
                out = []
                for bbox in detections:
                    tid = self._match(bbox, used)
                    if tid is None:
                        tid = self._next_id
                        self._next_id += 1
                        self.tracks[tid] = _FallbackTrack(tid, bbox)
                    else:
                        self.tracks[tid].bbox = bbox
                        self.tracks[tid].missed_frames = 0
                    used.add(tid)
                    out.append(self.tracks[tid])

                stale = []
                for tid, track in self.tracks.items():
                    if tid not in used:
                        track.missed_frames += 1
                        if track.missed_frames > 15:
                            stale.append(tid)
                for tid in stale:
                    self.tracks.pop(tid, None)
                return out

            def reset(self):
                self._next_id = 1
                self.tracks.clear()

        def reset_face_tracker():  # type: ignore[no-redef]
            return None

    try:
        from models_logic.insightface_recognition import (
            load_known_embeddings as load_insightface_known_embeddings,
            load_embeddings_from_file as load_insightface_embeddings_from_file,
        )
    except Exception as e:
        print(f"    InsightFace module unavailable, disabling face recognition: {e}")

        def load_insightface_known_embeddings():  # type: ignore[no-redef]
            return [], np.array([]), None

        def load_insightface_embeddings_from_file():  # type: ignore[no-redef]
            return [], np.array([]), None
    from models_logic.safe_zone import load_yolo_model as load_person_model
    from models_logic.fire_smoke_detector import load_fire_smoke_model
    from models_logic.helmet_detector import load_helmet_model
    from utils.config import (
        ALERT_COOLDOWN_SECONDS,
        INSIGHTFACE_AUTH_HIT_THRESHOLD,
        INSIGHTFACE_SIMILARITY_THRESHOLD,
        INSIGHTFACE_SIMILARITY_THRESHOLD_SMALL_FACE,
        INSIGHTFACE_UNAUTH_HIT_THRESHOLD,
        ML_INFERENCE_SIZE,
        YOLO_PERSON_MODEL,
    )
    from ultralytics import YOLO

    # ------------------------------------------------------------------
    # Load models once
    # ------------------------------------------------------------------
    print(" ML worker: loading models...")

    try:
        person_model = YOLO(YOLO_PERSON_MODEL)
        print("    Person YOLO model loaded")
    except Exception as e:
        print(f"    Person YOLO failed: {e}")
        person_model = None

    try:
        reset_face_tracker()
        print("    Face track manager initialized")
    except Exception as e:
        print(f"    Face track manager failed: {e}")

    try:
        insightface_names, insightface_embs, insightface_app = load_insightface_embeddings_from_file()
        if insightface_app is None:
            insightface_names, insightface_embs, insightface_app = load_insightface_known_embeddings()
        print(f"    InsightFace recognition loaded ({len(insightface_names)} known identities)")
    except Exception as e:
        print(f"    InsightFace recognition failed: {e}")
        insightface_names, insightface_embs, insightface_app = [], np.array([]), None

    try:
        fs_model = load_fire_smoke_model()
        print("    Fire/smoke model loaded" if fs_model else "    Fire/smoke model not found")
    except Exception as e:
        print(f"    Fire/smoke failed: {e}")
        fs_model = None

    try:
        helmet_model = load_helmet_model()
        print("    Helmet model loaded" if helmet_model else "    Helmet model not found")
    except Exception as e:
        print(f"    Helmet model failed: {e}")
        helmet_model = None

    print(" ML worker: all models ready. Warming up inference engines...")

    # ------------------------------------------------------------------
    # Model warm-up  run one dummy inference on each loaded model to
    # trigger TensorFlow/YOLO JIT compilation NOW, not on the first real
    # frame.  Eliminates the 3-4s lag when a model is first toggled on.
    # ------------------------------------------------------------------
    try:
        import torch as _torch
        _dummy_frame = np.zeros((416, 416, 3), dtype=np.uint8)

        if person_model is not None:
            person_model(_dummy_frame, verbose=False, classes=[0])
            print("    Person YOLO warmed up")

        if fs_model is not None:
            fs_model(_dummy_frame, verbose=False)
            print("    Fire/smoke model warmed up")

    except Exception as _warm_err:
        print(f"    Warm-up error (non-fatal): {_warm_err}")

    print(" ML worker: warm-up complete. Entering inference loop.")


    # ------------------------------------------------------------------
    # Per-session state (reset when stream restarts)
    # ------------------------------------------------------------------

    # track_id  label str  e.g. {7: "Teacher_Sara (AUTHORIZED)", 3: "Unknown"}
    _identity_cache: Dict[int, str] = {}

    # track_id  {label: hit_count}
    _track_hits: Dict[int, Dict[str, int]] = {}

    # track_id  number of consecutive Unknown outcomes
    _track_fail_hits: Dict[int, int] = {}
    
    # track_id  total number of frames we TRIED to run face rec on them
    _track_attempts: Dict[int, int] = {}
    
    _MAX_FACE_ATTEMPTS = 120  # ~4 s at 30 fps  enough time even when person turns away
    _HITS_REQUIRED = 5         # reduce from 6 to 5 for even faster lock-in
    _UNAUTH_HITS_REQUIRED = 20
    _IDENTITY_HOLD_SECONDS = 1.5  # keep AUTHORIZED labels stable briefly before retrying
    _UNKNOWN_IDENTITY_HOLD_SECONDS = 6.0  # keep Unknown locked longer before retrying

    # track_id  timestamp until which the current label should be kept
    _identity_hold_until: Dict[int, float] = {}

    # Re-validation constants
    _REVALIDATE_EVERY_N_FRAMES = 10   # revalidate every 10 frames (~0.33 s at 30 fps) instead of 15 for better drift detection
    _REVOKE_STRIKES_NEEDED     = 2    # 2 consecutive confirmed mismatches to revoke lock (faster correction)

    # track_id  frame index of last revalidation attempt
    _track_last_revalidated: Dict[int, int] = {}
    # track_id  number of consecutive revalidation mismatches
    _track_revalidation_strikes: Dict[int, int] = {}

    # alert cooldown: (event_key)  last_fired_timestamp
    _alert_cooldown: Dict[str, float] = {}

    # missed-frame counters per track_id  used to prune caches for people who left frame
    _track_missed: Dict[int, int] = {}

    # Set of names that have already been AUTHORIZED in this session.
    # When a re-entering person matches one of these names on their first
    # confident hit, they are immediately locked  skipping the full 30-hit wait.
    _authorized_names: set = set()

    # name  track_id that currently "owns" that identity.
    # Prevents two different track IDs from being labelled the same person
    # simultaneously.  The slot is freed when the owning track is pruned.
    _name_to_track: Dict[str, int] = {}

    # Fire/Smoke persistence state
    # label  timestamp when label FIRST exceeded its confidence threshold
    # Cleared if confidence drops below threshold; alert fires after 5 s.
    _FS_THRESHOLDS: Dict[str, float] = {"fire": 0.5, "smoke": 0.4}   # per-label min conf
    _FS_PERSIST_SECONDS: float = 5.0   # must stay above threshold this long before alert
    _fs_first_seen: Dict[str, float] = {}   # label  first-seen timestamp

    # Live stream stabilizer  assigns a persistent track id to each person
    # based on box overlap/centroid continuity so overlapping people do not
    # swap identities when the raw YOLO tracker changes IDs.
    live_track_manager = FaceTrackManager()

    frame_idx = 0
    _last_proc_time = time.time()
    _proc_since = 0

    # ----------------------------------------------------------------
    # Helper: push alert to queue (throttled)
    # ----------------------------------------------------------------
    def _emit_alert(
        alert_type: str,
        message: str,
        severity: str,
        key: str,
        cooldown_seconds: Optional[float] = None,
    ):
        now = time.time()
        last = _alert_cooldown.get(key, 0.0)
        cooldown = ALERT_COOLDOWN_SECONDS if cooldown_seconds is None else cooldown_seconds
        if now - last < cooldown:
            print(f"     Alert throttled (cooldown): {alert_type} - {message}")
            return
        _alert_cooldown[key] = now
        payload = {
            "type": alert_type,
            "message": message,
            "severity": severity,  # "info" | "warning" | "error"
            "timestamp": now,
        }
        try:
            alert_queue.put_nowait(payload)
            print(f" Alert emitted to queue: {alert_type} - {message}")
        except queue.Full:
            print(f" Alert queue FULL, dropping: {alert_type}")
        except Exception as e:
            print(f" Failed to emit alert: {e}")

    # ----------------------------------------------------------------
    # Helper: Hit-collector based identity assignment for InsightFace
    # ----------------------------------------------------------------
    def _register_identity_hit_insightface(track_id: int, best_label: str) -> str:
        attempts = _track_attempts.get(track_id, 0)

        if track_id not in _track_hits:
            _track_hits[track_id] = {}

        if best_label == "Unknown":
            fail_hits = _track_fail_hits.get(track_id, 0) + 1
            _track_fail_hits[track_id] = fail_hits
            if fail_hits >= INSIGHTFACE_UNAUTH_HIT_THRESHOLD:
                _identity_cache[track_id] = "Unknown (UNAUTHORIZED)"
                _identity_hold_until[track_id] = time.time() + _UNKNOWN_IDENTITY_HOLD_SECONDS
                print(f" Track #{track_id} locked  'Unknown (UNAUTHORIZED)' after {fail_hits} Unknown hits")
                return "Unknown (UNAUTHORIZED)"
        else:
            _track_fail_hits[track_id] = 0
            owner = _name_to_track.get(best_label)
            if owner is not None and owner != track_id:
                owner_missed = _track_missed.get(owner, 0)
                if owner_missed >= 2:
                    print(f" Releasing stale name slot '{best_label}' from dead Track #{owner}  Track #{track_id}")
                    _name_to_track.pop(best_label, None)
                    _identity_cache.pop(owner, None)
                    _track_hits.pop(owner, None)
                    _track_fail_hits.pop(owner, None)
                    _track_attempts.pop(owner, None)
                else:
                    _track_attempts[track_id] = attempts + 1
                    return f"Identifying... [{attempts+1}/{_MAX_FACE_ATTEMPTS}]"

        current_hits = _track_hits[track_id].get(best_label, 0) + 1
        _track_hits[track_id][best_label] = current_hits

        if current_hits >= INSIGHTFACE_AUTH_HIT_THRESHOLD:
            if best_label != "Unknown":
                final_label = f"{best_label} (AUTHORIZED)"
                _authorized_names.add(best_label)
                _name_to_track[best_label] = track_id
                _identity_cache[track_id] = final_label
                _identity_hold_until[track_id] = time.time() + _IDENTITY_HOLD_SECONDS
                print(f" Track #{track_id} locked  '{final_label}'  AUTHORIZED (after {current_hits} hits)")
                return final_label
            _identity_cache[track_id] = "Unknown"
            _identity_hold_until[track_id] = time.time() + _UNKNOWN_IDENTITY_HOLD_SECONDS
            return "Unknown"

        if attempts + 1 >= _MAX_FACE_ATTEMPTS:
            _identity_cache[track_id] = "Unknown"
            _identity_hold_until[track_id] = time.time() + _UNKNOWN_IDENTITY_HOLD_SECONDS
            return "Unknown"

        _track_attempts[track_id] = attempts + 1
        return f"Identifying... [{attempts+1}/{_MAX_FACE_ATTEMPTS}]"

    def _try_assign_identity_insightface(track_id: int, frame: np.ndarray, x1: int, y1: int, x2: int, y2: int) -> str:
        if track_id in _identity_cache:
            return _identity_cache[track_id]

        if track_id not in _track_hits:
            _track_hits[track_id] = {}

        person_crop = frame[max(0, y1):max(0, y2), max(0, x1):max(0, x2)]
        if person_crop.size == 0 or insightface_app is None:
            _track_attempts[track_id] = _track_attempts.get(track_id, 0) + 1
            return f"Identifying... [{_track_attempts[track_id]}/{_MAX_FACE_ATTEMPTS}]"

        try:
            faces = insightface_app.get(cv2.cvtColor(person_crop, cv2.COLOR_BGR2RGB))
            if not faces:
                _track_attempts[track_id] = _track_attempts.get(track_id, 0) + 1
                return f"Identifying... [{_track_attempts[track_id]}/{_MAX_FACE_ATTEMPTS}]"

            def _area(face) -> float:
                bx1, by1, bx2, by2 = face.bbox
                return float(max(0.0, bx2 - bx1) * max(0.0, by2 - by1))

            face = max(faces, key=_area)
            emb = getattr(face, "normed_embedding", None)
            if emb is None:
                emb = getattr(face, "embedding", None)
            if emb is None:
                _track_attempts[track_id] = _track_attempts.get(track_id, 0) + 1
                return f"Identifying... [{_track_attempts[track_id]}/{_MAX_FACE_ATTEMPTS}]"

            emb = np.asarray(emb, dtype=np.float32)
            if emb.size == 0:
                _track_attempts[track_id] = _track_attempts.get(track_id, 0) + 1
                return f"Identifying... [{_track_attempts[track_id]}/{_MAX_FACE_ATTEMPTS}]"

            norm = float(np.linalg.norm(emb))
            if norm > 0:
                emb = emb / norm

            best_label = "Unknown"
            if len(insightface_embs) > 0:
                sims = insightface_embs @ emb
                best_idx = int(np.argmax(sims))
                best_sim = float(np.max(sims))
                # Use size-aware threshold: smaller face  lower threshold (more forgiving)
                face_width = x2 - x1
                threshold = INSIGHTFACE_SIMILARITY_THRESHOLD_SMALL_FACE if face_width < 80 else INSIGHTFACE_SIMILARITY_THRESHOLD
                if best_sim >= threshold:
                    best_label = insightface_names[best_idx]

            return _register_identity_hit_insightface(track_id, best_label)
        except Exception:
            _track_attempts[track_id] = _track_attempts.get(track_id, 0) + 1
            if _track_attempts[track_id] >= _MAX_FACE_ATTEMPTS:
                _identity_cache[track_id] = "Unknown"
                _identity_hold_until[track_id] = time.time() + _UNKNOWN_IDENTITY_HOLD_SECONDS
                return "Unknown"
            return f"Identifying... [{_track_attempts[track_id]}/{_MAX_FACE_ATTEMPTS}]"

    def _revalidate_identity_insightface(track_id: int, frame: np.ndarray, x1: int, y1: int, x2: int, y2: int) -> None:
        cached_label = _identity_cache.get(track_id)
        if cached_label is None:
            return

        cached_name = cached_label.replace(" (AUTHORIZED)", "").strip()
        person_crop = frame[max(0, y1):max(0, y2), max(0, x1):max(0, x2)]
        if person_crop.size == 0 or insightface_app is None:
            return

        try:
            faces = insightface_app.get(cv2.cvtColor(person_crop, cv2.COLOR_BGR2RGB))
            if not faces:
                _track_revalidation_strikes[track_id] = 0
                return

            def _area(face) -> float:
                bx1, by1, bx2, by2 = face.bbox
                return float(max(0.0, bx2 - bx1) * max(0.0, by2 - by1))

            face = max(faces, key=_area)
            emb = getattr(face, "normed_embedding", None)
            if emb is None:
                emb = getattr(face, "embedding", None)
            if emb is None:
                return

            emb = np.asarray(emb, dtype=np.float32)
            if emb.size == 0:
                return

            norm = float(np.linalg.norm(emb))
            if norm > 0:
                emb = emb / norm

            detected_name = "Unknown"
            if len(insightface_embs) > 0:
                sims = insightface_embs @ emb
                best_idx = int(np.argmax(sims))
                best_sim = float(np.max(sims))
                # Use size-aware threshold for revalidation too
                face_width = x2 - x1
                threshold = INSIGHTFACE_SIMILARITY_THRESHOLD_SMALL_FACE if face_width < 80 else INSIGHTFACE_SIMILARITY_THRESHOLD
                if best_sim >= threshold:
                    detected_name = insightface_names[best_idx]

            if detected_name == cached_name:
                _track_revalidation_strikes[track_id] = 0
            else:
                strikes = _track_revalidation_strikes.get(track_id, 0) + 1
                _track_revalidation_strikes[track_id] = strikes
                print(
                    f"  InsightFace revalidation strike {strikes}/{_REVOKE_STRIKES_NEEDED} "
                    f"Track #{track_id}: cached='{cached_name}' detected='{detected_name}'"
                )
                if strikes >= _REVOKE_STRIKES_NEEDED:
                    print(
                        f" Revoking InsightFace identity for Track #{track_id} ('{cached_name}') "
                        f"after {strikes} consecutive mismatches  forcing re-identification"
                    )
                    _name_to_track.pop(cached_name, None)
                    _identity_cache.pop(track_id, None)
                    _identity_hold_until.pop(track_id, None)
                    _track_hits.pop(track_id, None)
                    _track_attempts.pop(track_id, None)
                    _track_revalidation_strikes.pop(track_id, None)
                    _track_last_revalidated.pop(track_id, None)
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Main inference loop
    # ------------------------------------------------------------------
    while True:
        try:
            active = dict(flags_dict)
        except Exception:
            active = {}

        try:
            item = frame_queue.get(timeout=1.0)
        except queue.Empty:
            continue

        if item is None:
            print(" ML worker: received shutdown sentinel, exiting.")
            break

        # Source-switch sentinel  clear per-session caches, keep models loaded
        if isinstance(item, dict) and item.get("cmd") == "switch_source":
            _identity_cache.clear()
            _identity_hold_until.clear()
            _track_hits.clear()
            _track_fail_hits.clear()
            _track_attempts.clear()
            _authorized_names.clear()
            _name_to_track.clear()
            _fs_first_seen.clear()
            _track_last_revalidated.clear()
            _track_revalidation_strikes.clear()
            _track_missed.clear()
            live_track_manager.reset()
            print(" ML worker: source switched  all tracking caches cleared, inference continues")
            continue

        if isinstance(item, dict) and item.get("cmd") == "reset_identity_state":
            _identity_cache.clear()
            _identity_hold_until.clear()
            _track_hits.clear()
            _track_fail_hits.clear()
            _track_attempts.clear()
            _authorized_names.clear()
            _name_to_track.clear()
            _track_last_revalidated.clear()
            _track_revalidation_strikes.clear()
            _track_missed.clear()
            print(" ML worker: identity state reset for face-system switch")
            continue

        # Reload-embeddings sentinel  re-read the saved .pkl file from disk
        # and clear all identity caches so everyone is re-identified fresh.
        if isinstance(item, dict) and item.get("cmd") == "reload_embeddings":
            reload_mode = item.get("mode", "insightface")
            print(f" ML worker: reloading {reload_mode} embeddings from disk...")
            try:
                if reload_mode == "insightface":
                    new_names, new_embs, new_app = load_insightface_embeddings_from_file()
                    if new_names is not None and len(new_names) > 0:
                        insightface_names = new_names
                        insightface_embs = new_embs
                        if new_app is not None:
                            insightface_app = new_app
                        print(f"    Reloaded {len(insightface_names)} InsightFace identities from disk")
                    else:
                        print("    No InsightFace embeddings found  keeping current set")
            except Exception as _e:
                print(f"    Reload failed: {_e}")
            # Always clear identity caches so stale labels are gone
            _identity_cache.clear()
            _identity_hold_until.clear()
            _track_hits.clear()
            _track_fail_hits.clear()
            _track_attempts.clear()
            _authorized_names.clear()
            _name_to_track.clear()
            _track_last_revalidated.clear()
            _track_revalidation_strikes.clear()
            _track_missed.clear()
            live_track_manager.reset()
            print(" ML worker: identity caches cleared  re-identification will start fresh")
            continue

        orig_h, orig_w, frame_bytes = item

        try:
            frame = np.frombuffer(frame_bytes, dtype=np.uint8).reshape(orig_h, orig_w, 3)
            frame = frame.copy()  # frombuffer returns read-only; OpenCV needs writable
        except Exception:
            continue

        frame_idx += 1
        _proc_since += 1

        # Log processed FPS once per second
        _now_proc = time.time()
        if _now_proc - _last_proc_time >= 1.0:
            print(f"  ProcessedFPS={_proc_since}/s frame_idx={frame_idx}")
            _last_proc_time = _now_proc
            _proc_since = 0

        try:
            sz_pts = list(safe_zone_pts)
        except Exception:
            sz_pts = []

        # ---------------------------------------------------------------
        # Resize once for all models
        # ---------------------------------------------------------------
        inf_size = ML_INFERENCE_SIZE
        sx = inf_size / orig_w
        sy = inf_size / orig_h
        small = cv2.resize(frame, (inf_size, inf_size))

        result: Dict[str, Any] = {
            "frame_idx": frame_idx,
            "orig_w": orig_w,
            "orig_h": orig_h,
            "persons": [],       # list of (x1,y1,x2,y2,conf,track_id,label)
            "faces": {},         # (x1,y1,x2,y2)  label  (legacy, kept for safety)
            "fire_smoke": [],    # list of (x1,y1,x2,y2,label,conf)
            "helmet": [],        # list of helmet violations
            "safe_zone_pts": sz_pts,
        }

        # ---------------------------------------------------------------
        # 1. Person detection with YOLO + stable live track manager
        #    The raw YOLO IDs can swap when people overlap. We keep a
        #    separate stable track id based on box continuity so labels
        #    stay attached to the physical person.
        # ---------------------------------------------------------------
        person_boxes_orig = []   # (x1,y1,x2,y2,conf,track_id,label)

        if person_model is not None and (
            active.get("safezone") or active.get("face_insight") or active.get("helmet")
        ):
            try:
                track_res = person_model.track(
                    frame,
                    imgsz=512,  # reduced from 640 for ~2-3x faster inference, maintains accuracy
                    persist=True,
                    verbose=False,
                    classes=[0],          # 0 = person only
                    tracker=_os.path.join(_os.path.dirname(__file__), "custom_tracker.yaml"),
                    conf=0.35,            # increased from 0.20 to reduce false positives
                    iou=0.45,             # reduces duplicate detections
                )
                detections = []
                for r in track_res:
                    if r.boxes is None:
                        continue
                    for box in r.boxes:
                        x1o, y1o, x2o, y2o = map(int, box.xyxy[0])
                        conf = float(box.conf[0])
                        x1o = max(0, x1o); y1o = max(0, y1o)
                        x2o = min(orig_w, x2o); y2o = min(orig_h, y2o)

                        detections.append(((x1o, y1o, x2o, y2o), conf))

                tracked_people = live_track_manager.update([bbox for bbox, _ in detections])
                conf_by_bbox = {bbox: conf for bbox, conf in detections}

                for track in tracked_people:
                    x1o, y1o, x2o, y2o = track.bbox
                    conf = conf_by_bbox.get(track.bbox, 0.0)
                    track_id = track.track_id
                    padded_bbox = _pad_bbox((x1o, y1o, x2o, y2o), frame.shape)
                    now = time.time()
                    face_mode = "insightface" if (active.get("face_insight") and insightface_app is not None) else None
                    
                    # DEBUG: Print once per frame which mode is active (only on first track to avoid spam)
                    if track_id == tracked_people[0].track_id and frame_idx % 30 == 0:
                        print(f" Frame {frame_idx}: face_mode={face_mode} | face_insight_flag={active.get('face_insight')} | insightface_app={insightface_app is not None}")

                    # -----------------------------------------------
                    # Identity assignment  face recognition runs ONCE
                    # per track_id, then re-validated every N frames.
                    # -----------------------------------------------
                    label = "Person"
                    if face_mode == "insightface":
                        cached_label = _identity_cache.get(track_id)
                        hold_until = _identity_hold_until.get(track_id, 0.0)

                        if cached_label is not None and now < hold_until:
                            label = cached_label
                        elif cached_label is not None and cached_label.startswith("Unknown"):
                            _identity_cache.pop(track_id, None)
                            _identity_hold_until.pop(track_id, None)
                            _track_hits.pop(track_id, None)
                            _track_fail_hits.pop(track_id, None)
                            _track_attempts.pop(track_id, None)
                            label = _try_assign_identity_insightface(
                                track_id, frame, padded_bbox[0], padded_bbox[1], padded_bbox[2], padded_bbox[3]
                            )
                        elif cached_label is not None:
                            last_rv = _track_last_revalidated.get(track_id, -_REVALIDATE_EVERY_N_FRAMES)
                            if frame_idx - last_rv >= _REVALIDATE_EVERY_N_FRAMES:
                                _track_last_revalidated[track_id] = frame_idx
                                _revalidate_identity_insightface(
                                    track_id, frame, padded_bbox[0], padded_bbox[1], padded_bbox[2], padded_bbox[3]
                                )
                            if track_id in _identity_cache:
                                _identity_hold_until[track_id] = now + _IDENTITY_HOLD_SECONDS
                                label = _identity_cache[track_id]
                            else:
                                label = _try_assign_identity_insightface(
                                    track_id, frame, padded_bbox[0], padded_bbox[1], padded_bbox[2], padded_bbox[3]
                                )
                        else:
                            label = _try_assign_identity_insightface(
                                track_id, frame, padded_bbox[0], padded_bbox[1], padded_bbox[2], padded_bbox[3]
                            )

                    # Apply motion smoothing to reduce perceived lag
                    smoothed_box = _apply_motion_smoothing(track_id, (x1o, y1o, x2o, y2o), frame.shape)
                    person_boxes_orig.append((*smoothed_box, conf, track_id, label))

                    # -----------------------------------------------
                    # Alert: unknown person locked (first time only)
                    # -----------------------------------------------
                    if face_mode is not None and label.startswith("Unknown"):
                        _emit_alert(
                            alert_type="unknown_person",
                            message=f"Unknown person detected (Track #{track_id})",
                            severity="warning",
                            key=f"unknown_{track_id}",
                        )

            except Exception as e:
                print(f"    Person tracking error: {e}")
                # Fallback to plain detection on error. We still route the
                # boxes through the stable live track manager so labels don't
                # jump when detections are reordered.
                try:
                    yolo_res = person_model(frame, imgsz=512, verbose=False, classes=[0])
                    fallback_detections = []
                    for r in yolo_res:
                        if r.boxes is None:
                            continue
                        for box in r.boxes:
                            x1o, y1o, x2o, y2o = map(int, box.xyxy[0])
                            conf = float(box.conf[0])
                            bbox = (max(0, x1o), max(0, y1o), min(orig_w, x2o), min(orig_h, y2o))
                            fallback_detections.append((bbox, conf))

                    tracked_people = live_track_manager.update([bbox for bbox, _ in fallback_detections])
                    conf_by_bbox = {bbox: conf for bbox, conf in fallback_detections}
                    for track in tracked_people:
                        x1o, y1o, x2o, y2o = track.bbox
                        person_boxes_orig.append((x1o, y1o, x2o, y2o, conf_by_bbox.get(track.bbox, 0.0), track.track_id, "Person"))
                except Exception:
                    pass

        result["persons"] = person_boxes_orig

        # ---------------------------------------------------------------
        # Stale track pruning  free identity caches for people who left
        # ---------------------------------------------------------------
        current_ids = {entry[5] for entry in person_boxes_orig if entry[5] >= 0}

        # Reset counter for tracks still visible; increment for absent ones
        for tid in list(_track_missed.keys()):
            if tid in current_ids:
                _track_missed[tid] = 0
            else:
                _track_missed[tid] += 1
                if _track_missed[tid] > 60:
                    # Prune after 60 missed frames (~2 s)  long enough to survive brief occlusion
                    old_label = _identity_cache.get(tid, "")
                    old_name = old_label.replace(" (AUTHORIZED)", "").strip()
                    if old_name and _name_to_track.get(old_name) == tid:
                        _name_to_track.pop(old_name, None)
                    _identity_cache.pop(tid, None)
                    _identity_hold_until.pop(tid, None)
                    _track_hits.pop(tid, None)
                    _track_attempts.pop(tid, None)
                    _track_missed.pop(tid, None)
                    _track_last_revalidated.pop(tid, None)
                    _track_revalidation_strikes.pop(tid, None)
                    print(f"  Track #{tid} pruned (absent 60+ frames)  slot freed for new person")

        # Register brand-new track IDs seen for the first time
        for tid in current_ids:
            if tid not in _track_missed:
                _track_missed[tid] = 0

        # ---------------------------------------------------------------
        # 2. Safe-zone violation alerts
        # ---------------------------------------------------------------
        if active.get("safezone") and len(sz_pts) >= 3:
            sz_polygon = Polygon(sz_pts)
            violations_this_frame = 0
            for (x1, y1, x2, y2, conf, tid, lbl) in person_boxes_orig:
                person_poly = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])
                inside = sz_polygon.intersects(person_poly)
                if not inside:
                    violations_this_frame += 1
                    is_unknown_locked = lbl.startswith("Unknown")
                    if is_unknown_locked:
                        msg = f"Unknown person (Track #{tid}) left the safe zone"
                        log_name = f"Unknown person (Track #{tid})"
                    else:
                        name = lbl if lbl not in ("Person", "Identifying...", "Unknown") else "someone"
                        msg = f"{name} left the safe zone"
                        log_name = name
                    print(f" Safe-zone violation: {log_name} (tid={tid}, lbl={lbl})")
                    _emit_alert(
                        alert_type="unsafe_zone",
                        message=msg,
                        severity="warning",
                        key=f"safezone_{tid}",
                    )
            if violations_this_frame > 0 and frame_idx % 30 == 0:
                print(f"    {violations_this_frame} violations this frame (safezone enabled, {len(sz_pts)} points)")
        elif frame_idx % 300 == 0:
            print(f" SafeZone check: safezone_enabled={active.get('safezone')}, pts={len(sz_pts)}")

        # ---------------------------------------------------------------
        # 3. Fire / Smoke (on small frame, scale boxes back)
        #    Per-label confidence thresholds: fire > 0.5, smoke > 0.4
        #    Alert fires after 5 seconds of CUMULATIVE detection.
        #    A gap of up to 3 s is tolerated (timer not reset on brief misses).
        # ---------------------------------------------------------------
        if active.get("firesmoke") and fs_model is not None:
            try:
                fs_res = fs_model(small, verbose=False)

                # Track which labels were seen above threshold this frame
                labels_above_threshold = set()
                _now = time.time()

                for r in fs_res:
                    if r.boxes is None:
                        continue
                    for box in r.boxes:
                        x1s, y1s, x2s, y2s = box.xyxy[0]
                        cls = int(box.cls[0])
                        fs_label = fs_model.names.get(cls, str(cls)).lower()
                        conf = float(box.conf[0])
                        x1o, y1o, x2o, y2o = _scale_xyxy(
                            float(x1s), float(y1s), float(x2s), float(y2s), sx, sy
                        )

                        # Always add to result for drawing (even below threshold)
                        result["fire_smoke"].append((x1o, y1o, x2o, y2o, fs_label, conf))

                        # Per-label minimum confidence
                        min_conf = _FS_THRESHOLDS.get(fs_label, 0.5)

                        if conf >= min_conf:
                            labels_above_threshold.add(fs_label)

                            if fs_label not in _fs_first_seen:
                                # Fresh start  record first-seen
                                _fs_first_seen[fs_label] = (_now, _now)  # (first_seen, last_seen)
                                print(f"    {fs_label} above threshold (conf={conf:.2f} >= {min_conf})  5s timer started")
                            else:
                                first_seen, _ = _fs_first_seen[fs_label]
                                _fs_first_seen[fs_label] = (first_seen, _now)  # update last_seen only

                            first_seen, _ = _fs_first_seen[fs_label]
                            elapsed = _now - first_seen

                            if elapsed >= _FS_PERSIST_SECONDS:
                                _emit_alert(
                                    alert_type=fs_label,          # "fire" or "smoke"  not hardcoded
                                    message=f"{fs_label.capitalize()} detected for {elapsed:.0f}s (conf={conf:.2f})  take action immediately!",
                                    severity="error",
                                    key=f"fire_{fs_label}",
                                    cooldown_seconds=60.0 if fs_label == "fire" else None,
                                )
                                print(f"    ALERT: {fs_label} confirmed ({elapsed:.1f}s above threshold)")

                # Expire labels that have been absent for more than 3 seconds
                # (brief detection gaps are tolerated  only hard absence resets the timer)
                _GAP_TOLERANCE_S = 3.0
                for lbl in list(_fs_first_seen.keys()):
                    if lbl not in labels_above_threshold:
                        _, last_seen = _fs_first_seen[lbl]
                        if _now - last_seen > _GAP_TOLERANCE_S:
                            print(f"    {lbl} absent >{_GAP_TOLERANCE_S:.0f}s  persistence timer reset")
                            _fs_first_seen.pop(lbl, None)

            except Exception as e:
                print(f"    Fire/smoke error: {e}")

        # ---------------------------------------------------------------
        # 4. Helmet detection
        # ---------------------------------------------------------------
        if active.get("helmet") and helmet_model is not None:
            if frame_idx % 30 == 0:  # Print once per second
                print(f"    Helmet detection: ACTIVE (frame {frame_idx})")
            try:
                from models_logic.helmet_detector import detect_helmet_violations
                helmet_violations = detect_helmet_violations(frame, helmet_model, confidence_threshold=0.25)
                
                if helmet_violations:
                    print(f"    Helmet detection: found {len(helmet_violations)} violations")

                # Group PPE violations by tracked person so each body gets only one box/label.
                person_missing: Dict[int, Dict[str, Any]] = {}
                for (px1, py1, px2, py2, _pconf, tid, _plabel) in person_boxes_orig:
                    if tid < 0:
                        continue
                    person_missing[tid] = {
                        "bbox": (px1, py1, px2, py2),
                        "missing": set(),
                        "conf": 0.0,
                    }

                for hv in helmet_violations:
                    hv_bbox = tuple(int(v) for v in hv.get("bbox", [0, 0, 0, 0]))
                    hv_type = hv.get("type")
                    hv_conf = float(hv.get("confidence", 0.0))
                    if hv_type not in {"no_helmet", "no_vest"}:
                        continue

                    best_tid = None
                    best_iou = 0.0
                    hx1, hy1, hx2, hy2 = hv_bbox
                    hcx, hcy = (hx1 + hx2) / 2.0, (hy1 + hy2) / 2.0
                    for tid, pdata in person_missing.items():
                        pb = pdata["bbox"]
                        iou = _bbox_iou(hv_bbox, pb)
                        if iou > best_iou:
                            best_iou = iou
                            best_tid = tid
                        if best_tid is None and pb[0] <= hcx <= pb[2] and pb[1] <= hcy <= pb[3]:
                            best_tid = tid

                    if best_tid is None:
                        continue

                    person_missing[best_tid]["missing"].add(hv_type)
                    person_missing[best_tid]["conf"] = max(person_missing[best_tid]["conf"], hv_conf)

                # Emit one PPE violation per person and draw one full-body box + "missing" label.
                for tid, pdata in person_missing.items():
                    missing = pdata["missing"]
                    if not missing:
                        continue

                    ordered = []
                    if "no_helmet" in missing:
                        ordered.append("helmet")
                    if "no_vest" in missing:
                        ordered.append("vest")

                    label_txt = f"missing: {', '.join(ordered)}"

                    result["helmet"].append({
                        "type": label_txt,
                        "bbox": list(pdata["bbox"]),
                        "confidence": pdata["conf"],
                        "track_id": tid,
                    })

                    # Build a key that includes BOTH the person AND the violation
                    # types.  A new alert fires when:
                    #   • a different person appears  (tid changes), OR
                    #   • the SAME person commits a NEW type of violation
                    #     (e.g. was "helmet", now "helmet, vest")
                    _violation_sig = "_".join(sorted(ordered))   # e.g. "helmet_vest"
                    _emit_alert(
                        alert_type="ppe_violation",
                        message=f"PPE missing on Track #{tid}: {', '.join(ordered)}",
                        severity="warning",
                        key=f"helmet_track_{tid}_{_violation_sig}",
                    )
                    
            except Exception as e:
                print(f"    Helmet detection error: {e}")

        # ---------------------------------------------------------------
        # Put result  drop oldest if queue is full
        # ---------------------------------------------------------------
        try:
            result_queue.put_nowait(result)
        except queue.Full:
            try:
                result_queue.get_nowait()
            except queue.Empty:
                pass
            try:
                result_queue.put_nowait(result)
            except queue.Full:
                pass
