"""
Stream Router — optimized for 20-30 FPS even with all 4 ML models active.

Architecture
------------
Stream thread  (this process, FastAPI):
  Read frame → Draw cached boxes → Encode JPEG → Send HTTP    (~15ms/frame)

ML worker process  (separate OS process, no GIL contention):
  frame_queue → YOLO person → YOLOv8n-face → Distress → Fire/Smoke → result_queue

The stream thread NEVER waits for ML.  It draws the last cached result on
every frame and sends immediately.  The ML worker updates the cache
asynchronously in the background.

Queues
------
frame_queue  maxsize=2  — stream puts frames here; worker pops them.
             Old frames are dropped automatically (LIFO via discard).
result_queue maxsize=4  — worker puts results; a tiny reader-thread drains
             them and updates self._cached_result under a lock.
"""

from __future__ import annotations

import multiprocessing as mp
import queue
import threading
import time
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
import os
import shutil
from fastapi import APIRouter, Request, File, UploadFile
from fastapi.responses import StreamingResponse
from shapely.geometry import Polygon

router = APIRouter()

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
_JPEG_QUALITY = 75          # Lower = faster encode, still looks fine for live stream
_TARGET_STREAM_FPS = 25     # Cap stream delivery rate
_STREAM_INTERVAL = 1.0 / _TARGET_STREAM_FPS


# ---------------------------------------------------------------------------
# StreamManager
# ---------------------------------------------------------------------------

