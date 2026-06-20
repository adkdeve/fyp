import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from .core.config import settings
from .core.firebase_db import init_firebase
from .api.router import api_router
from .api.ws import router as ws_router
from .workers.manager import worker_manager

logging.basicConfig(level=logging.INFO)
logging.getLogger("app.workers.detectors.yolo").setLevel(logging.DEBUG)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── startup ──────────────────────────────────────────────────────────
    os.makedirs(settings.media_dir, exist_ok=True)
    init_firebase()
    loop = asyncio.get_event_loop()
    worker_manager.start_all(loop)
    logger.info("✅ Construction Safety API started (Firebase backend)")
    yield
    # ── shutdown ─────────────────────────────────────────────────────────
    worker_manager.stop_all()
    logger.info("🛑 API shut down")


app = FastAPI(title="Construction Safety API", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve snapshot images
os.makedirs(settings.media_dir, exist_ok=True)
app.mount("/media", StaticFiles(directory=settings.media_dir), name="media")

app.include_router(api_router)
app.include_router(ws_router)


@app.get("/health")
def health():
    return {"status": "ok", "ml_api_url": settings.ml_api_url, "backend": "firebase"}
