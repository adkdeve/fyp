import random
import time
from .base import BaseDetector, Detection
from ...models.violation import ViolationType, Severity


class MockDetector(BaseDetector):
    """
    Generates random violations at a fixed interval for testing.
    Replace with YoloDetector when model.pt is available.
    """

    def __init__(self, interval_seconds: int = 60):
        self._interval = interval_seconds
        self._last_fired: dict[str, float] = {}  # camera_id -> timestamp

    def detect(self, frame, camera_id: str = "default") -> list[Detection]:
        now = time.time()
        last = self._last_fired.get(camera_id, 0)
        if now - last < self._interval:
            return []

        self._last_fired[camera_id] = now

        violation_type = random.choice(list(ViolationType))
        severity = random.choices(
            list(Severity),
            weights=[0.5, 0.35, 0.15],  # low, medium, high
        )[0]
        confidence = round(random.uniform(0.70, 0.99), 2)

        return [Detection(type=violation_type, severity=severity, confidence=confidence)]
