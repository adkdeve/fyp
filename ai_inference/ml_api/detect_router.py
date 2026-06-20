"""
/detect — unified inference endpoint.

The backend camera worker POSTs:
  - base64 JPEG frame
  - safe_zone_polygon: list of [[nx, ny], ...] NORMALIZED coords (0–1 range)
  - enabled_models: dict of which models to run THIS frame (e.g. {"face_insight": true, "helmet": true})
    If enabled_models is not provided, falls back to app.state.active_models (legacy behaviour
    when toggled via the ml_frontend UI).

Returns detections:
  - PPE violations (no_helmet, no_vest)
  - fire_detected / smoke_detected
  - unknown_face
  - person  → person inside zone  (display_only, green box — never recorded as violation)
  - restricted_area_entrance → person outside zone (violation, red box)
"""
import base64
import logging

import cv2
import numpy as np
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter()

_SEVERITY: dict[str, str] = {
    "no_helmet":                "high",
    "no_vest":                  "medium",
    "fire_detected":            "high",
    "smoke_detected":           "high",
    "unknown_face":             "high",
    "unauthorized_zone":        "high",
    "unsafe_material":          "medium",
    "restricted_area_entrance": "high",
    "person":                   "low",
    "other":                    "low",
}


class DetectRequest(BaseModel):
    frame_b64: str
    camera_id: str = "default"
    # Normalized polygon coords [[nx, ny], ...] where nx,ny ∈ [0,1]
    safe_zone_polygon: list[list[float]] = []
    # Which models to activate for this request.
    # Overrides app.state.active_models when provided.
    # Keys: "helmet", "firesmoke", "face_insight"
    enabled_models: dict[str, bool] = {}


class DetectionItem(BaseModel):
    type: str
    severity: str
    confidence: float
    bbox: list[int]
    display_only: bool = False   # person inside zone — draw but don't record
    composite_label: str | None = None


class DetectResponse(BaseModel):
    camera_id: str
    detections: list[DetectionItem]


# ── Lazy model cache ─────────────────────────────────────────────────────────
_model_cache: dict[str, object] = {}


def _get_or_load(key: str, loader_fn):
    if key not in _model_cache:
        _model_cache[key] = loader_fn()
    return _model_cache[key]


# ── Point-in-polygon (ray-casting, no shapely needed) ────────────────────────
def _point_in_polygon(px: float, py: float, polygon: list) -> bool:
    n = len(polygon)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
        j = i
    return inside


