"""
Thread-safe store for the latest annotated JPEG frame per camera.
The camera worker writes here; the stream API reads from here.
Uses string camera IDs (Firebase document IDs).

Provides an efficient event-based notification so the MJPEG stream
endpoint can push frames immediately when they arrive instead of polling.
"""
import threading
from dataclasses import dataclass, field


@dataclass
class _CameraSlot:
    jpeg: bytes = b""
    version: int = 0
    event: threading.Event = field(default_factory=threading.Event)
    lock: threading.Lock = field(default_factory=threading.Lock)


_slots: dict[str, _CameraSlot] = {}
_slots_lock = threading.Lock()


def _get_slot(camera_id: str) -> _CameraSlot:
    with _slots_lock:
        if camera_id not in _slots:
            _slots[camera_id] = _CameraSlot()
        return _slots[camera_id]


def put_frame(camera_id: str, jpeg_bytes: bytes) -> None:
    slot = _get_slot(camera_id)
    with slot.lock:
        slot.jpeg = jpeg_bytes
        slot.version += 1
        slot.event.set()  # Wake up any waiting stream consumers


def get_frame(camera_id: str) -> bytes | None:
    with _slots_lock:
        slot = _slots.get(camera_id)
    if slot is None:
        return None
    with slot.lock:
        return slot.jpeg if slot.jpeg else None


def wait_for_frame(camera_id: str, last_version: int = -1,
                   timeout: float = 1.0) -> tuple[bytes | None, int]:
    """
    Block until a new frame is available (version > last_version) or timeout.
    Returns (jpeg_bytes, current_version).
    This avoids busy-polling in the MJPEG stream endpoint.
    """
    slot = _get_slot(camera_id)

    # If we already have a newer frame, return immediately
    with slot.lock:
        if slot.version > last_version and slot.jpeg:
            v = slot.version
            j = slot.jpeg
            slot.event.clear()
            return j, v

    # Wait for the worker to push a new frame
    slot.event.wait(timeout=timeout)

    with slot.lock:
        slot.event.clear()
        if slot.version > last_version and slot.jpeg:
            return slot.jpeg, slot.version
        return (slot.jpeg if slot.jpeg else None), slot.version


def remove_camera(camera_id: str) -> None:
    with _slots_lock:
        slot = _slots.pop(camera_id, None)
    if slot:
        slot.event.set()  # Wake up any waiting consumers so they can exit
