import asyncio
import logging
import os
import time
import threading
import json
from datetime import datetime

import cv2
import numpy as np

from ..core.config import settings
from ..core.firebase_db import get_firestore
from ..models import Severity
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
    VIOLATION_COOLDOWN = 5  # seconds between same violation type

    def __init__(self, camera_id: str, rtsp_url: str,
                 detector: BaseDetector, loop: asyncio.AbstractEventLoop):
        self.camera_id = camera_id
        self.rtsp_url  = rtsp_url
        self.detector  = detector
        self.loop      = loop
        self._stop     = threading.Event()
        self._thread: threading.Thread | None = None
        self._latest_frame = None
        self._frame_lock   = threading.Lock()
        self._last_alert_time: float = 0

    def start(self):
        self._stop.clear()
        self._thread = threading.Thread(
            target=self._run, daemon=True, name=f"cam-{self.camera_id}")
        self._thread.start()
        logger.info(f"[Cam {self.camera_id}] Worker started")

    def stop(self):
        self._stop.set()
        if self._thread and self._thread.is_alive() and self._thread is not threading.current_thread():
            self._thread.join(timeout=3)
        self._thread = None
        frame_store.remove_camera(self.camera_id)
        logger.info(f"[Cam {self.camera_id}] Stop signal sent")

    # ── helpers ──────────────────────────────────────────────────────────────

    def _update_camera_status(self, status: str):
        try:
            db = get_firestore()
            db.collection("cameras").document(self.camera_id).update({
                "status": status,
                "updatedAt": datetime.utcnow().isoformat() + "Z",
            })
        except Exception as e:
            logger.error(f"[Cam {self.camera_id}] Status update error: {e}")

    # ── Frame grabber ────────────────────────────────────────────────────────

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

    # ── Annotation ───────────────────────────────────────────────────────────

    def _annotate(self, frame, detections) -> tuple[np.ndarray, bytes]:
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

        h, w = out.shape[:2]
        ts = datetime.utcnow().strftime("%Y-%m-%d  %H:%M:%S UTC")
        cam = f"CAM-{self.camera_id[:8]}"
        overlay = out.copy()
        cv2.rectangle(overlay, (0, h - 36), (w, h), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.55, out, 0.45, 0, out)
        cv2.putText(out, ts,  (8, h - 18), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (220, 220, 220), 1, cv2.LINE_AA)
        cv2.putText(out, cam, (8, h -  4), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 210, 0),     1, cv2.LINE_AA)

        badge       = "!! AI ALERT"  if detections else "AI MONITORING"
        badge_color = (0, 0, 180)   if detections else (0, 130, 0)
        (bw, bh), _ = cv2.getTextSize(badge, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 1)
        cv2.rectangle(out, (w - bw - 14, 6), (w - 4, bh + 14), badge_color, -1)
        cv2.putText(out, badge, (w - bw - 10, bh + 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_AA)

        _, buf = cv2.imencode(".jpg", out, [cv2.IMWRITE_JPEG_QUALITY, 80])
        return out, buf.tobytes()

    # ── Save snapshot ─────────────────────────────────────────────────────────

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

    # ── Record violation to Firestore ─────────────────────────────────────────

    def _record_violation(self, detection, snapshot_url: str | None) -> dict | None:
        try:
            db = get_firestore()
            now = datetime.utcnow()
            violation_data = {
                "camera_id": self.camera_id,
                "type": detection.type.value,
                "severity": detection.severity.value,
                "status": "open",
                "confidence": detection.confidence,
                "snapshot_url": snapshot_url,
                "detected_at": now.isoformat() + "Z",
                "resolved_at": None,
                "notes": None,
            }
            doc_ref = db.collection("violations").add(violation_data)
            violation_id = doc_ref[1].id

            # Get camera info for the alert payload
            cam_doc = db.collection("cameras").document(self.camera_id).get()
            cam_data = cam_doc.to_dict() if cam_doc.exists else {}

            payload = {
                "type": "new_violation",
                "violation_id": violation_id,
                "camera_id": self.camera_id,
                "camera_name": cam_data.get("name", "Unknown"),
                "violation_type": detection.type.value,
                "severity": detection.severity.value,
                "confidence": detection.confidence,
                "snapshot_url": snapshot_url,
                "detected_at": now.isoformat() + "Z",
            }

            # Also save as an alert in Firestore
            db.collection("alerts").add({
                "violation_id": violation_id,
                "camera_id": self.camera_id,
                "camera_name": cam_data.get("name", "Unknown"),
                "type": detection.type.value,
                "severity": detection.severity.value,
                "confidence": detection.confidence,
                "snapshot_url": snapshot_url,
                "read": False,
                "created_at": now.isoformat() + "Z",
            })

            return payload
        except Exception as e:
            logger.error(f"[Cam {self.camera_id}] Firestore error: {e}")
            return None

    def _broadcast(self, payload: dict):
        from ..ws.manager import connection_manager
        asyncio.run_coroutine_threadsafe(
            connection_manager.broadcast(payload), self.loop)

    # ── Main inference loop ───────────────────────────────────────────────────

    def _run(self):
        frame_store.put_frame(self.camera_id, _make_placeholder("Connecting..."))

        url = self.rtsp_url
        if url.isdigit():
            url = int(url)
            
        cap = cv2.VideoCapture(url)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        if not cap.isOpened():
            logger.warning(f"[Cam {self.camera_id}] Cannot open stream: {self.rtsp_url}")
            frame_store.put_frame(self.camera_id, _make_placeholder("Stream Unavailable"))
            self._update_camera_status("error")
            return

        self._update_camera_status("online")
        logger.info(f"[Cam {self.camera_id}] Stream opened: {self.rtsp_url}")

        grab_thread = threading.Thread(
            target=self._grab_loop, args=(cap,), daemon=True,
            name=f"grab-{self.camera_id}")
        grab_thread.start()

        fps = max(settings.fps_target, 1)
        interval = 1.0 / fps
        frame_count = 0
        last_detections = []

        while not self._stop.is_set():
            time.sleep(interval)
            frame = self._pop_frame()
            if frame is None:
                if not grab_thread.is_alive():
                    logger.warning(f"[Cam {self.camera_id}] Grab thread died — reconnecting in 5s")
                    self._update_camera_status("offline")
                    frame_store.put_frame(self.camera_id, _make_placeholder("Reconnecting..."))
                    time.sleep(5)
                    cap.release()
                    url = self.rtsp_url
                    if url.isdigit():
                        url = int(url)
                    cap = cv2.VideoCapture(url)
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    if cap.isOpened():
                        self._update_camera_status("online")
                        grab_thread = threading.Thread(
                            target=self._grab_loop, args=(cap,), daemon=True,
                            name=f"grab-{self.camera_id}")
                        grab_thread.start()
                continue

            frame_count += 1
            if frame_count % 3 == 0 or not last_detections:
                last_detections = self.detector.detect(frame, camera_id=str(self.camera_id))

            if last_detections and frame_count % 3 == 0:
                logger.info(
                    f"[Cam {self.camera_id}] {len(last_detections)} detection(s): "
                    + ", ".join(f"{d.type.value}({d.confidence:.0%})" for d in last_detections)
                )

            annotated_frame, jpeg = self._annotate(frame, last_detections)
            frame_store.put_frame(self.camera_id, jpeg)

            now = time.time()
            if last_detections and (now - self._last_alert_time >= self.VIOLATION_COOLDOWN):
                det = last_detections[0] # Only take the first violation in the frame
                snapshot_url = self._save_snapshot(annotated_frame)
                payload = self._record_violation(det, snapshot_url)
                if payload:
                    self._broadcast(payload)
                self._last_alert_time = now

        cap.release()
        self._update_camera_status("offline")
        frame_store.remove_camera(self.camera_id)
        logger.info(f"[Cam {self.camera_id}] Worker stopped")
