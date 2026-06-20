"""
/api/v1/ai-controls — Backend API for AI Detection model toggles.

The frontend calls these endpoints (instead of the ML service directly) so that:
  1. The backend can store current preferences and push them to camera workers
  2. Camera workers pass enabled_models with every /detect call → no ML service state dependency
  3. Works correctly even after ML service restarts
"""
import logging
# pyrefly: ignore [missing-import]
from fastapi import APIRouter
# pyrefly: ignore [missing-import]
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/ai-controls", tags=["AI Detection Controls"])

# In-memory store of active model preferences (persists for backend lifetime)
_active_models: dict[str, bool] = {
    "helmet":       False,
    "firesmoke":    False,
}


class ToggleRequest(BaseModel):
    model: str   # "helmet" | "firesmoke"
    active: bool


class BulkToggleRequest(BaseModel):
    models: dict[str, bool]   # e.g. {"helmet": true, "firesmoke": false}


def _broadcast_to_workers(models: dict[str, bool]):
    """Push enabled_models to all running camera workers."""
    try:
        from ..workers.manager import worker_manager
        worker_manager.update_enabled_models("*", models)
    except Exception as e:
        logger.warning(f"[AIControls] Worker update error: {e}")


@router.get("/status")
def get_status():
    """Return current enabled model state."""
    return {"active_models": _active_models}


@router.post("/toggle")
def toggle_model(body: ToggleRequest):
    """Toggle a single AI model on/off and push to all camera workers."""
    global _active_models
    if body.model not in _active_models:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail=f"Unknown model: {body.model}")

    _active_models[body.model] = body.active
    _broadcast_to_workers(_active_models)
    return {"status": "ok", "active_models": _active_models}


@router.post("/bulk")
def bulk_toggle(body: BulkToggleRequest):
    """Set multiple models at once (called on page load to sync preferences)."""
    global _active_models
    for k, v in body.models.items():
        if k in _active_models:
            _active_models[k] = bool(v)
    _broadcast_to_workers(_active_models)
    return {"status": "ok", "active_models": _active_models}
