import asyncio
import logging
from ..core.db import SessionLocal
from ..core.config import settings
from ..models.camera import Camera
from .camera_worker import CameraWorker
from .detectors.base import BaseDetector

logger = logging.getLogger(__name__)


def _build_detector() -> BaseDetector:
    if settings.detector == "yolo":
        from .detectors.yolo import YoloDetector
        logger.info(f"Loading YoloDetector from {settings.model_path} "
                    f"(threshold={settings.confidence_threshold})")
        return YoloDetector(settings.model_path,
                            confidence_threshold=settings.confidence_threshold)
    else:
        from .detectors.mock import MockDetector
        logger.info("Using MockDetector (generates a violation every 60s per camera)")
        return MockDetector(interval_seconds=60)


class WorkerManager:
    def __init__(self):
        self._workers: dict[int, CameraWorker] = {}
        self._detector: BaseDetector | None = None
        self._loop: asyncio.AbstractEventLoop | None = None

    def start_all(self, loop: asyncio.AbstractEventLoop):
        self._loop = loop
        self._detector = _build_detector()
        db = SessionLocal()
        try:
            cameras = db.query(Camera).filter(Camera.enabled == True).all()
            for cam in cameras:
                self._start_worker(cam.id, cam.rtsp_url)
            logger.info(f"WorkerManager: started {len(cameras)} camera workers")
        finally:
            db.close()

    def stop_all(self):
        for worker in self._workers.values():
            worker.stop()
        self._workers.clear()
        logger.info("WorkerManager: all workers stopped")

    def restart_camera(self, camera_id: int, rtsp_url: str):
        """Call this when a camera is added or updated via API."""
        self.stop_camera(camera_id)
        self._start_worker(camera_id, rtsp_url)

    def stop_camera(self, camera_id: int):
        worker = self._workers.pop(camera_id, None)
        if worker:
            worker.stop()

    def _start_worker(self, camera_id: int, rtsp_url: str):
        if not self._detector or not self._loop:
            return
        worker = CameraWorker(camera_id, rtsp_url, self._detector, self._loop)
        self._workers[camera_id] = worker
        worker.start()


worker_manager = WorkerManager()
