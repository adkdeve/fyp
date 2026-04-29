import asyncio
import logging
import os
import time
import threading
from datetime import datetime

import cv2
import numpy as np

from ..core.config import settings
from ..core.db import SessionLocal
from ..models.camera import Camera, CameraStatus
from ..models.violation import Violation
from ..models.violation import Severity
from ..models.alert import Alert, AlertChannel
from ..models.user import User, UserRole
from .detectors.base import BaseDetector
from . import frame_store

logger = logging.getLogger(__name__)

_SEVERITY_COLOR = {
    "high":   (0,   0,   255),
    "medium": (0,   165, 255),
    "low":    (0,   255, 255),
}


def _make_placeholder(text: str = "No Signal") -> bytes:
    img = np.zeros((360, 640, 3), dtype=np.uint8)
    cv2.putText(img, text, (220, 175),
                cv2.FONT_HERSHEY_SIMPLEX, 1.0, (80, 80, 80), 2)
    _, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 70])
    return buf.tobytes()


class CameraWorker:
    # Seconds that must pass before the same violation type is saved again
    VIOLATION_COOLDOWN = 30

    def __init__(self, camera_id: int, rtsp_url: str,
                 detector: BaseDetector, loop: asyncio.AbstractEventLoop):
        self.camera_id = camera_id
        self.rtsp_url  = rtsp_url
        self.detector  = detector
        self.loop      = loop
        self._stop     = threading.Event()
        self._thread: threading.Thread | None = None

        # Latest raw frame shared between grab thread → inference thread
        self._latest_frame = None
        self._frame_lock   = threading.Lock()

        # Cooldown tracker: violation_type → last saved timestamp
        self._last_saved: dict[str, float] = {}

    def start(self):
        self._stop.clear()
        self._thread = threading.Thread(
            target=self._run, daemon=True, name=f"cam-{self.camera_id}")
        self._thread.start()
        logger.info(f"[Cam {self.camera_id}] Worker started")

    def stop(self):
        self._stop.set()
        frame_store.remove_camera(self.camera_id)
        logger.info(f"[Cam {self.camera_id}] Stop signal sent")

    # ── helpers ──────────────────────────────────────────────────────────────

    def _set_status(self, status: CameraStatus):
        db = SessionLocal()
        try:
            cam = db.get(Camera, self.camera_id)
            if cam:
                cam.status = status
                if status == CameraStatus.online:
                    cam.last_seen_at = datetime.utcnow()
                db.commit()
        except Exception as e:
            logger.error(f"[Cam {self.camera_id}] Status update error: {e}")
        finally:
            db.close()

    # ── Frame grabber thread (drains RTSP buffer continuously) ───────────────

    def _grab_loop(self, cap: cv2.VideoCapture):
        """
        Runs as a daemon thread.
        Reads every frame from the RTSP stream as fast as possible so the
        OpenCV buffer never builds up.  Only the LATEST frame is kept.
        """
        while not self._stop.is_set():
            ret, frame = cap.read()
            if not ret:
                break                        # signal inference loop to reconnect
            with self._frame_lock:
                self._latest_frame = frame

    def _pop_frame(self):
        """Return the current latest frame (or None) without blocking."""
        with self._frame_lock:
            f = self._latest_frame
            self._latest_frame = None        # consume it so we don't reprocess
            return f

    # ── Annotation ───────────────────────────────────────────────────────────

    def _annotate(self, frame, detections) -> bytes:
        out = frame.copy()

        for det in detections:
            color = _SEVERITY_COLOR.get(det.severity.value, (0, 0, 255))
            if det.bbox:
                x1, y1, x2, y2 = det.bbox
                cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)
                label = f"{det.type.value.replace('_', ' ').title()}  {det.confidence:.0%}"
                (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.55, 1)
                cv2.rectangle(out, (x1, y1 - th - 10), (x1 + tw + 6, y1), color, -1)
                cv2.putText(out, label, (x1 + 3, y1 - 4),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1, cv2.LINE_AA)

        # ── HUD ──
        h, w = out.shape[:2]
        ts  = datetime.utcnow().strftime("%Y-%m-%d  %H:%M:%S UTC")
        cam = f"CAM-{self.camera_id}"

        # Dark semi-transparent bar at the bottom
        overlay = out.copy()
        cv2.rectangle(overlay, (0, h - 36), (w, h), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.55, out, 0.45, 0, out)

        cv2.putText(out, ts,  (8, h - 18), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (220, 220, 220), 1, cv2.LINE_AA)
        cv2.putText(out, cam, (8, h -  4), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 210, 0),     1, cv2.LINE_AA)

        # AI badge (top-right)
        badge       = "⚠ AI ALERT"  if detections else "AI MONITORING"
        badge_color = (0, 0, 180)   if detections else (0, 130, 0)
        (bw, bh), _ = cv2.getTextSize(badge, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 1)
        cv2.rectangle(out, (w - bw - 14, 6), (w - 4, bh + 14), badge_color, -1)
        cv2.putText(out, badge, (w - bw - 10, bh + 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_AA)

        _, buf = cv2.imencode(".jpg", out, [cv2.IMWRITE_JPEG_QUALITY, 80])
        return buf.tobytes()

    # ── Snapshot + DB ─────────────────────────────────────────────────────────

    def _save_snapshot(self, frame) -> str | None:
        try:
            snap_dir = os.path.join(settings.media_dir, "snapshots", str(self.camera_id))
            os.makedirs(snap_dir, exist_ok=True)
            fname = datetime.utcnow().strftime("%Y%m%d_%H%M%S") + ".jpg"
            fpath = os.path.join(snap_dir, fname)
            cv2.imwrite(fpath, frame)
            return f"/media/snapshots/{self.camera_id}/{fname}"
        except Exception as e:
            logger.warning(f"[Cam {self.camera_id}] Snapshot failed: {e}")
            return None

    def _record_violation(self, detection, snapshot_url: str | None) -> dict | None:
        db = SessionLocal()
        try:
            v = Violation(
                camera_id    = self.camera_id,
                type         = detection.type,
                severity     = detection.severity,
                confidence   = detection.confidence,
                snapshot_url = snapshot_url,
            )
            db.add(v)
            db.flush()

            supervisors = (
                db.query(User)
                .filter(User.role == UserRole.supervisor, User.is_active == True)
                .all()
            )
            recipient_ids: list[int] = []
            for sup in supervisors:
                if detection.severity == Severity.high and not sup.notify_critical_alerts:
                    continue
                if detection.severity == Severity.medium and not sup.notify_medium_alerts:
                    continue
                if detection.severity == Severity.low:
                    continue
                db.add(Alert(violation_id=v.id, user_id=sup.id,
                             channel=AlertChannel.websocket))
                recipient_ids.append(sup.id)
            db.commit()
            db.refresh(v)
            return {
                "recipients": recipient_ids,
                "payload": {
                    "type":           "new_violation",
                    "violation_id":   v.id,
                    "camera_id":      self.camera_id,
                    "violation_type": detection.type.value,
                    "severity":       detection.severity.value,
                    "confidence":     detection.confidence,
                    "snapshot_url":   snapshot_url,
                    "detected_at":    v.detected_at.isoformat(),
                },
            }
        except Exception as e:
            logger.error(f"[Cam {self.camera_id}] DB error: {e}")
            db.rollback()
            return None
        finally:
            db.close()

    def _broadcast(self, payload: dict):
        from ..ws.manager import connection_manager
        message = payload.get("payload", payload)
        recipients = payload.get("recipients")
        if recipients:
            for user_id in recipients:
                asyncio.run_coroutine_threadsafe(
                    connection_manager.send_to_user(user_id, message), self.loop)

    # ── Main inference loop ───────────────────────────────────────────────────

    def _run(self):
        frame_store.put_frame(self.camera_id, _make_placeholder("Connecting…"))

        cap = cv2.VideoCapture(self.rtsp_url)
        # Keep buffer tiny so we always get the latest frame
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        if not cap.isOpened():
            logger.warning(f"[Cam {self.camera_id}] Cannot open stream: {self.rtsp_url}")
            frame_store.put_frame(self.camera_id, _make_placeholder("Stream Unavailable"))
            self._set_status(CameraStatus.error)
            return

        self._set_status(CameraStatus.online)
        logger.info(f"[Cam {self.camera_id}] Stream opened: {self.rtsp_url}")

        # Start dedicated grab thread to continuously drain the RTSP buffer
        grab_thread = threading.Thread(
            target=self._grab_loop, args=(cap,), daemon=True,
            name=f"grab-{self.camera_id}")
        grab_thread.start()

        fps     = max(settings.fps_target, 1)
        interval = 1.0 / fps                  # seconds between inferences

        while not self._stop.is_set():
            time.sleep(interval)

            frame = self._pop_frame()
            if frame is None:
                # Grab thread lost the stream — reconnect
                if not grab_thread.is_alive():
                    logger.warning(f"[Cam {self.camera_id}] Grab thread died — reconnecting in 5s")
                    self._set_status(CameraStatus.offline)
                    frame_store.put_frame(self.camera_id, _make_placeholder("Reconnecting…"))
                    time.sleep(5)
                    cap.release()
                    cap = cv2.VideoCapture(self.rtsp_url)
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    if cap.isOpened():
                        self._set_status(CameraStatus.online)
                        grab_thread = threading.Thread(
                            target=self._grab_loop, args=(cap,), daemon=True,
                            name=f"grab-{self.camera_id}")
                        grab_thread.start()
                continue

            # Run YOLO on the LATEST frame
            detections = self.detector.detect(frame, camera_id=str(self.camera_id))

            if detections:
                logger.info(
                    f"[Cam {self.camera_id}] {len(detections)} detection(s): "
                    + ", ".join(f"{d.type.value}({d.confidence:.0%})" for d in detections)
                )

            # Annotate + push to stream store
            jpeg = self._annotate(frame, detections)
            frame_store.put_frame(self.camera_id, jpeg)

            # Persist violations — one record per type per cooldown window
            now = time.time()
            for det in detections:
                key       = det.type.value
                last_time = self._last_saved.get(key, 0)
                if now - last_time < self.VIOLATION_COOLDOWN:
                    continue          # same violation seen recently — skip
                self._last_saved[key] = now
                snapshot_url = self._save_snapshot(frame)
                payload = self._record_violation(det, snapshot_url)
                if payload:
                    self._broadcast(payload)

        cap.release()
        self._set_status(CameraStatus.offline)
        frame_store.remove_camera(self.camera_id)
        logger.info(f"[Cam {self.camera_id}] Worker stopped")
