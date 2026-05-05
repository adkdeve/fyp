from datetime import datetime
from pydantic import BaseModel
from ..models.alert import AlertChannel
from .violation import ViolationOut


class AlertOut(BaseModel):
    id: int
    violation_id: int
    channel: AlertChannel
    delivered: bool
    read: bool
    created_at: datetime
    violation: ViolationOut | None = None

    model_config = {"from_attributes": True}
