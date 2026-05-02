import csv
import io
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..core.db import get_db
from ..models.violation import Violation, ViolationType, Severity, ViolationStatus
from ..models.camera import Camera, CameraStatus
from ..models.alert import Alert
from ..models.user import User
from .deps import get_current_user, scope_site_query

router = APIRouter(prefix="/analytics", tags=["Analytics"])


@router.get("/summary")
def summary(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)

    scoped_violations = scope_site_query(
        db.query(Violation).join(Violation.camera),
        current_user,
        Camera.site_id,
    ).filter(Camera.enabled == True)
    enabled_cameras = scope_site_query(
        db.query(Camera).filter(Camera.enabled == True),
        current_user,
        Camera.site_id,
    )

    total = scoped_violations.filter(Violation.detected_at >= since).count()
    open_count = scoped_violations.filter(
        Violation.detected_at >= since,
        Violation.status == ViolationStatus.open,
    ).count()
    high = scoped_violations.filter(
        Violation.detected_at >= since,
        Violation.severity == Severity.high,
    ).count()
    cameras_active = enabled_cameras.filter(Camera.status == CameraStatus.online).count()
    active_zones = enabled_cameras.count()
    unread_alerts = scope_site_query(
        db.query(Alert).join(Alert.violation).join(Violation.camera),
        current_user,
        Camera.site_id,
    ).filter(Alert.read == False).count()
    resolved = scoped_violations.filter(
        Violation.detected_at >= since,
        Violation.status == ViolationStatus.resolved,
    ).count()
    false_positive = scoped_violations.filter(
        Violation.detected_at >= since,
        Violation.status == ViolationStatus.false_positive,
    ).count()
    avg_response_seconds = scoped_violations.with_entities(
        func.avg(func.extract("epoch", Violation.resolved_at - Violation.detected_at))
    ).filter(
        Violation.detected_at >= since,
        Violation.resolved_at.isnot(None),
    ).scalar()
    avg_fps = enabled_cameras.with_entities(func.avg(Camera.fps_target)).scalar()

    enabled_camera_ids = [
        camera_id
        for (camera_id,) in enabled_cameras.with_entities(Camera.id).all()
    ]
    open_camera_ids = set()
    if enabled_camera_ids:
        open_camera_ids = {
            camera_id
            for (camera_id,) in scoped_violations.with_entities(Violation.camera_id)
            .filter(
                Violation.status == ViolationStatus.open,
                Violation.camera_id.in_(enabled_camera_ids),
            )
            .distinct()
            .all()
        }
    compliant_cameras = max(active_zones - len(open_camera_ids), 0)
    compliance_rate = round((compliant_cameras / active_zones) * 100) if active_zones else 100
    detection_accuracy = round(((total - false_positive) / total) * 100) if total else 0

    return {
        "period_days": days,
        "total_violations": total,
        "open_violations": open_count,
        "resolved": resolved,
        "high_severity": high,
        "cameras_active": cameras_active,
        "unread_alerts": unread_alerts,
        "active_zones": active_zones,
        "compliant_cameras": compliant_cameras,
        "compliance_rate": compliance_rate,
        "avg_response_time": round(float(avg_response_seconds or 0), 1),
        "detection_accuracy": detection_accuracy,
        "false_positive_rate": round(((false_positive or 0) / total) * 100, 1) if total else 0,
        "processing_fps": round(float(avg_fps or 0)),
    }


@router.get("/by-type")
def by_type(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        scope_site_query(
            db.query(Violation.type, func.count(Violation.id)).join(Violation.camera),
            current_user,
            Camera.site_id,
        ).filter(Camera.enabled == True)
        .filter(Violation.detected_at >= since)
        .group_by(Violation.type)
        .all()
    )
    return [{"type": r[0], "count": r[1]} for r in rows]


@router.get("/by-severity")
def by_severity(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        scope_site_query(
            db.query(Violation.severity, func.count(Violation.id)).join(Violation.camera),
            current_user,
            Camera.site_id,
        ).filter(Camera.enabled == True)
        .filter(Violation.detected_at >= since)
        .group_by(Violation.severity)
        .all()
    )
    return [{"severity": r[0], "count": r[1]} for r in rows]


@router.get("/trend")
def trend(
    days: int = Query(7, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns daily violation counts for the last N days."""
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        scope_site_query(
            db.query(
                func.date(Violation.detected_at).label("day"),
                func.count(Violation.id).label("count"),
            ).join(Violation.camera),
            current_user,
            Camera.site_id,
        ).filter(Camera.enabled == True)
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
    current_user: User = Depends(get_current_user),
):
    since = datetime.utcnow() - timedelta(days=days)
    rows = (
        scope_site_query(
            db.query(Camera.name, func.count(Violation.id))
            .join(Violation, Violation.camera_id == Camera.id),
            current_user,
            Camera.site_id,
        ).filter(Camera.enabled == True)
        .filter(Violation.detected_at >= since)
        .group_by(Camera.name)
        .order_by(func.count(Violation.id).desc())
        .all()
    )
    return [{"camera": r[0], "camera_name": r[0], "count": r[1]} for r in rows]


@router.get("/export")
def export_analytics(
    days: int = Query(7, ge=1, le=365),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["section", "name", "value"])

    s = summary(days=days, db=db, current_user=current_user)
    for key, value in s.items():
        writer.writerow(["summary", key, value])

    for row in by_type(days=days, db=db, current_user=current_user):
        writer.writerow(["by_type", row["type"], row["count"]])
    for row in by_severity(days=days, db=db, current_user=current_user):
        writer.writerow(["by_severity", row["severity"], row["count"]])
    for row in trend(days=min(days, 365), db=db, current_user=current_user):
        writer.writerow(["trend", row["date"], row["count"]])
    for row in by_camera(days=days, db=db, current_user=current_user):
        writer.writerow(["by_camera", row["camera_name"], row["count"]])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=analytics.csv"},
    )
