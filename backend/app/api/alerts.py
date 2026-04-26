from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.alert import Alert
from ..models.user import User
from ..schemas.alert import AlertOut
from .deps import get_current_user

router = APIRouter(prefix="/alerts", tags=["Alerts"])


@router.get("", response_model=list[AlertOut])
def list_alerts(
    unread_only: bool = Query(False),
    limit: int = Query(50, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    q = db.query(Alert).filter(Alert.user_id == current_user.id)
    if unread_only:
        q = q.filter(Alert.read == False)
    return q.order_by(Alert.created_at.desc()).limit(limit).all()


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
