import asyncio
import logging
from ..models.camera import CameraStatus
from ..core.db import SessionLocal
from ..core.config import settings
from ..models.camera import Camera
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
        logger.warning("Using MockDetector. This is for development only and does not provide real safety detections.")
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
        self.stop_camera(camera_id, update_status=False)
        self._start_worker(camera_id, rtsp_url)

    def stop_camera(self, camera_id: int, update_status: bool = True):
        worker = self._workers.pop(camera_id, None)
        if worker:
            worker.stop()
        if not update_status:
            return
        db = SessionLocal()
        try:
            cam = db.get(Camera, camera_id)
            if cam:
                cam.status = CameraStatus.offline
                db.commit()
        except Exception:
            db.rollback()
            logger.exception(f"WorkerManager: failed to set camera {camera_id} offline")
        finally:
            db.close()

    def _start_worker(self, camera_id: int, rtsp_url: str):
        if not self._detector or not self._loop:
            return
        worker = CameraWorker(camera_id, rtsp_url, self._detector, self._loop)
        self._workers[camera_id] = worker
        worker.start()


worker_manager = WorkerManager()
