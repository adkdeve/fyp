from datetime import datetime
from pydantic import BaseModel
from ..models.camera import CameraStatus


class SiteOut(BaseModel):
    id: int
    name: str
    address: str | None

    model_config = {"from_attributes": True}


class SiteCreate(BaseModel):
    name: str
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None


class CameraCreate(BaseModel):
    name: str
    rtsp_url: str
    location: str | None = None
    site_id: int | None = None
    enabled: bool = True
    fps_target: int = 5


class CameraUpdate(BaseModel):
    name: str | None = None
    rtsp_url: str | None = None
    location: str | None = None
    site_id: int | None = None
    enabled: bool | None = None
    fps_target: int | None = None


class CameraOut(BaseModel):
    id: int
    name: str
    rtsp_url: str | None
    location: str | None
    enabled: bool
    status: CameraStatus
    fps_target: int
    last_seen_at: datetime | None
    created_at: datetime
    site: SiteOut | None

    model_config = {"from_attributes": True}
