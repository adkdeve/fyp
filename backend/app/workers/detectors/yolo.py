"""
YoloDetector — activated when model.pt is placed on the server.

To enable:
  1. pip install ultralytics torch
  2. Place model.pt in backend/ (or set MODEL_PATH in .env)
  3. Set DETECTOR=yolo in .env
  4. Restart the server
"""
import logging
import os
from .base import BaseDetector, Detection
from ...models.violation import ViolationType, Severity

logger = logging.getLogger(__name__)

# ── Normalise class names ────────────────────────────────────────────────────
# Different PPE datasets use different conventions.  We normalise everything to
# lowercase with underscores so the map below works regardless of the model.

def _normalise(raw: str) -> str:
    return raw.strip().lower().replace("-", "_").replace(" ", "_")


# ── Violation class map (normalised key → ViolationType) ────────────────────
# Covers common naming conventions across public PPE datasets.

CLASS_MAP: dict[str, ViolationType] = {
    # No-helmet variants
    "no_helmet":            ViolationType.no_helmet,
    "no_hardhat":           ViolationType.no_helmet,
    "no_hard_hat":          ViolationType.no_helmet,
    "without_helmet":       ViolationType.no_helmet,
    "without_hardhat":      ViolationType.no_helmet,
    "no_safety_helmet":     ViolationType.no_helmet,
    "head":                 ViolationType.no_helmet,   # some models label bare head
    # No-vest variants
    "no_vest":              ViolationType.no_vest,
    "no_safety_vest":       ViolationType.no_vest,
    "no_reflective_vest":   ViolationType.no_vest,
    "without_vest":         ViolationType.no_vest,
    "no_jacket":            ViolationType.no_vest,
    # No-gloves variants
    "no_gloves":            ViolationType.no_gloves,
    "no_safety_gloves":     ViolationType.no_gloves,
    "without_gloves":       ViolationType.no_gloves,
    # No-boots variants
    "no_boots":             ViolationType.no_boots,
    "no_safety_boots":      ViolationType.no_boots,
    "without_boots":        ViolationType.no_boots,
    # No-mask variants
    "no_mask":              ViolationType.no_mask,
    "no_face_mask":         ViolationType.no_mask,
    "without_mask":         ViolationType.no_mask,
    # Zone / material
    "unauthorized_zone":    ViolationType.unauthorized_zone,
    "unsafe_material":      ViolationType.unsafe_material,
}

SEVERITY_MAP: dict[ViolationType, Severity] = {
    ViolationType.no_helmet:          Severity.high,
    ViolationType.no_vest:            Severity.medium,
    ViolationType.unauthorized_zone:  Severity.high,
    ViolationType.no_gloves:          Severity.medium,
    ViolationType.no_boots:           Severity.medium,
    ViolationType.no_mask:            Severity.low,
    ViolationType.unsafe_material:    Severity.medium,
}


class YoloDetector(BaseDetector):
    def __init__(self, model_path: str, confidence_threshold: float = 0.4):
        from ultralytics import YOLO  # lazy import — server starts without torch
        import torch
        
        # Optimize PyTorch for CPU inference
        torch.set_num_threads(os.cpu_count() or 4)
        
        self.model     = YOLO(model_path)
        self.threshold = confidence_threshold

        # Log every class name the model knows so we can debug mismatches
        names = list(self.model.names.values())
        logger.info(f"[YOLO] Model loaded from '{model_path}'")
        logger.info(f"[YOLO] Model classes ({len(names)}): {names}")

        # Warn about any class that won't map to a violation
        unmapped = [n for n in names if _normalise(n) not in CLASS_MAP]
        if unmapped:
            logger.warning(
                f"[YOLO] {len(unmapped)} class(es) have NO mapping and will be "
                f"ignored: {unmapped}"
            )

    def detect(self, frame, camera_id: str = "default") -> list[Detection]:
        results = self.model(frame, verbose=False)
        detections: list[Detection] = []

        person_boxes = []
        violation_boxes = []

        for result in results:
            for box in result.boxes:
                conf     = float(box.conf[0])
                raw_name = result.names[int(box.cls[0])]
                norm     = _normalise(raw_name)
                bbox     = [int(x) for x in box.xyxy[0].tolist()]

                # Always log every box above a low floor so we can see what the
                # model is actually detecting even if conf < threshold.
                if conf >= 0.25:
                    vtype = CLASS_MAP.get(norm)
                    logger.debug(
                        f"[YOLO cam={camera_id}] '{raw_name}' ({norm}) "
                        f"conf={conf:.0%}  mapped={vtype is not None}"
                    )

                if norm == "person":
                    if conf >= 0.25:
                        person_boxes.append(bbox)
                    continue

                if conf < self.threshold:
                    continue

                vtype = CLASS_MAP.get(norm)
                if vtype is None:
                    continue  # class we don't track (e.g. "helmet" = compliant)

                severity = SEVERITY_MAP.get(vtype, Severity.medium)
                violation_boxes.append({
                    "type": vtype,
                    "severity": severity,
                    "confidence": round(conf, 2),
                    "bbox": bbox
                })

        # Map violations to the enclosing person
        for p_box in person_boxes:
            person_violations = []
            for v_box in violation_boxes:
                # check if the center of the violation is inside the person box
                v_center_x = (v_box["bbox"][0] + v_box["bbox"][2]) / 2
                v_center_y = (v_box["bbox"][1] + v_box["bbox"][3]) / 2
                
                # Expand person box slightly to be forgiving
                px1, py1, px2, py2 = p_box
                margin_x = (px2 - px1) * 0.1
                margin_y = (py2 - py1) * 0.1
                
                if (px1 - margin_x) <= v_center_x <= (px2 + margin_x) and \
                   (py1 - margin_y) <= v_center_y <= (py2 + margin_y):
                    person_violations.append(v_box)
            
            if person_violations:
                # Group multiple PPE violations for this person
                labels = []
                max_conf = 0.0
                highest_severity = Severity.low
                
                severity_scores = {Severity.low: 1, Severity.medium: 2, Severity.high: 3}
                
                for v in person_violations:
                    vconf = int(float(v["confidence"]) * 100)
                    labels.append(f"{v['type'].value.replace('_', ' ').title()} {vconf}%")
                    max_conf = max(max_conf, v["confidence"])
                    if severity_scores[v["severity"]] > severity_scores[highest_severity]:
                        highest_severity = v["severity"]
                        
                # Provide a fallback type (use the highest severity violation type or just the first one)
                primary_type = person_violations[0]["type"]
                for v in person_violations:
                    if severity_scores[v["severity"]] == severity_scores[highest_severity]:
                        primary_type = v["type"]
                        break
                        
                composite_label = ", ".join(labels)
                
                detections.append(Detection(
                    type=primary_type,
                    severity=highest_severity,
                    confidence=max_conf,
                    bbox=p_box,  # Use the person's bbox so we draw/track the person
                    composite_label=composite_label
                ))

        # Fallback: if the model never detects "person" objects, just return the raw violations
        if not person_boxes and violation_boxes:
            for v_box in violation_boxes:
                detections.append(Detection(
                    type=v_box["type"],
                    severity=v_box["severity"],
                    confidence=v_box["confidence"],
                    bbox=v_box["bbox"]
                ))

        return detections
