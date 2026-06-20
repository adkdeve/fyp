import asyncio
import logging
from datetime import datetime

from fastapi import APIRouter
from fastapi.responses import Response, StreamingResponse

from ..core.config import settings
from ..workers import frame_store
from ..workers.camera_worker import _make_placeholder

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/stream", tags=["Stream"])

_BOUNDARY = b"frame"
_BOUNDARY_SEP = b"--frame\r\nContent-Type: image/jpeg\r\n\r\n"
_BOUNDARY_END = b"\r\n"


# ── Single JPEG frame ────────────────────────────────────────────────────
@router.get("/{camera_id}/frame")
def get_frame(camera_id: str):
    """Returns the latest annotated JPEG frame for a camera."""
    jpeg = frame_store.get_frame(camera_id)
    if jpeg is None:
        jpeg = _make_placeholder("No Signal")
    return Response(
        content=jpeg,
        media_type="image/jpeg",
        headers={
            "Cache-Control": "no-cache, no-store",
            "Access-Control-Allow-Origin": "*",   # Allow canvas drawImage()
        },
    )


# ── True MJPEG stream (browser / VLC friendly) ────────────────────────────
@router.get("/{camera_id}")
async def mjpeg_stream(camera_id: str):
    """
    Streams MJPEG (multipart/x-mixed-replace).
    Open in browser: http://host:8000/api/v1/stream/{camera_id}

    Uses event-based waiting so frames are pushed as soon as they
    are produced by the camera worker — no fixed sleep interval.
    """
    async def generator():
        last_version = -1
        while True:
            # Run the blocking wait_for_frame in a thread so we don't
            # block the asyncio event loop
            jpeg, last_version = await asyncio.to_thread(
                frame_store.wait_for_frame,
                camera_id,
                last_version,
                timeout=1.0,  # max wait before sending a keep-alive frame
            )
            if jpeg is None:
                jpeg = _make_placeholder("No Signal")
            yield _BOUNDARY_SEP + jpeg + _BOUNDARY_END

    return StreamingResponse(
        generator(),
        media_type=f"multipart/x-mixed-replace; boundary={_BOUNDARY.decode()}",
        headers={
            "Cache-Control": "no-cache, no-store",
            "X-Accel-Buffering": "no",        # Disable nginx buffering
            "Transfer-Encoding": "chunked",
        },
    )
