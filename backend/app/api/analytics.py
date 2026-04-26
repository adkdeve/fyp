from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.violation import Violation, ViolationType, Severity, ViolationStatus
from ..models.camera import Camera
from ..models.alert import Alert
from ..models.user import User
from .deps import get_current_user

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/summary")
def summary(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)
    total = db.query(func.count(Violation.id)).filter(Violation.detected_at >= since).scalar()
    open_count = db.query(func.count(Violation.id)).filter(
        Violation.detected_at >= since,
        Violation.status == ViolationStatus.open,
    ).scalar()
    high = db.query(func.count(Violation.id)).filter(
        Violation.detected_at >= since,
        Violation.severity == Severity.high,
    ).scalar()
    cameras_active = db.query(func.count(Camera.id)).filter(Camera.enabled == True).scalar()
    unread_alerts = db.query(func.count(Alert.id)).filter(Alert.read == False).scalar()

    return {
        "period_days": days,
        "total_violations": total,
        "open_violations": open_count,
        "high_severity": high,
        "cameras_active": cameras_active,
        "unread_alerts": unread_alerts,
    }


@router.get("/by-type")
def by_type(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        db.query(Violation.type, func.count(Violation.id))
        .filter(Violation.detected_at >= since)
        .group_by(Violation.type)
        .all()
    )
    return [{"type": r[0], "count": r[1]} for r in rows]


@router.get("/by-severity")
def by_severity(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        db.query(Violation.severity, func.count(Violation.id))
        .filter(Violation.detected_at >= since)
        .group_by(Violation.severity)
        .all()
    )
    return [{"severity": r[0], "count": r[1]} for r in rows]


@router.get("/trend")
def trend(
    days: int = Query(7, ge=1, le=30),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Returns daily violation counts for the last N days."""
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        db.query(
            func.date(Violation.detected_at).label("day"),
            func.count(Violation.id).label("count"),
        )
        .filter(Violation.detected_at >= since)
        .group_by(func.date(Violation.detected_at))
        .order_by(func.date(Violation.detected_at))
        .all()
    )
    return [{"date": str(r.day), "count": r.count} for r in rows]


@router.get("/by-camera")
def by_camera(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        db.query(Camera.name, func.count(Violation.id))
        .join(Violation, Violation.camera_id == Camera.id)
        .filter(Violation.detected_at >= since)
        .group_by(Camera.name)
        .order_by(func.count(Violation.id).desc())
        .all()
    )
    return [{"camera": r[0], "count": r[1]} for r in rows]
