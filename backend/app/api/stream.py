import asyncio
import logging
import os
from datetime import datetime

from fastapi import APIRouter, Depends
from fastapi.responses import Response, StreamingResponse

from ..core.config import settings
from ..core.db import SessionLocal
from ..models.camera import Camera
from ..models.user import User
from .deps import can_access_camera, get_current_user
from ..workers import frame_store
from ..workers.camera_worker import _make_placeholder

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/stream", tags=["Stream"])

_BOUNDARY = b"frame"
_BOUNDARY_SEP = b"--frame\r\nContent-Type: image/jpeg\r\n\r\n"
_BOUNDARY_END = b"\r\n"


def _get_accessible_camera(camera_id: int, current_user: User) -> Camera | None:
    db = SessionLocal()
    try:
        camera = db.get(Camera, camera_id)
        if not can_access_camera(current_user, camera):
            return None
        return camera
    finally:
        db.close()


# ── Single JPEG frame (Flutter polls this) ────────────────────────────────────

@router.get("/{camera_id}/frame")
def get_frame(
    camera_id: int,
    current_user: User = Depends(get_current_user),
):
    """Returns the latest annotated JPEG frame for a camera."""
    camera = _get_accessible_camera(camera_id, current_user)
    if camera is None:
        return Response(status_code=404)
    if not camera.enabled:
        jpeg = _make_placeholder("Camera Disabled")
        return Response(content=jpeg, media_type="image/jpeg",
                        headers={"Cache-Control": "no-cache, no-store"})
    jpeg = frame_store.get_frame(camera_id)
    if jpeg is None:
        jpeg = _make_placeholder("No Signal")
    return Response(content=jpeg, media_type="image/jpeg",
                    headers={"Cache-Control": "no-cache, no-store"})


@router.post("/{camera_id}/snapshot")
def save_snapshot(
    camera_id: int,
    current_user: User = Depends(get_current_user),
):
    camera = _get_accessible_camera(camera_id, current_user)
    if camera is None:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Camera not found")
    if not camera.enabled:
        from fastapi import HTTPException
        raise HTTPException(status_code=409, detail="Camera is disabled")
    jpeg = frame_store.get_frame(camera_id)
    if jpeg is None:
        jpeg = _make_placeholder("No Signal")

    snap_dir = os.path.join(settings.media_dir, "snapshots", "manual", str(camera_id))
    os.makedirs(snap_dir, exist_ok=True)
    filename = datetime.utcnow().strftime("%Y%m%d_%H%M%S_%f") + ".jpg"
    fpath = os.path.join(snap_dir, filename)
    with open(fpath, "wb") as out:
        out.write(jpeg)
    return {"snapshot_url": f"/media/snapshots/manual/{camera_id}/{filename}"}


# ── True MJPEG stream (browser / VLC friendly) ────────────────────────────────

@router.get("/{camera_id}")
async def mjpeg_stream(
    camera_id: int,
    current_user: User = Depends(get_current_user),
):
    """
    Streams MJPEG (multipart/x-mixed-replace).
    Open in browser or VLC: http://host:8000/stream/{id}?token=...
    """
    if _get_accessible_camera(camera_id, current_user) is None:
        return Response(status_code=404)

    async def generator():
        while True:
            current_camera = _get_accessible_camera(camera_id, current_user)
            if current_camera is None:
                break
            if not current_camera.enabled:
                jpeg = _make_placeholder("Camera Disabled")
            else:
                jpeg = frame_store.get_frame(camera_id)
            if jpeg is None:
                jpeg = _make_placeholder("No Signal")
            yield _BOUNDARY_SEP + jpeg + _BOUNDARY_END
            await asyncio.sleep(0.2)          # ~5 fps

    return StreamingResponse(
        generator(),
        media_type=f"multipart/x-mixed-replace; boundary={_BOUNDARY.decode()}",
        headers={"Cache-Control": "no-cache, no-store"},
    )
