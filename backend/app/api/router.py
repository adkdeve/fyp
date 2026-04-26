from fastapi import APIRouter
from .auth import router as auth_router
from .cameras import router as cameras_router
from .sites import router as sites_router
from .violations import router as violations_router
from .alerts import router as alerts_router
from .analytics import router as analytics_router
from .stream import router as stream_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth_router)
api_router.include_router(sites_router)
api_router.include_router(cameras_router)
api_router.include_router(violations_router)
api_router.include_router(alerts_router)
api_router.include_router(analytics_router)
api_router.include_router(stream_router)
