from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.camera import Camera, CameraStatus
from ..models.user import User
from ..schemas.camera import CameraCreate, CameraUpdate, CameraOut
from .deps import can_access_camera, get_current_user, is_admin, scope_camera_query
from ..workers.manager import worker_manager

router = APIRouter(prefix="/cameras", tags=["Cameras"])


def _desired_status(enabled: bool) -> CameraStatus:
    return CameraStatus.online if enabled else CameraStatus.offline


def _serialize_camera(camera: Camera, current_user: User) -> dict:
    payload = CameraOut.model_validate(camera).model_dump()
    if not is_admin(current_user):
        payload["rtsp_url"] = None
    return payload


@router.get("", response_model=list[CameraOut])
def list_cameras(
    enabled_only: bool = False,
    enabled: bool | None = Query(None),
    status: CameraStatus | None = Query(None),
    q: str | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = scope_camera_query(db.query(Camera), current_user)
    if enabled_only:
        query = query.filter(Camera.enabled == True)
    if enabled is not None:
        query = query.filter(Camera.enabled == enabled)
    if status is not None:
        query = query.filter(Camera.status == status)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(or_(Camera.name.ilike(like), Camera.location.ilike(like)))
    cameras = query.order_by(Camera.name).all()
    return [_serialize_camera(camera, current_user) for camera in cameras]


@router.get("/{camera_id}", response_model=CameraOut)
def get_camera(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    camera = db.get(Camera, camera_id)
    if not can_access_camera(current_user, camera):
        raise HTTPException(status_code=404, detail="Camera not found")
    return _serialize_camera(camera, current_user)


@router.post("", response_model=CameraOut, status_code=201)
def create_camera(
    body: CameraCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not is_admin(current_user):
        raise HTTPException(status_code=403, detail="Admin access required")
    camera = Camera(**body.model_dump())
    camera.status = _desired_status(camera.enabled)
    db.add(camera)
    db.commit()
    db.refresh(camera)
    # Start inference worker immediately if camera is enabled
    if camera.enabled:
        worker_manager.restart_camera(camera.id, camera.rtsp_url)
    return _serialize_camera(camera, current_user)


@router.patch("/{camera_id}", response_model=CameraOut)
def update_camera(
    camera_id: int,
    body: CameraUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    camera = db.get(Camera, camera_id)
    if not can_access_camera(current_user, camera):
        raise HTTPException(status_code=404, detail="Camera not found")
    changes = body.model_dump(exclude_unset=True)
    if not is_admin(current_user):
        if set(changes.keys()) - {"enabled"}:
            raise HTTPException(
                status_code=403,
                detail="Supervisors can only enable or disable assigned site cameras",
            )
    for field, value in changes.items():
        setattr(camera, field, value)
    camera.status = _desired_status(camera.enabled)
    db.commit()
    db.refresh(camera)
    # Restart worker with updated URL / re-enable if needed
    if camera.enabled:
        worker_manager.restart_camera(camera.id, camera.rtsp_url)
    else:
        worker_manager.stop_camera(camera.id)
    return _serialize_camera(camera, current_user)


@router.delete("/{camera_id}", status_code=204)
def delete_camera(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not is_admin(current_user):
        raise HTTPException(status_code=403, detail="Admin access required")
    camera = db.get(Camera, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    worker_manager.stop_camera(camera.id)
    db.delete(camera)
    db.commit()
