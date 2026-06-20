"""
Safe Zone API — stores normalized polygon per camera in Firestore,
hot-updates the running camera worker, and enables the ML service.

Polygon points are stored as NORMALIZED coords [[nx, ny], …] where
nx, ny ∈ [0, 1] (fraction of frame width/height). This makes the polygon
resolution-agnostic — correct regardless of stream resolution.
"""
import logging
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ..core.config import settings
from ..core.firebase_db import get_firestore

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/safe-zone", tags=["Safe Zone"])


class PolygonPoint(BaseModel):
    # Normalized coords (0–1) — fraction of frame width/height
    x: float
    y: float


class SetPolygonRequest(BaseModel):
    camera_id: str
    points: list[PolygonPoint]


@router.post("/set")
def set_safe_zone(body: SetPolygonRequest):
    """
    Save a safe zone polygon for a camera (normalized coords).
    1. Persists to Firestore
    2. Hot-updates the running camera worker (no restart needed)
    3. Enables safe zone on ML service (best-effort)
    """
    if len(body.points) < 3:
        raise HTTPException(status_code=400, detail="Need at least 3 points")

    points_norm = [[p.x, p.y] for p in body.points]
    print(f"DEBUG: Setting safe zone for camera_id='{body.camera_id}' with {len(points_norm)} points")
    logger.info(f"[SafeZone] set for camera={body.camera_id} pts={len(points_norm)}: {points_norm[:2]}...")

    # ── 1. Persist to Firestore ────────────────────────────────────────────────
    try:
        db = get_firestore()
        # Firestore doesn't support nested arrays, so we must store a list of dicts.
        # Use set(merge=True) instead of update() so the call succeeds even if the
        # camera document doesn't exist yet (update() throws NotFound on missing docs).
        points_dict_list = [{"x": p[0], "y": p[1]} for p in points_norm]
        db.collection("cameras").document(body.camera_id).set({
            "safe_zone_polygon": points_dict_list,
        }, merge=True)
        logger.info(f"[SafeZone] Saved {len(points_norm)} pts to Firestore for cam {body.camera_id}")
    except Exception as e:
        logger.error(f"[SafeZone] Firestore update error: {e}")
        raise HTTPException(status_code=500, detail=f"Firestore error: {e}")

    # ── 2. Hot-update the running camera worker ────────────────────────────────
    try:
        from ..workers.manager import worker_manager
        workers = worker_manager.get_workers()
        logger.info(f"[SafeZone] Running workers: {list(workers.keys())}")
        worker_manager.update_safe_zone(body.camera_id, points_norm)
    except Exception as e:
        logger.warning(f"[SafeZone] Worker update error: {e}")

    # ── 3. Enable safe zone on ML service (best-effort, non-fatal) ────────────
    try:
        with httpx.Client(timeout=5.0) as client:
            # 1. Toggle it on
            client.post(f"{settings.ml_api_url}/models/safe-zone/toggle", json={"active": True})
            # 2. Sync the actual points (normalized)
            client.post(f"{settings.ml_api_url}/models/safe-zone/set-polygon", json={"points": points_norm})
            logger.info(f"[SafeZone] Synced polygon to ML service for cam {body.camera_id}")
    except Exception as e:
        logger.warning(f"[SafeZone] ML service sync error (non-fatal): {e}")

    return {
        "status": "ok",
        "camera_id": body.camera_id,
        "points_count": len(points_norm),
    }


@router.get("/debug/{camera_id}")
def debug_safe_zone(camera_id: str):
    """Debug endpoint — returns Firestore polygon + worker state for a camera."""
    try:
        from ..workers.manager import worker_manager

        # Firestore state
        db  = get_firestore()
        doc = db.collection("cameras").document(camera_id).get()
        fs_polygon = (doc.to_dict() or {}).get("safe_zone_polygon", []) if doc.exists else []

        # Worker state
        workers = worker_manager.get_workers()
        worker_polygon = []
        if camera_id in workers:
            worker_polygon = workers[camera_id]._get_polygon()

        return {
            "camera_id":          camera_id,
            "firestore_polygon":  fs_polygon,
            "firestore_pts":      len(fs_polygon),
            "worker_running":     camera_id in workers,
            "worker_polygon":     worker_polygon,
            "worker_pts":         len(worker_polygon),
            "all_workers":        list(workers.keys()),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/clear/{camera_id}")
def clear_safe_zone(camera_id: str):
    """Remove the safe zone polygon for a camera."""
    try:
        get_firestore().collection("cameras").document(camera_id).set({
            "safe_zone_polygon": [],
        }, merge=True)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Firestore error: {e}")

    # Hot-update worker
    try:
        from ..workers.manager import worker_manager
        worker_manager.update_safe_zone(camera_id, [])
    except Exception:
        pass

    # Disable safe zone on ML service
    try:
        with httpx.Client(timeout=5.0) as client:
            client.post(
                f"{settings.ml_api_url}/models/safe-zone/toggle",
                json={"active": False},
            )
            client.post(
                f"{settings.ml_api_url}/models/safe-zone/set-polygon",
                json={"points": []},
            )
    except Exception:
        pass

    return {"status": "cleared", "camera_id": camera_id}


@router.get("/{camera_id}")
def get_safe_zone(camera_id: str):
    """Return the current safe zone polygon (normalized coords) for a camera."""
    try:
        db  = get_firestore()
        doc = db.collection("cameras").document(camera_id).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Camera not found")
        data = doc.to_dict() or {}
        return {
            "camera_id": camera_id,
            "points":    data.get("safe_zone_polygon", []),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