@router.post("/detect", response_model=DetectResponse)
def detect(req: Request, payload: DetectRequest):
    """Unified inference endpoint — called once per camera frame by the backend."""

    # ── Decode frame ─────────────────────────────────────────────────────────
    try:
        arr   = np.frombuffer(base64.b64decode(payload.frame_b64), np.uint8)
        frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if frame is None:
            raise ValueError("imdecode returned None")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid frame: {e}")

    fh, fw = frame.shape[:2]

    # Merge active_models from app state (toggled via UI) with per-request overrides.
    # Per-request enabled_models takes priority — this allows the camera worker to
    # pass model flags independently of the ML service's in-memory state.
    global_active = dict(req.app.state.active_models)
    if payload.enabled_models:
        global_active.update(payload.enabled_models)
    active = global_active

    all_detections: list[DetectionItem] = []

    # ── Shared Person Detection ───────────────────────────────────────────────
    # We need person boxes for both PPE grouping and Safe Zone detection
    poly_normalized = payload.safe_zone_polygon
    if not poly_normalized:
        poly_normalized = getattr(req.app.state, "safe_zone_polygon", [])
        
    person_boxes = []
    if len(poly_normalized) >= 3 or active.get("helmet"):
        try:
            from models_logic.safe_zone import load_yolo_model
            person_model = _get_or_load("_person_model", load_yolo_model)
            if person_model is not None:
                scale = min(1.0, 640 / max(fw, fh))
                small = cv2.resize(frame, (int(fw * scale), int(fh * scale)))
                results = person_model(small, verbose=False, conf=0.40)
                for r in results:
                    for box in r.boxes:
                        cls = int(box.cls[0])
                        if person_model.names.get(cls, "") != "person":
                            continue
                        conf = float(box.conf[0])
                        x1, y1, x2, y2 = [v / scale for v in box.xyxy[0].tolist()]
                        person_boxes.append({
                            "bbox": [int(x1), int(y1), int(x2), int(y2)],
                            "conf": conf
                        })
        except Exception as e:
            logger.warning(f"[detect] Person model error: {e}")

    # ── 1. PPE / Helmet  (min 70% confidence) ─────────────────────────────────
    PPE_MIN_CONF = 0.70
    if active.get("helmet"):
        try:
            from models_logic.helmet_detector import detect_helmet_violations
            raw_ppe = detect_helmet_violations(frame)
            
            # Map raw PPE violations to the enclosing person boxes
            for p_dict in person_boxes:
                p_box = p_dict["bbox"]
                px1, py1, px2, py2 = p_box
                
                person_violations = []
                for det in raw_ppe:
                    conf = float(det.get("confidence", 0))
                    if conf < PPE_MIN_CONF:
                        continue
                    
                    v_box = det.get("bbox", [])
                    if not v_box: continue
                    
                    v_center_x = (v_box[0] + v_box[2]) / 2
                    v_center_y = (v_box[1] + v_box[3]) / 2
                    
                    # Expand person box slightly to be forgiving
                    margin_x = (px2 - px1) * 0.1
                    margin_y = (py2 - py1) * 0.1
                    
                    if (px1 - margin_x) <= v_center_x <= (px2 + margin_x) and \
                       (py1 - margin_y) <= v_center_y <= (py2 + margin_y):
                        person_violations.append(det)
                        
                if person_violations:
                    labels = []
                    max_conf = 0.0
                    highest_severity = "low"
                    severity_scores = {"low": 1, "medium": 2, "high": 3}
                    
                    for v in person_violations:
                        vtype = v.get("type", "other")
                        severity = _SEVERITY.get(vtype, "medium")
                        vconf = int(float(v.get("confidence", 0)) * 100)
                        labels.append(f"{vtype.replace('_', ' ').title()} {vconf}%")
                        max_conf = max(max_conf, float(v.get("confidence", 0)))
                        if severity_scores.get(severity, 1) > severity_scores.get(highest_severity, 1):
                            highest_severity = severity
                            
                    # Provide fallback primary type
                    primary_type = person_violations[0].get("type", "other")
                    for v in person_violations:
                        v_sev = _SEVERITY.get(v.get("type", "other"), "medium")
                        if severity_scores.get(v_sev, 1) == severity_scores.get(highest_severity, 1):
                            primary_type = v.get("type", "other")
                            break
                            
                    composite_label = ", ".join(labels)
                    
                    all_detections.append(DetectionItem(
                        type=primary_type,
                        severity=highest_severity,
                        confidence=round(max_conf, 3),
                        bbox=p_box,  # Use person's bbox so we draw/track the person
                        composite_label=composite_label
                    ))
                    
        except Exception as e:
            logger.warning(f"[detect] Helmet error: {e}")

    # ── 2. Fire & Smoke ────────────────────────────────────────────────────────
    if active.get("firesmoke"):
        try:
            from models_logic.fire_smoke_detector import load_fire_smoke_model
            fire_model = _get_or_load("_fire_model", load_fire_smoke_model)
            if fire_model is not None:
                for r in fire_model(frame, verbose=False):
                    for box in r.boxes:
                        conf = float(box.conf[0])
                        if conf < 0.80:   # fire/smoke: require ≥80% confidence
                            continue
                        raw = r.names[int(box.cls[0])].lower()
                        vtype = "fire_detected" if "fire" in raw else "smoke_detected"
                        all_detections.append(DetectionItem(
                            type=vtype,
                            severity="high",
                            confidence=round(conf, 3),
                            bbox=[int(x) for x in box.xyxy[0].tolist()],
                        ))
        except Exception as e:
            logger.warning(f"[detect] Fire/smoke error: {e}")

    # ── 3. Face Recognition ────────────────────────────────────────────────────
    if active.get("face_insight"):
        try:
            from models_logic.insightface_recognition import recognize_faces
            for face in recognize_faces(frame):
                is_auth = face.get("is_authorized", False)
                conf    = float(face.get("confidence", 0.0))
                bbox    = [int(x) for x in face.get("bbox", [])]

                if is_auth:
                    # Authorized person — green display-only box, no violation
                    all_detections.append(DetectionItem(
                        type="person",
                        severity="low",
                        confidence=round(conf, 3),
                        bbox=bbox,
                        display_only=True,
                    ))
                else:
                    # Unknown/unauthorized → high-severity violation
                    all_detections.append(DetectionItem(
                        type="unknown_face",
                        severity="high",
                        confidence=0.9,
                        bbox=bbox,
                        display_only=False,
                    ))
        except Exception as e:
            logger.warning(f"[detect] InsightFace error: {e}")

    # ── 4. Safe Zone — person detection + zone checking ───────────────────────
    if len(poly_normalized) >= 3:
        try:
            max_coord = max(max(abs(p[0]), abs(p[1])) for p in poly_normalized)
            if max_coord <= 1.0:
                poly_px = [[p[0] * fw, p[1] * fh] for p in poly_normalized]
            else:
                poly_px = [[float(p[0]), float(p[1])] for p in poly_normalized]

            for p_dict in person_boxes:
                x1, y1, x2, y2 = p_dict["bbox"]
                conf = p_dict["conf"]

                # Check if bounding box hits the safe zone boundary or is inside it
                pts_to_check = [
                    (x1, y1), (x2, y1), (x2, y2), (x1, y2),
                    ((x1+x2)/2.0, (y1+y2)/2.0), ((x1+x2)/2.0, y2)
                ]
                
                hits_zone = any(_point_in_polygon(px, py, poly_px) for px, py in pts_to_check)
                
                if not hits_zone:
                    hits_zone = any(x1 <= p[0] <= x2 and y1 <= p[1] <= y2 for p in poly_px)

                if hits_zone:
                    all_detections.append(DetectionItem(
                        type="restricted_area_entrance",
                        severity="high",
                        confidence=round(conf, 3),
                        bbox=[x1, y1, x2, y2],
                        display_only=False,
                    ))
                else:
                    # Only add "person" (Safe) display box if we didn't already add a PPE violation
                    # to prevent rendering text overlapping issues. (Camera worker handles display).
                    has_ppe = any(d.bbox == [x1,y1,x2,y2] and not d.display_only for d in all_detections)
                    if not has_ppe:
                        all_detections.append(DetectionItem(
                            type="person",
                            severity="low",
                            confidence=round(conf, 3),
                            bbox=[x1, y1, x2, y2],
                            display_only=True,
                        ))
        except Exception as e:
            logger.warning(f"[detect] SafeZone error: {e}")

    return DetectResponse(camera_id=payload.camera_id, detections=all_detections)


@router.post("/api/v1/detect", response_model=DetectResponse)
def detect_v1(req: Request, payload: DetectRequest):
    """Compatibility alias for clients using /api/v1/detect."""
    return detect(req, payload)
