import csv
import io
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.camera import Camera
from ..models.violation import Violation, ViolationType, Severity, ViolationStatus
from ..models.user import User
from ..schemas.violation import ViolationOut, ViolationCreate, ViolationResolve
from .deps import get_current_user, is_admin, scope_site_query

router = APIRouter(prefix="/violations", tags=["Violations"])


@router.get("", response_model=list[ViolationOut])
def list_violations(
    q: str | None = Query(None),
    camera_id: int | None = Query(None),
    type: ViolationType | None = Query(None),
    severity: Severity | None = Query(None),
    status: ViolationStatus | None = Query(None),
    enabled_only: bool = Query(False),
    from_date: datetime | None = Query(None),
    to_date: datetime | None = Query(None),
    limit: int = Query(50, le=200),
    offset: int = Query(0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = scope_site_query(db.query(Violation).join(Violation.camera), current_user, Camera.site_id)
    if enabled_only:
        query = query.filter(Camera.enabled == True)
    if camera_id:
        query = query.filter(Violation.camera_id == camera_id)
    if type:
        query = query.filter(Violation.type == type)
    if severity:
        query = query.filter(Violation.severity == severity)
    if status:
        query = query.filter(Violation.status == status)
    if from_date:
        query = query.filter(Violation.detected_at >= from_date)
    if to_date:
        query = query.filter(Violation.detected_at <= to_date)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(
                Violation.notes.ilike(like),
                Camera.name.ilike(like),
                Camera.location.ilike(like),
            )
        )
    return query.order_by(Violation.detected_at.desc()).offset(offset).limit(limit).all()


@router.get("/export")
def export_violations(
    q: str | None = Query(None),
    camera_id: int | None = Query(None),
    type: ViolationType | None = Query(None),
    severity: Severity | None = Query(None),
    status: ViolationStatus | None = Query(None),
    enabled_only: bool = Query(False),
    from_date: datetime | None = Query(None),
    to_date: datetime | None = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = list_violations(
        q=q,
        camera_id=camera_id,
        type=type,
        severity=severity,
        status=status,
        enabled_only=enabled_only,
        from_date=from_date,
        to_date=to_date,
        limit=200,
        offset=0,
        db=db,
        current_user=current_user,
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "id",
        "camera",
        "location",
        "type",
        "severity",
        "status",
        "confidence",
        "detected_at",
        "resolved_at",
        "notes",
    ])
    for v in rows:
        writer.writerow([
            v.id,
            v.camera.name if v.camera else "",
            v.camera.location if v.camera else "",
            v.type.value,
            v.severity.value,
            v.status.value,
            v.confidence,
            v.detected_at.isoformat() if v.detected_at else "",
            v.resolved_at.isoformat() if v.resolved_at else "",
            v.notes or "",
        ])
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=violations.csv"},
    )


@router.get("/{violation_id}", response_model=ViolationOut)
def get_violation(
    violation_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    v = db.get(Violation, violation_id)
    if not v or not (is_admin(current_user) or (current_user.site_id is not None and v.camera and v.camera.site_id == current_user.site_id)):
        raise HTTPException(status_code=404, detail="Violation not found")
    return v


@router.post("", response_model=ViolationOut, status_code=201)
def create_violation(
    body: ViolationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Normally called by the inference worker, but exposed for testing."""
    camera = db.get(Camera, body.camera_id)
    if not camera or not (is_admin(current_user) or (current_user.site_id is not None and camera.site_id == current_user.site_id)):
        raise HTTPException(status_code=404, detail="Camera not found")
    v = Violation(**body.model_dump())
    db.add(v)
    db.commit()
    db.refresh(v)
    return v


@router.patch("/{violation_id}/resolve", response_model=ViolationOut)
def resolve_violation(
    violation_id: int,
    body: ViolationResolve,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    v = db.get(Violation, violation_id)
    if not v or not (
        is_admin(current_user)
        or (
            current_user.site_id is not None
            and v.camera
            and v.camera.site_id == current_user.site_id
        )
    ):
        raise HTTPException(status_code=404, detail="Violation not found")
    v.status = body.status
    if body.notes:
        v.notes = body.notes
    if body.status == ViolationStatus.resolved:
        v.resolved_at = datetime.utcnow()
        v.resolved_by_id = current_user.id
    db.commit()
    db.refresh(v)
    return v
