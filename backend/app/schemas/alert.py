from datetime import datetime
from pydantic import BaseModel
from ..models.alert import AlertChannel


class AlertOut(BaseModel):
    id: int
    violation_id: int
    channel: AlertChannel
    delivered: bool
    read: bool
    created_at: datetime

    model_config = {"from_attributes": True}
