import asyncio
import logging
from ..core.config import settings
from ..core.firebase_db import get_firestore
from .camera_worker import CameraWorker
from .detectors.base import BaseDetector

logger = logging.getLogger(__name__)


class NoOpDetector(BaseDetector):
    """Safe fallback — returns no detections (ML service unreachable)."""
    def detect(self, frame, camera_id: str = "default", safe_zone_polygon=None):
        return []


def _build_detector() -> BaseDetector:
    try:
        from .detectors.remote_ml import RemoteMLDetector
        logger.info(f"[WorkerManager] RemoteMLDetector → {settings.ml_api_url}")
        return RemoteMLDetector(settings.ml_api_url)
    except Exception:
        logger.exception("Failed to init RemoteMLDetector — falling back to NoOp")
        return NoOpDetector()


class WorkerManager:
    def __init__(self):
        self._workers:  dict[str, CameraWorker] = {}
        self._detector: BaseDetector | None      = None
        self._loop:     asyncio.AbstractEventLoop | None = None

    def start_all(self, loop: asyncio.AbstractEventLoop):
        self._loop     = loop
        self._detector = _build_detector()

        try:
            db    = get_firestore()
            docs  = db.collection("cameras").where("enabled", "==", True).stream()
            count = 0
            for doc in docs:
                data   = doc.to_dict()
                cam_id = doc.id
                url    = data.get("rtsp_url", "")
                if url:
                    self._start_worker(cam_id, url)
                    count += 1
            logger.info(f"WorkerManager: started {count} camera workers from Firebase")
        except Exception as e:
            logger.error(f"WorkerManager: Firebase load failed: {e}")

    def stop_all(self):
        for w in self._workers.values():
            w.stop()
        self._workers.clear()
        logger.info("WorkerManager: all workers stopped")

    def restart_camera(self, camera_id: str, rtsp_url: str):
        self.stop_camera(camera_id)
        self._start_worker(camera_id, rtsp_url)

    def stop_camera(self, camera_id: str):
        worker = self._workers.pop(camera_id, None)
        if worker:
            worker.stop()

    def update_safe_zone(self, camera_id: str, points: list[list[float]]):
        """
        Hot-update the safe zone polygon for a running camera worker.
        Called by the safe_zone API after saving to Firestore.
        """
        worker = self._workers.get(camera_id)
        if worker:
            worker.set_safe_zone_polygon(points)
            logger.info(f"WorkerManager: safe zone updated for cam {camera_id} ({len(points)} pts)")
        else:
            logger.debug(f"WorkerManager: cam {camera_id} not running — polygon will load on next start")

    def update_enabled_models(self, camera_id: str, models: dict[str, bool]):
        """
        Hot-update which AI models are active for a running camera worker.
        Called when the supervisor toggles detection models in the Settings panel.
        Updates ALL workers if camera_id is None or '*'.
        """
        if camera_id in ("*", None, ""):
            # Broadcast to all workers
            for w in self._workers.values():
                w.set_enabled_models(models)
            logger.info(f"WorkerManager: enabled_models broadcast to all workers: {models}")
        else:
            worker = self._workers.get(camera_id)
            if worker:
                worker.set_enabled_models(models)
                logger.info(f"WorkerManager: enabled_models for cam {camera_id}: {models}")

    def get_workers(self) -> dict[str, CameraWorker]:
        return dict(self._workers)

    def _start_worker(self, camera_id: str, rtsp_url: str):
        if not self._detector or not self._loop:
            return
        worker = CameraWorker(camera_id, rtsp_url, self._detector, self._loop)
        self._workers[camera_id] = worker
        worker.start()


worker_manager = WorkerManager()