class StreamManager:
    """
    Manages the webcam capture, the background ML worker process, and the
    HTTP multipart/x-mixed-replace stream.

    Only one instance is created (module-level singleton `stream_mgr`).
    """

    def __init__(self):
        from stream.audio_engine import AudioCaptureEngine
        self.cap: Optional[cv2.VideoCapture] = None
        self.source: Any = 0
        self.is_running = False
        self._capture_lock = threading.Lock()

        # ------------------------------------------------------------------
        # Shared state for ML worker (multiprocessing Manager)
        # ------------------------------------------------------------------
        self._mp_manager: Optional[mp.Manager] = None
        self._flags_dict = None     # shared dict: model enable flags
        self._sz_pts_list = None    # shared list: safe-zone polygon points
        self._frame_queue: Optional[mp.Queue] = None
        self._result_queue: Optional[mp.Queue] = None
        self._worker_proc: Optional[mp.Process] = None

        # ------------------------------------------------------------------
        # Cached result (updated by _result_reader_thread)
        # ------------------------------------------------------------------
        self._cached_result: Dict[str, Any] = {}
        self._result_lock = threading.Lock()
        self._result_reader_thread: Optional[threading.Thread] = None

        # ------------------------------------------------------------------
        # Alert queue — worker pushes alerts; /stream/alerts drains them
        # ------------------------------------------------------------------
        self._alert_queue: Optional[mp.Queue] = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def boot_worker(self):
        """
        Spawn the ML worker process ONCE at server startup.
        Safe to call multiple times — idempotent.
        """
        if self._worker_proc is not None and self._worker_proc.is_alive():
            return  # already running — do not respawn

        print("🚀 Booting ML worker process (models load once here)...")

        # Manager for cross-process shared state
        self._mp_manager = mp.Manager()
        self._flags_dict = self._mp_manager.dict({
            "face_insight": False,
            "safezone": False,
            "firesmoke": False,
            "helmet": False,
        })
        self._sz_pts_list = self._mp_manager.list()

        # Queues
        self._frame_queue = mp.Queue(maxsize=5)  # increased from 2 to buffer IP camera jitter
        self._result_queue = mp.Queue(maxsize=4)
        self._alert_queue = mp.Queue(maxsize=200)

        # Spawn worker — it loads models once internally
        from streams_logic.ml_worker import worker_fn
        self._worker_proc = mp.Process(
            target=worker_fn,
            args=(
                self._frame_queue,
                self._result_queue,
                self._flags_dict,
                self._sz_pts_list,
                self._alert_queue,
            ),
            daemon=True,
            name="MLWorker",
        )
        self._worker_proc.start()
        print(f"✅ ML worker process spawned (PID {self._worker_proc.pid}) — models loading in background")

        # Start the tiny thread that drains result_queue
        self._result_reader_thread = threading.Thread(
            target=self._drain_results, daemon=True, name="ResultReader"
        )
        self._result_reader_thread.start()

    # Alias for backwards-compat — generate_frames calls this
    def load_models(self):
        self.boot_worker()


    def update_flags(self, app_state):
        """Sync model enable flags from FastAPI app state to the ML worker."""
        if self._flags_dict is None:
            return
        try:
            self._flags_dict.update({
                "face_insight": app_state.active_models.get("face_insight", False),
                "safezone": app_state.active_models.get("safezone", False),
                "firesmoke": app_state.active_models.get("firesmoke", False),
                "helmet": app_state.active_models.get("helmet", False),
            })
        except Exception:
            pass

    def update_safe_zone(self, pts: List[Tuple[int, int]]):
        """Push new safe-zone polygon points to the ML worker."""
        if self._sz_pts_list is None:
            return
        try:
            del self._sz_pts_list[:]
            if pts:
                self._sz_pts_list.extend(pts)
        except Exception:
            pass

    def reset_identity_state(self):
        """Tell the ML worker to clear any cached identities immediately."""
        if self._frame_queue is None:
            return
        try:
            self._frame_queue.put_nowait({"cmd": "reset_identity_state"})
        except Exception:
            try:
                self._frame_queue.get_nowait()
                self._frame_queue.put_nowait({"cmd": "reset_identity_state"})
            except Exception:
                pass

    def reload_face_embeddings(self, mode: str = "insightface"):
        """Tell the ML worker to reload embeddings from disk immediately.

        Called after the embeddings file is updated (create/update embeddings)
        so the running worker picks up the new identities without a server restart.
        """
        if self._frame_queue is None:
            return
        try:
            self._frame_queue.put_nowait({"cmd": "reload_embeddings", "mode": mode})
            print(f"🔄 StreamManager: reload_embeddings sentinel sent to ML worker (mode={mode})")
        except Exception:
            # Queue full — try to free a slot then retry once
            try:
                self._frame_queue.get_nowait()
                self._frame_queue.put_nowait({"cmd": "reload_embeddings", "mode": mode})
            except Exception:
                pass

    def generate_frames(self, app_state):
        """
        Generator yielding multipart/x-mixed-replace JPEG frames.

        This runs in the FastAPI response streaming thread.  It NEVER
        calls any ML model — it only reads frames and draws cached boxes.
        """
        # Ensure models / worker are running
        self.load_models()

        with self._capture_lock:
            if self.cap is None or not self.cap.isOpened():
                self.cap = cv2.VideoCapture(self.source)
                self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        frame_idx = 0
        _last_fps_time = time.time()
        _captured_since = 0
        _sent_since = 0
        _drop_since = 0
        _encode_params = [int(cv2.IMWRITE_JPEG_QUALITY), _JPEG_QUALITY]

        # ---------------------------------------------------------------
        # Read video FPS once before loop — not every frame inside a lock
        # ---------------------------------------------------------------
        _is_video_file = (
            isinstance(self.source, str)
            and not str(self.source).startswith("http")
            and not str(self.source).isdigit()
        )
        _video_frame_interval = _STREAM_INTERVAL  # default
        if _is_video_file:
            with self._capture_lock:
                if self.cap:
                    _vfps = self.cap.get(cv2.CAP_PROP_FPS)
                    if _vfps and _vfps > 0:
                        _video_frame_interval = 1.0 / _vfps

        while self.is_running:
            t_start = time.monotonic()

            # ---------------------------------------------------------------
            # 1. Capture frame
            # ---------------------------------------------------------------
            with self._capture_lock:
                if not self.cap or not self.cap.isOpened():
                    break
                ok, frame = self.cap.read()

            if not ok or frame is None:
                # If local video file, loop it instead of breaking
                if isinstance(self.source, str) and not self.source.startswith("http") and not self.source.isdigit():
                    with self._capture_lock:
                        if self.cap:
                            self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    continue
                break

            frame_idx += 1
            orig_h, orig_w = frame.shape[:2]

            # track capture counters for periodic logging
            _captured_since += 1

            # ---------------------------------------------------------------
            # 2. Feed frame to ML worker (non-blocking — drop if queue full)
            # ---------------------------------------------------------------
            self.update_flags(app_state)
            try:
                # Send raw bytes — no lossy JPEG encode/decode between processes
                payload = (orig_h, orig_w, frame.tobytes())
                try:
                    self._frame_queue.put_nowait(payload)
                    _sent_since += 1
                except queue.Full:
                    # Worker is busy — discard oldest frame, keep streaming
                    try:
                        self._frame_queue.get_nowait()
                        _drop_since += 1
                    except queue.Empty:
                        pass
                    try:
                        self._frame_queue.put_nowait(payload)
                        _sent_since += 1
                    except queue.Full:
                        pass
            except Exception:
                pass

            # ---------------------------------------------------------------
            # 3. Draw cached ML results (zero model latency)
            # ---------------------------------------------------------------
            with self._result_lock:
                cached = dict(self._cached_result)

            annotated = frame.copy()
            self._draw_results(annotated, cached, app_state)

            # ---------------------------------------------------------------
            # 4. Encode annotated frame and yield
            # ---------------------------------------------------------------
            ret2, buf2 = cv2.imencode(".jpg", annotated, _encode_params)
            if not ret2:
                continue

            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n\r\n"
                + buf2.tobytes()
                + b"\r\n"
            )

            # ---------------------------------------------------------------
            # 5. Throttle to target FPS (video FPS was cached before loop)
            # ---------------------------------------------------------------
            elapsed = time.monotonic() - t_start
            sleep_for = (_video_frame_interval if _is_video_file else _STREAM_INTERVAL) - elapsed
            if sleep_for > 0:
                time.sleep(sleep_for)

            # Periodic capture/send/drop logging (once per second)
            now = time.time()
            if now - _last_fps_time >= 1.0:
                try:
                    qsz = self._frame_queue.qsize() if self._frame_queue is not None else -1
                except Exception:
                    qsz = -1
                print(f"📸 CaptureFPS={_captured_since}/s SentToWorker={_sent_since}/s QueueDrops={_drop_since}/s qsize={qsz}")
                _last_fps_time = now
                _captured_since = 0
                _sent_since = 0
                _drop_since = 0

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def stop(self):
        """
        Soft stop — releases the camera.
        The ML worker process stays alive so models stay in RAM.
        """
        self.is_running = False

        # Release camera
        with self._capture_lock:
            if self.cap is not None:
                self.cap.release()
                self.cap = None

        print("⏹️  Stream stopped (worker still alive, models in RAM).")

    def shutdown_worker(self):
        """
        Full shutdown — called only at server exit.
        Sends the None sentinel and terminates the worker process.
        """
        self.is_running = False

        # Send shutdown sentinel to worker
        if self._frame_queue is not None:
            try:
                self._frame_queue.put_nowait(None)
            except queue.Full:
                try:
                    self._frame_queue.get_nowait()
                except queue.Empty:
                    pass
                try:
                    self._frame_queue.put_nowait(None)
                except Exception:
                    pass

        if self._worker_proc is not None and self._worker_proc.is_alive():
            self._worker_proc.join(timeout=3)
            if self._worker_proc.is_alive():
                self._worker_proc.terminate()

        # Explicitly close multiprocessing queues so semaphore handles
        # are released before interpreter shutdown.
        def _close_mp_queue(q):
            if q is None:
                return
            try:
                q.close()
            except Exception:
                pass
            try:
                q.join_thread()
            except Exception:
                pass

        _close_mp_queue(self._frame_queue)
        _close_mp_queue(self._result_queue)
        _close_mp_queue(self._alert_queue)

        with self._capture_lock:
            if self.cap is not None:
                self.cap.release()
                self.cap = None

        if self._mp_manager is not None:
            try:
                self._mp_manager.shutdown()
            except Exception:
                pass
            self._mp_manager = None

        self._worker_proc = None
        self._frame_queue = None
        self._result_queue = None
        self._alert_queue = None

        print("🛑 ML worker shut down.")


    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _drain_results(self):
        """
        Tiny background thread: continuously drains result_queue and
        stores the latest result in self._cached_result under a lock.
        """
        while True:
            try:
                result = self._result_queue.get(timeout=1.0)
                with self._result_lock:
                    self._cached_result = result
            except queue.Empty:
                continue
            except Exception:
                break

    def drain_alerts(self, limit: int = 50) -> List[Dict[str, Any]]:
        """
        Drain pending alerts from the alert_queue and return as a list.
        Called by GET /stream/alerts — non-blocking, returns whatever
        is in the queue at this moment (up to `limit` items).
        """
        alerts = []
        if self._alert_queue is None:
            return alerts
        for _ in range(limit):
            try:
                alert = self._alert_queue.get_nowait()
                alerts.append(alert)
            except queue.Empty:
                break
        if alerts:
            print(f"📥 drain_alerts: got {len(alerts)} alerts from queue")
        return alerts

    def _draw_results(self, frame: np.ndarray, cached: Dict[str, Any], app_state) -> None:
        """
        Draw cached ML bounding boxes onto frame in-place.
        No model calls — pure OpenCV drawing.
        """
        if not cached:
            return

        orig_w = cached.get("orig_w", frame.shape[1])
        orig_h = cached.get("orig_h", frame.shape[0])
        cur_h, cur_w = frame.shape[:2]

        # Scale factor in case the cached result was from a differently-
        # sized frame (should be identical, but guard just in case).
        rx = cur_w / orig_w if orig_w else 1.0
        ry = cur_h / orig_h if orig_h else 1.0

        active = app_state.active_models
        sz_pts = app_state.safe_zone_polygon or []

        # ---- Safe-zone polygon overlay ----
        if sz_pts and len(sz_pts) >= 3:
            # Detect if normalized (all coords <= 1) or absolute pixel
            max_c = max(max(abs(p[0]), abs(p[1])) for p in sz_pts)
            if max_c <= 1.0:
                pts_px = np.array([[int(p[0] * cur_w), int(p[1] * cur_h)] for p in sz_pts], np.int32)
            else:
                pts_px = np.array(sz_pts, np.int32)

            # Semi-transparent fill
            overlay = frame.copy()
            cv2.fillPoly(overlay, [pts_px], (30, 120, 255)) # Orange-blue fill
            cv2.addWeighted(overlay, 0.25, frame, 0.75, 0, frame)

            # Border
            cv2.polylines(frame, [pts_px], True, (0, 200, 255), 2) # Cyan/Yellow border
        
        sz_polygon = Polygon(sz_pts) if len(sz_pts) >= 3 else None

        # ---- Person / safe-zone boxes ----
        # persons tuple: (x1, y1, x2, y2, conf, track_id, label)
        for person_entry in cached.get("persons", []):
            # Support both old 5-tuple and new 7-tuple for safety
            if len(person_entry) == 7:
                x1, y1, x2, y2, conf, track_id, identity_label = person_entry
            else:
                x1, y1, x2, y2, conf = person_entry[:5]
                track_id = -1
                identity_label = "Person"

            x1 = int(x1 * rx); y1 = int(y1 * ry)
            x2 = int(x2 * rx); y2 = int(y2 * ry)

            # Determine box color and displayed label
            if active.get("safezone") and sz_polygon is not None:
                person_poly = Polygon([(x1, y1), (x2, y1), (x2, y2), (x1, y2)])
                inside = sz_polygon.intersects(person_poly)
                color = (0, 255, 0) if inside else (0, 0, 255)
                zone_tag = "Safe" if inside else "Unsafe"
                # Show identity if face_insight is enabled
                face_recognition_active = active.get("face_insight")
                display_label = f"{identity_label} [{zone_tag}]" if face_recognition_active else zone_tag
            else:
                # Color by identity when no safe-zone
                face_recognition_active = active.get("face_insight")
                if "UNAUTHORIZED" in identity_label or identity_label == "Unknown":
                    color = (0, 0, 255)     # red
                elif "AUTHORIZED" in identity_label or (identity_label not in ("Person", "Identifying...")):
                    color = (0, 255, 0)     # green — known person
                else:
                    color = (0, 255, 255)   # yellow — person, not yet identified
                display_label = identity_label if face_recognition_active else "Person"
            if track_id > 0:
                display_label = f"#{track_id} {display_label}"

            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, display_label, (x1, max(20, y1 - 10)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)

        # ---- Face recognition labels ----
        # Labels are now embedded in the persons drawing loop above as
        # identity_label (cached per YOLO track_id).  Drawing a second set
        # of boxes here would cause duplicates, so this block is intentionally
        # skipped.  cached["faces"] is kept for backward-compat only.

        # ---- Fire / Smoke boxes ----
        if active.get("firesmoke"):
            for (x1, y1, x2, y2, fs_label, conf) in cached.get("fire_smoke", []):
                x1 = int(x1 * rx); y1 = int(y1 * ry)
                x2 = int(x2 * rx); y2 = int(y2 * ry)
                cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 140, 255), 2)
                cv2.putText(frame, f"{fs_label} {conf:.2f}", (x1, max(20, y1 - 10)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 140, 255), 2)

        # ---- Helmet violations ----
        if active.get("helmet"):
            for hv in cached.get("helmet", []):
                bbox = hv.get("bbox")
                if not bbox:
                    continue
                x1, y1, x2, y2 = bbox
                x1 = int(x1 * rx); y1 = int(y1 * ry)
                x2 = int(x2 * rx); y2 = int(y2 * ry)
                violation_type = hv.get("type", "unknown")
                conf = hv.get("confidence", 0.0)
                
                color = (0, 0, 255)  # red for violations
                cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
                cv2.putText(frame, f"{violation_type} {conf:.2f}", (x1, max(20, y1 - 10)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2)


# ---------------------------------------------------------------------------
# Module-level singleton
# ---------------------------------------------------------------------------
stream_mgr = StreamManager()


# ---------------------------------------------------------------------------
# FastAPI routes
# ---------------------------------------------------------------------------

from pydantic import BaseModel

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/upload")
async def upload_video(file: UploadFile = File(...)):
    """Accepts a video upload and stores it for the stream player"""
    file_path = os.path.join(UPLOAD_DIR, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"filename": file_path}

class StartRequest(BaseModel):
    source: str = "0"

@router.post("/start")
def start_stream(request: Request, payload: StartRequest = None):
    src = stream_mgr.source
    if payload and payload.source:
        src = int(payload.source) if payload.source.isdigit() else payload.source

    # Update source and reset camera if source changed
    with stream_mgr._capture_lock:
        if stream_mgr.source != src:
            stream_mgr.source = src
            if stream_mgr.cap is not None:
                stream_mgr.cap.release()
                stream_mgr.cap = None

    # Ensure worker is alive (boots once; no-op if already running)
    stream_mgr.boot_worker()
    stream_mgr.is_running = True

    # Pre-open camera/video in a background thread so it is ready before
    # the browser hits /video_feed (avoids the 4-5s camera init blocking the stream)
    def _prewarm_capture():
        import time as _time
        _time.sleep(0.05)  # tiny yield to let the response return first
        with stream_mgr._capture_lock:
            if stream_mgr.cap is None or not stream_mgr.cap.isOpened():
                stream_mgr.cap = cv2.VideoCapture(src)
                stream_mgr.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                print(f"📷 Camera pre-warmed for source: {src}")
    threading.Thread(target=_prewarm_capture, daemon=True, name="CameraPrewarm").start()

    # Send switch_source sentinel to clear ML tracking caches
    if stream_mgr._frame_queue is not None:
        try:
            stream_mgr._frame_queue.put_nowait({"cmd": "switch_source"})
        except Exception:
            pass

    return {"status": "started", "source": str(src)}


@router.post("/stop")
def stop_stream():
    stream_mgr.stop()
    return {"status": "stopped"}



@router.get("/video_feed")
def video_feed(request: Request):
    return StreamingResponse(
        stream_mgr.generate_frames(request.app.state),
        media_type="multipart/x-mixed-replace; boundary=frame",
    )


@router.get("/status")
def get_stream_status(request: Request):
    worker_alive = (
        stream_mgr._worker_proc is not None
        and stream_mgr._worker_proc.is_alive()
    )
    return {
        "status": "active" if stream_mgr.is_running else "stopped",
        "active_models": request.app.state.active_models,
        "ml_worker_alive": worker_alive,
    }


@router.get("/alerts")
def get_alerts():
    """
    Drain and return pending ML alerts.

    The frontend should poll this endpoint every 2 seconds.
    Returns a list of alert objects:
      {
        "type":      "fire" | "unsafe_zone" | "unknown_person" | "no_helmet" | "no_vest",
        "message":   "Human-readable description",
        "severity":  "info" | "warning" | "error",
        "timestamp": unix_epoch_float
      }

    Each unique event type is throttled to at most one alert per 30 s
    in the worker, so this endpoint will never return a flood of duplicates.
    """
    alerts = stream_mgr.drain_alerts(limit=50)
    if alerts:
        print(f"📤 Draining {len(alerts)} alerts: {[a.get('type') for a in alerts]}")
    return {"alerts": alerts, "count": len(alerts)}
