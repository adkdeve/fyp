from fastapi import APIRouter, Request
from pydantic import BaseModel

router = APIRouter()

class ToggleRequest(BaseModel):
    active: bool

@router.post("/toggle")
def toggle_model(request: Request, payload: ToggleRequest):
    request.app.state.active_models["firesmoke"] = payload.active
    # Immediately sync to the ML worker process  don't wait for next video frame
    from stream.router import stream_mgr
    stream_mgr.update_flags(request.app.state)
    return {"status": "success", "active": payload.active}
