from dataclasses import dataclass, field
from ...models.violation import ViolationType, Severity


@dataclass
class Detection:
    type: ViolationType
    severity: Severity
    confidence: float
    bbox: list[float] = field(default_factory=list)  # [x1, y1, x2, y2]
    track_id: int | None = None
    display_only: bool = False  # If True, draw but do NOT record as a violation
    composite_label: str | None = None  # e.g., "No Helmet, No Vest"


class BaseDetector:
    """All detectors must implement this interface."""

    def detect(
        self,
        frame,
        camera_id: str = "default",
        safe_zone_polygon: list | None = None,
    ) -> list[Detection]:
        raise NotImplementedError
