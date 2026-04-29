from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.alert import Alert
from ..models.camera import Camera
from ..models.user import User
from ..models.violation import Severity, Violation
from ..schemas.alert import AlertOut
from .deps import get_current_user

router = APIRouter(prefix="/alerts", tags=["Alerts"])


@router.get("", response_model=list[AlertOut])
def list_alerts(
    unread_only: bool = Query(False),
    q: str | None = Query(None),
    severity: Severity | None = Query(None),
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Alert).join(Alert.violation).join(Violation.camera)
    query = query.filter(Alert.user_id == current_user.id)
    if unread_only:
        query = query.filter(Alert.read == False)
    if severity:
        query = query.filter(Violation.severity == severity)
    if q:
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(
                Violation.notes.ilike(like),
                Camera.name.ilike(like),
                Camera.location.ilike(like),
            )
        )
    return query.order_by(Alert.created_at.desc()).limit(limit).all()


@router.patch("/{alert_id}/read", response_model=AlertOut)
def mark_read(
    alert_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    alert = db.get(Alert, alert_id)
    if not alert or alert.user_id != current_user.id:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Alert not found")
    alert.read = True
    db.commit()
    db.refresh(alert)
    return alert


@router.patch("/read-all", response_model=dict)
def mark_all_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db.query(Alert).filter(
        Alert.user_id == current_user.id,
        Alert.read == False,
    ).update({"read": True})
    db.commit()
    return {"message": "All alerts marked as read"}


@router.patch("/mark-all-read", response_model=dict)
def mark_all_read_legacy(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return mark_all_read(db=db, current_user=current_user)
