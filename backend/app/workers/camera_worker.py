"""
CameraWorker — per-camera stream + AI inference worker.

Key responsibilities:
  - Grab frames from RTSP/webcam at full speed
  - Send frames to the ML service every N frames (non-blocking inference thread)
  - Annotate frames: draw safe zone polygon + person/violation boxes
  - Record violations in Firebase (with 24h cooldown per track+violation_type)
  - Push MJPEG frames to frame_store for HTTP streaming
"""
import asyncio
import logging
import threading
import queue
import time
from datetime import datetime

import cv2
import numpy as np

from ..core.config import settings
from ..core.firebase_db import get_firestore, get_storage_bucket
from ..models import ViolationType
from .detectors.base import BaseDetector
from . import frame_store

logger = logging.getLogger(__name__)

# ── Colours ───────────────────────────────────────────────────────────────────
_C_ZONE        = (255, 255,   0)   # cyan (BGR) — matches working ML feed
_C_ZONE_FILL   = (255, 200,   0)   # light blue fill
_C_PERSON_SAFE = ( 50, 220,  50)   # green — person inside zone (authorized)
_C_VIOLATION   = (  0,   0, 220)   # red — violation / unauthorized
_C_FIRE        = (  0, 100, 255)   # orange-red — fire/smoke
_C_FACE        = (200,  60,  60)   # blue-ish — unknown face
_C_PPE         = (  0, 165, 255)   # orange — PPE violation

_SEVERITY_COLOR = {
    "high":   _C_VIOLATION,
    "medium": _C_PPE,
    "low":    (0, 220, 220),
}

# Cooldowns for violation recording
_TRACKED_COOLDOWN   = 86400 # 24 hours — prevents same person triggering multiple violations
_UNTRACKED_COOLDOWN = 10    # seconds between same type (fire, smoke, face)

# Types that should NEVER be written to Firebase
_DISPLAY_ONLY_TYPES = {ViolationType.person}


def _make_placeholder(text: str = "No Signal") -> bytes:
    img = np.zeros((360, 640, 3), dtype=np.uint8)
    cv2.putText(img, text, (180, 180),
                cv2.FONT_HERSHEY_SIMPLEX, 0.9, (80, 80, 80), 2)
    _, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 70])
    return buf.tobytes()


def _compute_iou(a, b) -> float:
    xA, yA = max(a[0], b[0]), max(a[1], b[1])
    xB, yB = min(a[2], b[2]), min(a[3], b[3])
    inter  = max(0, xB - xA + 1) * max(0, yB - yA + 1)
    aA = (a[2] - a[0] + 1) * (a[3] - a[1] + 1)
    bB = (b[2] - b[0] + 1) * (b[3] - b[1] + 1)
    return inter / float(aA + bB - inter + 1e-6)


