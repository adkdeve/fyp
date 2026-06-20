"""
Violation API — reads from Firebase Firestore.
Violations are created by the camera worker when detections occur.
"""
import logging
from fastapi import APIRouter, Query

from ..core.firebase_db import get_firestore

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/violations", tags=["Violations"])


@router.get("")
def list_violations(
    camera_id: str | None = Query(None),
    limit: int = Query(50, le=200),
):
    """List recent violations from Firestore."""
    db = get_firestore()
    query = db.collection("violations").order_by(
        "detected_at", direction="DESCENDING"
    ).limit(limit)

    if camera_id:
        query = query.where("camera_id", "==", camera_id)

    docs = query.stream()
    violations = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = doc.id
        # Convert Firestore timestamps to ISO strings
        if data.get("detected_at"):
            data["detected_at"] = data["detected_at"].isoformat() if hasattr(data["detected_at"], "isoformat") else str(data["detected_at"])
        violations.append(data)
    return violations


@router.get("/{violation_id}")
def get_violation(violation_id: str):
    """Get a single violation by ID."""
    db = get_firestore()
    doc = db.collection("violations").document(violation_id).get()
    if not doc.exists:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Violation not found")
    data = doc.to_dict()
    data["id"] = doc.id
    return data
