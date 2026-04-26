from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.violation import Violation, ViolationType, Severity, ViolationStatus
from ..models.user import User
from ..schemas.violation import ViolationOut, ViolationCreate, ViolationResolve
from .deps import get_current_user

router = APIRouter(prefix="/violations", tags=["Violations"])


@router.get("", response_model=list[ViolationOut])
def list_violations(
    camera_id: int | None = Query(None),
    type: ViolationType | None = Query(None),
    severity: Severity | None = Query(None),
    status: ViolationStatus | None = Query(None),
    from_date: datetime | None = Query(None),
    to_date: datetime | None = Query(None),
    limit: int = Query(50, le=200),
    offset: int = Query(0),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Violation)
    if camera_id:
        q = q.filter(Violation.camera_id == camera_id)
    if type:
        q = q.filter(Violation.type == type)
    if severity:
        q = q.filter(Violation.severity == severity)
    if status:
        q = q.filter(Violation.status == status)
    if from_date:
        q = q.filter(Violation.detected_at >= from_date)
    if to_date:
        q = q.filter(Violation.detected_at <= to_date)
    return q.order_by(Violation.detected_at.desc()).offset(offset).limit(limit).all()


@router.get("/{violation_id}", response_model=ViolationOut)
def get_violation(
    violation_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    v = db.get(Violation, violation_id)
    if not v:
        raise HTTPException(status_code=404, detail="Violation not found")
    return v


@router.post("", response_model=ViolationOut, status_code=201)
def create_violation(
    body: ViolationCreate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Normally called by the inference worker, but exposed for testing."""
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
    if not v:
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
