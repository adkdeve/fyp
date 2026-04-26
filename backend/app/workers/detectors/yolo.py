"""
YoloDetector — activated when model.pt is placed on the server.

To enable:
  1. pip install ultralytics torch
  2. Place model.pt in backend/ (or set MODEL_PATH in .env)
  3. Set DETECTOR=yolo in .env
  4. Restart the server
"""
import logging
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
    ViolationType.no_vest:            Severity.high,
    ViolationType.unauthorized_zone:  Severity.high,
    ViolationType.no_gloves:          Severity.medium,
    ViolationType.no_boots:           Severity.medium,
    ViolationType.no_mask:            Severity.medium,
    ViolationType.unsafe_material:    Severity.medium,
}


class YoloDetector(BaseDetector):
    def __init__(self, model_path: str, confidence_threshold: float = 0.4):
        from ultralytics import YOLO  # lazy import — server starts without torch
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

        for result in results:
            for box in result.boxes:
                conf     = float(box.conf[0])
                raw_name = result.names[int(box.cls[0])]
                norm     = _normalise(raw_name)

                # Always log every box above a low floor so we can see what the
                # model is actually detecting even if conf < threshold.
                if conf >= 0.25:
                    vtype = CLASS_MAP.get(norm)
                    logger.debug(
                        f"[YOLO cam={camera_id}] '{raw_name}' ({norm}) "
                        f"conf={conf:.0%}  mapped={vtype is not None}"
                    )

                if conf < self.threshold:
                    continue

                vtype = CLASS_MAP.get(norm)
                if vtype is None:
                    continue  # class we don't track (e.g. "helmet" = compliant)

                severity = SEVERITY_MAP.get(vtype, Severity.medium)
                bbox     = [int(x) for x in box.xyxy[0].tolist()]
                detections.append(Detection(
                    type=vtype,
                    severity=severity,
                    confidence=round(conf, 2),
                    bbox=bbox,
                ))

        return detections
