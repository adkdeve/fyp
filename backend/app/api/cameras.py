"""
Camera management API — reads/writes to Firebase Firestore.
Manages worker lifecycle for camera streams.
"""
import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..core.firebase_db import get_firestore
from ..workers.manager import worker_manager

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/cameras", tags=["Cameras"])


class CameraStartRequest(BaseModel):
    camera_id: str
    rtsp_url: str


@router.get("")
def list_cameras():
    """List all cameras from Firestore."""
    db = get_firestore()
    docs = db.collection("cameras").stream()
    cameras = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        cameras.append(data)
    return cameras


@router.post("/start")
def start_camera(body: CameraStartRequest):
    """Start a camera worker for inference + streaming."""
    worker_manager.restart_camera(body.camera_id, body.rtsp_url)
    return {"status": "started", "camera_id": body.camera_id}


@router.post("/stop/{camera_id}")
def stop_camera(camera_id: str):
    """Stop a camera worker."""
    worker_manager.stop_camera(camera_id)
    return {"status": "stopped", "camera_id": camera_id}


@router.get("/active")
def active_cameras():
    """List camera IDs with active workers."""
    return {"active": list(worker_manager._workers.keys())}
