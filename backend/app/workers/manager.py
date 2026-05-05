import asyncio
import logging
from ..core.config import settings
from ..core.firebase_db import get_firestore
from .camera_worker import CameraWorker
from .detectors.base import BaseDetector

logger = logging.getLogger(__name__)


class NoOpDetector(BaseDetector):
    """Safe fallback when no real detector is available."""
    def detect(self, frame, camera_id: str = "default"):
        return []


def _build_detector() -> BaseDetector:
    if settings.detector == "mock":
        from .detectors.mock import MockDetector
        logger.warning("Using MockDetector — development only.")
        return MockDetector(interval_seconds=60)
    if settings.detector == "yolo":
        try:
            from .detectors.yolo import YoloDetector
            logger.info(f"Loading YoloDetector from {settings.model_path} "
                        f"(threshold={settings.confidence_threshold})")
            return YoloDetector(settings.model_path,
                                confidence_threshold=settings.confidence_threshold)
        except Exception:
            logger.exception("Failed to initialize YoloDetector. Falling back to NoOpDetector.")
            return NoOpDetector()
    logger.warning(f"Unknown detector '{settings.detector}'. Falling back to NoOpDetector.")
    return NoOpDetector()


class WorkerManager:
    def __init__(self):
        self._workers: dict[str, CameraWorker] = {}
        self._detector: BaseDetector | None = None
        self._loop: asyncio.AbstractEventLoop | None = None

    def start_all(self, loop: asyncio.AbstractEventLoop):
        self._loop = loop
        self._detector = _build_detector()

        try:
            db = get_firestore()
            docs = db.collection("cameras").where("enabled", "==", True).stream()
            count = 0
            for doc in docs:
                data = doc.to_dict()
                camera_id = doc.id
                rtsp_url = data.get("rtsp_url", "")
                if rtsp_url:
                    self._start_worker(camera_id, rtsp_url)
                    count += 1
            logger.info(f"WorkerManager: started {count} camera workers from Firebase")
        except Exception as e:
            logger.error(f"WorkerManager: failed to load cameras from Firebase: {e}")

    def stop_all(self):
        for worker in self._workers.values():
            worker.stop()
        self._workers.clear()
        logger.info("WorkerManager: all workers stopped")

    def restart_camera(self, camera_id: str, rtsp_url: str):
        self.stop_camera(camera_id)
        self._start_worker(camera_id, rtsp_url)

    def stop_camera(self, camera_id: str):
        worker = self._workers.pop(camera_id, None)
        if worker:
            worker.stop()

    def _start_worker(self, camera_id: str, rtsp_url: str):
        if not self._detector or not self._loop:
            return
        worker = CameraWorker(camera_id, rtsp_url, self._detector, self._loop)
        self._workers[camera_id] = worker
        worker.start()


worker_manager = WorkerManager()
