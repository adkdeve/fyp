"""
Helmet Detection Router
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

router = APIRouter()

# Global state for helmet model
_helmet_active = False


class ToggleRequest(BaseModel):
    active: bool


@router.post("/toggle")
def toggle_helmet(req: Request, request: ToggleRequest):
    """Toggle helmet detection on/off"""
    global _helmet_active
    _helmet_active = request.active
    req.app.state.active_models["helmet"] = request.active
    # Immediately sync to the ML worker process so helmet starts/stops without waiting.
    from stream.router import stream_mgr
    stream_mgr.update_flags(req.app.state)
    return {"active": _helmet_active, "model": "helmet"}


@router.get("/status")
def get_status():
    """Get current helmet detection status"""
    return {"active": _helmet_active, "model": "helmet"}


@router.post("/load")
def load_model():
    """Load the helmet detection model"""
    try:
        from models_logic.helmet_detector import load_helmet_model
        model = load_helmet_model()
        if model is None:
            raise HTTPException(status_code=500, detail="Failed to load helmet model")
        return {"status": "loaded", "model": "helmet"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/is_active")
def is_active():
    """Check if helmet detection is active"""
    return {"active": _helmet_active}
