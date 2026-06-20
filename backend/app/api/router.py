from fastapi import APIRouter
from .stream import router as stream_router
from .violations import router as violations_router
from .cameras import router as cameras_router
from .safe_zone import router as safe_zone_router
from .faces import router as faces_router
from .ai_controls import router as ai_controls_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(stream_router)
api_router.include_router(violations_router)
api_router.include_router(cameras_router)
api_router.include_router(safe_zone_router)
api_router.include_router(faces_router)
api_router.include_router(ai_controls_router)
