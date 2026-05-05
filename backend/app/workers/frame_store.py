"""
Thread-safe store for the latest annotated JPEG frame per camera.
The camera worker writes here; the stream API reads from here.
Uses string camera IDs (Firebase document IDs).
"""
import threading

_frames: dict[str, bytes] = {}
_lock = threading.Lock()


def put_frame(camera_id: str, jpeg_bytes: bytes) -> None:
    with _lock:
        _frames[camera_id] = jpeg_bytes


def get_frame(camera_id: str) -> bytes | None:
    with _lock:
        return _frames.get(camera_id)


def remove_camera(camera_id: str) -> None:
    with _lock:
        _frames.pop(camera_id, None)
