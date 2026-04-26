import asyncio
import logging

from fastapi import APIRouter, Depends
from fastapi.responses import Response, StreamingResponse

from ..models.user import User
from .deps import get_current_user
from ..workers import frame_store
from ..workers.camera_worker import _make_placeholder

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/stream", tags=["Stream"])

_BOUNDARY = b"frame"
_BOUNDARY_SEP = b"--frame\r\nContent-Type: image/jpeg\r\n\r\n"
_BOUNDARY_END = b"\r\n"


# ── Single JPEG frame (Flutter polls this) ────────────────────────────────────

@router.get("/{camera_id}/frame")
def get_frame(
    camera_id: int,
    _: User = Depends(get_current_user),
):
    """Returns the latest annotated JPEG frame for a camera."""
    jpeg = frame_store.get_frame(camera_id)
    if jpeg is None:
        jpeg = _make_placeholder("No Signal")
    return Response(content=jpeg, media_type="image/jpeg",
                    headers={"Cache-Control": "no-cache, no-store"})


# ── True MJPEG stream (browser / VLC friendly) ────────────────────────────────

@router.get("/{camera_id}")
async def mjpeg_stream(
    camera_id: int,
    _: User = Depends(get_current_user),
):
    """
    Streams MJPEG (multipart/x-mixed-replace).
    Open in browser or VLC: http://host:8000/stream/{id}?token=...
    """
    async def generator():
        while True:
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
