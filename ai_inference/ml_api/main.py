from contextlib import asynccontextmanager

# Windows multiprocessing MUST be configured before any module that
# creates multiprocessing objects is imported.
import multiprocessing as _mp
_mp.freeze_support()
if _mp.current_process().name == "MainProcess":
    try:
        _mp.set_start_method("spawn", force=False)
    except RuntimeError:
        pass  # already set

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from models.safe_zone.router import router as safe_zone_router
from models.fire_smoke.router import router as fire_router
from models.helmet.router import router as helmet_router
from stream.router import router as stream_router, stream_mgr
from detect_router import router as detect_router



@asynccontextmanager
async def lifespan(app):
    """Boot the ML worker once when the server starts. Models load here — never again."""
    print("=" * 60)
    print("🚀 ML Service starting — booting ML worker...")
    print("   Models will load once in the background process.")
    print("   Source switches (laptop/IP/video) will take 1-2s after this.")
    print("=" * 60)
    stream_mgr.boot_worker()
    yield
    print("🛑 Server shutting down — terminating ML worker...")
    stream_mgr.shutdown_worker()


app = FastAPI(title="ML Inference Service", lifespan=lifespan)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global State
app.state.active_models = {
    "safezone": False,
    "firesmoke": False,
    "helmet": False
}
app.state.safe_zone_polygon = []

app.include_router(safe_zone_router,   prefix="/models/safe-zone",    tags=["Safe Zone"])
app.include_router(fire_router,        prefix="/models/fire-smoke",   tags=["Fire Smoke"])
app.include_router(helmet_router,      prefix="/models/helmet",       tags=["Helmet Detection"])
app.include_router(stream_router,      prefix="/stream",              tags=["Stream"])
# Unified detection endpoint — used by backend camera workers
app.include_router(detect_router, tags=["Detection"])


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "ml_api"}
