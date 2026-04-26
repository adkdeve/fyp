from datetime import datetime
from pydantic import BaseModel
from ..models.violation import ViolationType, Severity, ViolationStatus
from .camera import CameraOut


class ViolationOut(BaseModel):
    id: int
    camera_id: int
    type: ViolationType
    severity: Severity
    status: ViolationStatus
    confidence: float
    snapshot_url: str | None
    notes: str | None
    detected_at: datetime
    resolved_at: datetime | None
    camera: CameraOut

    model_config = {"from_attributes": True}


class ViolationCreate(BaseModel):
    camera_id: int
    type: ViolationType
    severity: Severity = Severity.medium
    confidence: float
    snapshot_url: str | None = None
    bbox_json: str | None = None
    notes: str | None = None


class ViolationResolve(BaseModel):
    status: ViolationStatus
    notes: str | None = None


class ViolationFilter(BaseModel):
    camera_id: int | None = None
    type: ViolationType | None = None
    severity: Severity | None = None
    status: ViolationStatus | None = None
    from_date: datetime | None = None
    to_date: datetime | None = None