class CameraWorker:
    DISPLAY_FPS  = 15
    DETECT_EVERY = 10   # run ML every N display frames

    def __init__(self, camera_id: str, rtsp_url: str,
                 detector: BaseDetector, loop: asyncio.AbstractEventLoop):
        self.camera_id = camera_id
        self.rtsp_url  = rtsp_url
        self.detector  = detector
        self.loop      = loop
        self._stop     = threading.Event()
        self._thread: threading.Thread | None = None

        # Frame grabbing
        self._latest_frame = None
        self._frame_lock   = threading.Lock()

        # Inference pipeline
        self._infer_queue     = queue.Queue(maxsize=1)
        self._result_box_lock = threading.Lock()
        self._result_box: list = []

        # Firebase write pipeline
        self._firebase_queue = queue.Queue(maxsize=10)

        # Safe zone polygon — normalized [[nx, ny], …] coords ∈ [0,1]
        # Loaded from Firestore on start; can be updated live via set_safe_zone_polygon()
        self._safe_zone_polygon: list[list[float]] = []
        self._polygon_lock = threading.Lock()

        # Which AI models to enable (loaded from Firestore camera settings)
        self._enabled_models: dict[str, bool] = {
            "helmet":       False,
            "firesmoke":    False,
        }

        # Load the polygon for this camera from Firestore
        self._load_polygon_from_firestore()

    # ── Polygon management ────────────────────────────────────────────────────

    def _load_polygon_from_firestore(self):
        """Load saved safe zone polygon for this camera (called on init)."""
        try:
            db  = get_firestore()
            doc = db.collection("cameras").document(self.camera_id).get()
            if doc.exists:
                data   = doc.to_dict() or {}
                pts    = data.get("safe_zone_polygon", [])
                if pts:
                    with self._polygon_lock:
                        # Handle both list of dicts [{"x": 0.1, "y": 0.2}] and legacy list of lists
                        parsed_pts = []
                        for p in pts:
                            if isinstance(p, dict) and "x" in p and "y" in p:
                                parsed_pts.append([p["x"], p["y"]])
                            elif isinstance(p, (list, tuple)) and len(p) >= 2:
                                parsed_pts.append([p[0], p[1]])
                        self._safe_zone_polygon = parsed_pts
                    logger.info(f"[Cam {self.camera_id}] Loaded {len(parsed_pts)}-pt safe zone")
        except Exception as e:
            logger.warning(f"[Cam {self.camera_id}] Could not load safe zone: {e}")

    def set_safe_zone_polygon(self, points: list[list[float]]):
        """Hot-update the polygon without restarting the worker."""
        with self._polygon_lock:
            self._safe_zone_polygon = [list(p) for p in points]
        logger.info(f"[Cam {self.camera_id}] Safe zone updated: {len(points)} pts")

    def set_enabled_models(self, models: dict[str, bool]):
        """Hot-update which AI models are active for this camera."""
        self._enabled_models = dict(models)
        if hasattr(self.detector, 'set_enabled_models'):
            self.detector.set_enabled_models(models)
        logger.info(f"[Cam {self.camera_id}] Enabled models: {models}")

    def _get_polygon(self) -> list[list[float]]:
        with self._polygon_lock:
            return list(self._safe_zone_polygon)

    # ── Lifecycle ─────────────────────────────────────────────────────────────

    def start(self):
        self._stop.clear()
        threading.Thread(target=self._run,            daemon=True, name=f"cam-{self.camera_id}").start()
        threading.Thread(target=self._inference_loop, daemon=True, name=f"infer-{self.camera_id}").start()
        threading.Thread(target=self._firebase_worker, daemon=True, name=f"fb-{self.camera_id}").start()
        logger.info(f"[Cam {self.camera_id}] Worker started ({self.rtsp_url})")

    def stop(self):
        self._stop.set()
        frame_store.remove_camera(self.camera_id)
        logger.info(f"[Cam {self.camera_id}] Worker stopped")

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _update_camera_status(self, status: str):
        try:
            get_firestore().collection("cameras").document(self.camera_id).update({
                "status": status,
                "updatedAt": datetime.utcnow().isoformat() + "Z",
            })
        except Exception as e:
            logger.debug(f"[Cam {self.camera_id}] Status update error: {e}")

    def _broadcast(self, payload: dict):
        try:
            from ..ws.manager import connection_manager
            asyncio.run_coroutine_threadsafe(
                connection_manager.broadcast(payload), self.loop)
        except Exception as e:
            logger.debug(f"[Cam {self.camera_id}] Broadcast error: {e}")

    # ── Frame grabber ─────────────────────────────────────────────────────────

    def _grab_loop(self, cap: cv2.VideoCapture):
        while not self._stop.is_set():
            ret, frame = cap.read()
            if not ret:
                break
            with self._frame_lock:
                self._latest_frame = frame

    def _pop_frame(self):
        with self._frame_lock:
            f = self._latest_frame
            self._latest_frame = None
            return f

    # ── Inference loop (separate thread) ─────────────────────────────────────

    def _inference_loop(self):
        while not self._stop.is_set():
            try:
                frame_data = self._infer_queue.get(timeout=1.0)
                if frame_data is None:
                    continue
                frame, _, _ = frame_data

                polygon = self._get_polygon()

                # Pass enabled_models so ML service runs the right models regardless
                # of its own in-memory state (which resets on every restart).
                if hasattr(self.detector, 'set_enabled_models'):
                    self.detector.set_enabled_models(self._enabled_models)

                raw = self.detector.detect(
                    frame,
                    camera_id=str(self.camera_id),
                    safe_zone_polygon=polygon,
                )

                with self._result_box_lock:
                    self._result_box = raw

            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"[Cam {self.camera_id}] Inference error: {e}")

    # ── Annotation ────────────────────────────────────────────────────────────

    def _annotate(self, frame, detections) -> tuple[np.ndarray, bytes]:
        """
        Draw:
          1. Safe zone polygon (semi-transparent blue fill + cyan border)
          2. Person boxes (green=safe inside zone, red=outside zone)
          3. PPE / fire / face violation boxes
        """
        out = frame.copy()
        h, w = out.shape[:2]

        # ── Draw safe zone polygon ────────────────────────────────────────────
        polygon = self._get_polygon()
        if len(polygon) >= 3:
            try:
                # Detect if normalized (all coords ≤ 1) or absolute pixel
                max_c = max(max(abs(p[0]), abs(p[1])) for p in polygon)
                if max_c <= 1.0:
                    pts_px = np.array([[int(p[0] * w), int(p[1] * h)] for p in polygon], dtype=np.int32)
                else:
                    pts_px = np.array([[int(p[0]), int(p[1])] for p in polygon], dtype=np.int32)

                # Semi-transparent fill (30% opacity, more visible)
                overlay = out.copy()
                cv2.fillPoly(overlay, [pts_px], _C_ZONE_FILL)
                cv2.addWeighted(overlay, 0.30, out, 0.70, 0, out)

                # Thick bright border (3px)
                cv2.polylines(out, [pts_px], isClosed=True, color=_C_ZONE, thickness=3)

                # Corner dots
                for pt in pts_px:
                    cv2.circle(out, tuple(pt), 7, (0, 255, 255), -1)   # cyan dots
                    cv2.circle(out, tuple(pt), 7, (0, 0, 0), 2)        # black outline

                # Label with background
                lx = int(pts_px[:, 0].min())
                ly = int(pts_px[:, 1].min()) - 10
                label = "RESTRICTED ZONE"
                (lw, lh), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.65, 2)
                ly = max(ly, lh + 8)
                cv2.rectangle(out, (lx, ly - lh - 6), (lx + lw + 8, ly + 4), _C_ZONE, -1)
                cv2.putText(out, label, (lx + 4, ly),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 0, 0), 2, cv2.LINE_AA)
            except Exception as e:
                logger.error(f"[Cam {self.camera_id}] Annotation error: {e}")


        # ── Draw detection boxes ──────────────────────────────────────────────
        for det in detections:
            if not det.bbox:
                continue
            x1, y1, x2, y2 = [int(v) for v in det.bbox]
            vtype = det.type.value

            # Pick colour by detection type
            if vtype == "person":
                color = _C_PERSON_SAFE
            elif vtype == "restricted_area_entrance":
                color = _C_VIOLATION
            elif "fire" in vtype or "smoke" in vtype:
                color = _C_FIRE
            elif vtype == "unknown_face":
                color = _C_FACE
            else:
                color = _SEVERITY_COLOR.get(det.severity.value, _C_PPE)

            # Box
            cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)

            # Label with filled background
            if vtype == "person":
                label = f"Person (Safe) {int(det.confidence * 100)}%"
            elif vtype == "restricted_area_entrance":
                label = f"Restricted Area! {int(det.confidence * 100)}%"
            elif getattr(det, "composite_label", None):
                label = det.composite_label
            else:
                label = f"{vtype.replace('_', ' ').title()} {int(det.confidence * 100)}%"

            (lw, lh), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.42, 1)
            ly2 = max(y1 - 4, lh + 6)
            cv2.rectangle(out, (x1, ly2 - lh - 4), (x1 + lw + 4, ly2), color, -1)
            cv2.putText(out, label, (x1 + 2, ly2 - 2),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)

        # ── Status badge ──────────────────────────────────────────────────────
        violations = [d for d in detections if not d.display_only]
        badge       = "!! ALERT" if violations else "MONITORING"
        badge_color = (0, 0, 180) if violations else (0, 130, 0)
        cv2.putText(out, badge, (w - 140, 25),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, badge_color, 1, cv2.LINE_AA)

        _, buf = cv2.imencode(".jpg", out, [cv2.IMWRITE_JPEG_QUALITY, 60])
        return out, buf.tobytes()

    # ── Firebase worker ───────────────────────────────────────────────────────

    def _firebase_worker(self):
        while not self._stop.is_set():
            try:
                task = self._firebase_queue.get(timeout=1.0)
                if task is None:
                    continue
                task_type, args = task
                if task_type == "snapshot":
                    frame, detection = args
                    url = self._save_snapshot_sync(frame)
                    if url:
                        self._record_violation_sync(detection, url)
            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"[Cam {self.camera_id}] Firebase worker error: {e}")

    def _save_snapshot_sync(self, frame) -> str | None:
        try:
            _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
            fname     = datetime.utcnow().strftime("%Y%m%d_%H%M%S") + ".jpg"
            blob_path = f"snapshots/{self.camera_id}/{fname}"
            bucket = get_storage_bucket()
            blob   = bucket.blob(blob_path)
            blob.upload_from_string(buf.tobytes(), content_type="image/jpeg")
            blob.make_public()
            return blob.public_url
        except Exception as e:
            logger.warning(f"[Cam {self.camera_id}] Snapshot failed: {e}")
            return None

    def _record_violation_sync(self, detection, snapshot_url: str | None) -> None:
        try:
            db  = get_firestore()
            now = datetime.utcnow()
            vdata = {
                "camera_id":    self.camera_id,
                "type":         detection.type.value,
                "severity":     detection.severity.value,
                "status":       "open",
                "confidence":   detection.confidence,
                "snapshot_url": snapshot_url,
                "detected_at":  now.isoformat() + "Z",
                "resolved_at":  None,
                "notes":        getattr(detection, "composite_label", None),
                "composite_label": getattr(detection, "composite_label", None),
            }
            ref         = db.collection("violations").add(vdata)
            vid         = ref[1].id
            cam_doc     = db.collection("cameras").document(self.camera_id).get()
            cam_data    = cam_doc.to_dict() if cam_doc.exists else {}
            cam_name    = cam_data.get("name", "Unknown")

            payload = {
                "type":           "new_violation",
                "violation_id":   vid,
                "camera_id":      self.camera_id,
                "camera_name":    cam_name,
                "violation_type": detection.type.value,
                "severity":       detection.severity.value,
                "confidence":     detection.confidence,
                "snapshot_url":   snapshot_url,
                "detected_at":    now.isoformat() + "Z",
                "composite_label": getattr(detection, "composite_label", None),
            }
            db.collection("alerts").add({
                "violation_id": vid,
                "camera_id":    self.camera_id,
                "camera_name":  cam_name,
                "type":         detection.type.value,
                "severity":     detection.severity.value,
                "confidence":   detection.confidence,
                "snapshot_url": snapshot_url,
                "read":         False,
                "created_at":   now.isoformat() + "Z",
                "composite_label": getattr(detection, "composite_label", None),
            })
            self._broadcast(payload)
            logger.info(f"[Cam {self.camera_id}] Violation recorded: {detection.type.value}")
        except Exception as e:
            logger.error(f"[Cam {self.camera_id}] Firestore error: {e}")

    # ── Main loop ─────────────────────────────────────────────────────────────

    def _run(self):
        frame_store.put_frame(self.camera_id, _make_placeholder("Connecting..."))

        url = self.rtsp_url
        if isinstance(url, str) and url.isdigit():
            url = int(url)

        cap = cv2.VideoCapture(url)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        if not cap.isOpened():
            logger.warning(f"[Cam {self.camera_id}] Cannot open: {self.rtsp_url}")
            frame_store.put_frame(self.camera_id, _make_placeholder("Unavailable"))
            self._update_camera_status("error")
            return

        self._update_camera_status("online")

        grab_thread = threading.Thread(
            target=self._grab_loop, args=(cap,), daemon=True, name=f"grab-{self.camera_id}")
        grab_thread.start()

        display_interval = 1.0 / self.DISPLAY_FPS
        frame_count      = 0
        last_detections: list = []

        # Tracking
        active_tracks: dict[int, dict] = {}
        next_track_id = 1

        # Deduplication
        recorded_violations: dict[tuple, float] = {}   # (track_id, vtype) → timestamp
        last_untracked_alert: dict[str, float]  = {}   # vtype → timestamp

        # Reconnection state
        grab_thread_dead_time: float | None = None
        max_reconnection_attempts = 3
        reconnection_attempts = 0

        while not self._stop.is_set():
            t0 = time.monotonic()

            frame = self._pop_frame()
            if frame is None:
                if not grab_thread.is_alive():
                    # Grab thread just died
                    if grab_thread_dead_time is None:
                        grab_thread_dead_time = time.time()
                        reconnection_attempts = 0
                        logger.warning(f"[Cam {self.camera_id}] Grab thread died")
                    
                    # Try to reconnect with exponential backoff (max 3 attempts)
                    if reconnection_attempts < max_reconnection_attempts:
                        elapsed_since_death = time.time() - grab_thread_dead_time
                        backoff_delay = 2 ** reconnection_attempts  # 1s, 2s, 4s
                        
                        if elapsed_since_death >= backoff_delay:
                            reconnection_attempts += 1
                            logger.info(f"[Cam {self.camera_id}] Reconnection attempt {reconnection_attempts}/{max_reconnection_attempts}...")
                            self._update_camera_status("offline")
                            frame_store.put_frame(self.camera_id, _make_placeholder("Reconnecting..."))
                            
                            cap.release()
                            cap = cv2.VideoCapture(url)
                            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                            
                            if cap.isOpened():
                                logger.info(f"[Cam {self.camera_id}] Reconnected successfully on attempt {reconnection_attempts}")
                                self._update_camera_status("online")
                                grab_thread = threading.Thread(
                                    target=self._grab_loop, args=(cap,), daemon=True,
                                    name=f"grab-{self.camera_id}")
                                grab_thread.start()
                                grab_thread_dead_time = None
                                reconnection_attempts = 0
                        else:
                            # Wait until next backoff period
                            time.sleep(0.1)
                    else:
                        # Max reconnection attempts exceeded — give up
                        logger.error(f"[Cam {self.camera_id}] Failed to reconnect after {max_reconnection_attempts} attempts. Stopping worker.")
                        self._update_camera_status("error")
                        frame_store.put_frame(self.camera_id, _make_placeholder("Connection Failed"))
                        break
                else:
                    time.sleep(0.005)
                continue

            frame_count += 1
            orig_h, orig_w = frame.shape[:2]

            # Queue frame for inference
            if frame_count % self.DETECT_EVERY == 0 or not last_detections:
                if not self._infer_queue.full():
                    self._infer_queue.put((frame.copy(), orig_h, orig_w))

            # Fetch latest results
            with self._result_box_lock:
                raw_detections = list(self._result_box)

            # IoU tracking (only update on detection cycles)
            if raw_detections is not None and frame_count % self.DETECT_EVERY == 0:
                frame_tracks: dict[int, dict] = {}
                for det in raw_detections:
                    if not det.bbox:
                        det.track_id = None
                        continue
                    best_iou, best_tid = 0.1, None
                    
                    # 1. Share track_id if multiple violations sit on the exact same person box
                    identical_tid = None
                    for tid, tinfo in frame_tracks.items():
                        if _compute_iou(det.bbox, tinfo["bbox"]) > 0.95:
                            identical_tid = tid
                            break
                            
                    if identical_tid is not None:
                        det.track_id = identical_tid
                        continue

                    # 2. Match against previous active tracks
                    for tid, tinfo in active_tracks.items():
                        if tid in frame_tracks:
                            continue
                        iou = _compute_iou(det.bbox, tinfo["bbox"])
                        if iou > best_iou:
                            best_iou, best_tid = iou, tid
                            
                    if best_tid is None:
                        best_tid      = next_track_id
                        next_track_id += 1
                    det.track_id = best_tid
                    frame_tracks[best_tid] = {"bbox": det.bbox, "missing": 0}
                
                # Keep unmatched tracks alive for up to 5 inference cycles to prevent track ID flipping
                for tid, tinfo in active_tracks.items():
                    if tid not in frame_tracks:
                        if tinfo["missing"] < 5:
                            frame_tracks[tid] = {"bbox": tinfo["bbox"], "missing": tinfo["missing"] + 1}
                            
                active_tracks   = frame_tracks
                last_detections = raw_detections

            # Annotate + push to stream
            annotated, jpeg = self._annotate(frame, last_detections)
            frame_store.put_frame(self.camera_id, jpeg)

            # Violation deduplication & Firebase queuing
            now = time.time()

            # Periodic cleanup
            if frame_count % (self.DISPLAY_FPS * 300) == 0:
                cutoff = now - _TRACKED_COOLDOWN * 10
                recorded_violations = {k: v for k, v in recorded_violations.items() if v > cutoff}
                last_untracked_alert = {k: v for k, v in last_untracked_alert.items() if v > cutoff}

            for det in last_detections:
                # Never record display-only detections (person inside zone)
                if det.display_only or det.type in _DISPLAY_ONLY_TYPES:
                    continue

                vtype = det.type.value
                
                # Use actual violation type for deduplication so that
                # different PPE violations on the same person each get
                # their own alert (e.g. no_helmet ≠ no_vest).
                dedup_vtype = vtype

                if det.track_id is not None:
                    key       = (det.track_id, dedup_vtype)
                    last_time = recorded_violations.get(key, 0.0)
                    if now - last_time >= _TRACKED_COOLDOWN:
                        recorded_violations[key] = now
                        if not self._firebase_queue.full():
                            self._firebase_queue.put(("snapshot", (annotated, det)))
                else:
                    last_time = last_untracked_alert.get(dedup_vtype, 0.0)
                    if now - last_time >= _UNTRACKED_COOLDOWN:
                        last_untracked_alert[dedup_vtype] = now
                        if not self._firebase_queue.full():
                            self._firebase_queue.put(("snapshot", (annotated, det)))

            # Frame pacing
            elapsed    = time.monotonic() - t0
            sleep_time = display_interval - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)

        cap.release()
        self._update_camera_status("offline")
        frame_store.remove_camera(self.camera_id)
        logger.info(f"[Cam {self.camera_id}] Worker fully stopped")
