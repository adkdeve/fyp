from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.camera import Camera, CameraStatus
from ..models.user import User
from ..schemas.camera import CameraCreate, CameraUpdate, CameraOut
from .deps import require_supervisor, get_current_user
from ..workers.manager import worker_manager

router = APIRouter(prefix="/cameras", tags=["Cameras"])


@router.get("", response_model=list[CameraOut])
def list_cameras(
    enabled_only: bool = False,
    enabled: bool | None = Query(None),
    status: CameraStatus | None = Query(None),
    q: str | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    query = db.query(Camera)
    if enabled_only:
        query = query.filter(Camera.enabled == True)
    if enabled is not None:
        query = query.filter(Camera.enabled == enabled)
    if status is not None:
        query = query.filter(Camera.status == status)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(or_(Camera.name.ilike(like), Camera.location.ilike(like)))
    return query.order_by(Camera.name).all()


@router.get("/{camera_id}", response_model=CameraOut)
def get_camera(
    camera_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    camera = db.get(Camera, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    return camera


@router.post("", response_model=CameraOut, status_code=201)
def create_camera(
    body: CameraCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_supervisor),
):
    camera = Camera(**body.model_dump())
    db.add(camera)
    db.commit()
    db.refresh(camera)
    # Start inference worker immediately if camera is enabled
    if camera.enabled:
        worker_manager.restart_camera(camera.id, camera.rtsp_url)
    return camera


@router.patch("/{camera_id}", response_model=CameraOut)
def update_camera(
    camera_id: int,
    body: CameraUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_supervisor),
):
    camera = db.get(Camera, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(camera, field, value)
    db.commit()
    db.refresh(camera)
    # Restart worker with updated URL / re-enable if needed
    if camera.enabled:
        worker_manager.restart_camera(camera.id, camera.rtsp_url)
    else:
        worker_manager.stop_camera(camera.id)
    return camera


@router.delete("/{camera_id}", status_code=204)
def delete_camera(
    camera_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_supervisor),
):
    camera = db.get(Camera, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    worker_manager.stop_camera(camera.id)
    db.delete(camera)
    db.commit()
