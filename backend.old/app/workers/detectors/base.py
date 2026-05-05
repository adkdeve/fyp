from dataclasses import dataclass, field
from ...models.violation import ViolationType, Severity


@dataclass
class Detection:
    type: ViolationType
    severity: Severity
    confidence: float
    bbox: list[float] = field(default_factory=list)  # [x1, y1, x2, y2]


class BaseDetector:
    """All detectors must implement this interface."""

    def detect(self, frame) -> list[Detection]:
        raise NotImplementedError
