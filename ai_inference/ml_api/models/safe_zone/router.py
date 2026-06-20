from fastapi import APIRouter, Request
from pydantic import BaseModel
from typing import List, Tuple

router = APIRouter()

class ToggleRequest(BaseModel):
    active: bool

class PolygonRequest(BaseModel):
    points: List[Tuple[float, float]]

@router.post("/toggle")
def toggle_model(request: Request, payload: ToggleRequest):
    request.app.state.active_models["safezone"] = payload.active
    # Immediately sync to the ML worker process  don't wait for next video frame
    from stream.router import stream_mgr
    stream_mgr.update_flags(request.app.state)
    return {"status": "success", "active": payload.active}

@router.post("/set-polygon")
def set_polygon(request: Request, payload: PolygonRequest):
    request.app.state.safe_zone_polygon = payload.points
    # Sync polygon points to the ML worker process
    from stream.router import stream_mgr
    stream_mgr.update_safe_zone(payload.points)
    print(f" Safe zone polygon set and synced: {len(payload.points)} points")
    return {"status": "success", "points": payload.points}
