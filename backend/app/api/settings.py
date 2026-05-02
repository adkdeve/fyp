from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.user import User
from ..schemas.auth import NotificationSettingsOut, NotificationSettingsUpdate
from .deps import get_current_user

router = APIRouter(prefix="/settings", tags=["Settings"])


@router.get("/notifications", response_model=NotificationSettingsOut)
def get_notification_settings(current_user: User = Depends(get_current_user)):
    return NotificationSettingsOut(
        low_alerts=current_user.notify_low_alerts,
        critical_alerts=current_user.notify_critical_alerts,
        medium_alerts=current_user.notify_medium_alerts,
    )


@router.patch("/notifications", response_model=NotificationSettingsOut)
def update_notification_settings(
    body: NotificationSettingsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.low_alerts is not None:
        current_user.notify_low_alerts = body.low_alerts
    if body.critical_alerts is not None:
        current_user.notify_critical_alerts = body.critical_alerts
    if body.medium_alerts is not None:
        current_user.notify_medium_alerts = body.medium_alerts
    db.commit()
    db.refresh(current_user)
    return NotificationSettingsOut(
        low_alerts=current_user.notify_low_alerts,
        critical_alerts=current_user.notify_critical_alerts,
        medium_alerts=current_user.notify_medium_alerts,
    )
