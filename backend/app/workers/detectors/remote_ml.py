"""
RemoteMLDetector — sends frames + safe zone polygon + enabled_models to the ML service.
No model weights live in the backend.

enabled_models is passed with every request so the backend controls which models run,
independent of the ML service's in-memory state (which resets on every restart).
"""
import base64
import logging
from urllib.parse import urlparse, urlunparse

import cv2
import httpx

from .base import BaseDetector, Detection
from ...models import ViolationType, Severity

logger = logging.getLogger(__name__)

_VIOLATION_MAP: dict[str, ViolationType] = {
    "no_helmet":                  ViolationType.no_helmet,
    "no_vest":                    ViolationType.no_vest,
    "no_gloves":                  ViolationType.no_gloves,
    "no_boots":                   ViolationType.no_boots,
    "no_mask":                    ViolationType.no_mask,
    "unauthorized_zone":          ViolationType.unauthorized_zone,
    "unsafe_material":            ViolationType.unsafe_material,
    "fire":                       ViolationType.fire_detected,
    "fire_detected":              ViolationType.fire_detected,
    "smoke":                      ViolationType.smoke_detected,
    "smoke_detected":             ViolationType.smoke_detected,
    "unknown_face":               ViolationType.unknown_face,
    "restricted_area_entrance":   ViolationType.restricted_area_entrance,
    "person":                     ViolationType.person,
    "other":                      ViolationType.other,
}

_SEVERITY_MAP: dict[str, Severity] = {
    "high":   Severity.high,
    "medium": Severity.medium,
    "low":    Severity.low,
}

# display_only types — drawn on stream but NEVER written to Firebase
_DISPLAY_ONLY = {ViolationType.person}


class RemoteMLDetector(BaseDetector):
    """
    Sends JPEG-encoded frames + safe zone polygon + enabled_models to /detect.
    Thread-safe: synchronous HTTP POST called from the inference thread.
    """

    def __init__(self, ml_url: str, timeout: float = 4.0):
        self._primary_detect_url = ml_url.rstrip("/") + "/detect"
        self._fallback_detect_url = self._build_fallback_url(ml_url)
        self.detect_url = self._primary_detect_url
        self._client = httpx.Client(timeout=timeout)
        self._enabled_models: dict[str, bool] = {
            "helmet":      False,
            "firesmoke":   False,
        }
        logger.info(f"[RemoteML] Detector configured → {self.detect_url}")

    def _build_fallback_url(self, ml_url: str) -> str | None:
        parsed = urlparse(ml_url.rstrip("/"))
        if parsed.hostname in ("localhost", "127.0.0.1") and parsed.port in (8000, 8001):
            alt_port = 8001 if parsed.port == 8000 else 8000
            fallback_netloc = f"{parsed.hostname}:{alt_port}"
            fallback = urlunparse(parsed._replace(netloc=fallback_netloc, path=""))
            return fallback.rstrip("/") + "/detect"
        return None

    def set_enabled_models(self, models: dict[str, bool]) -> None:
        """Update which models the ML service should run. Thread-safe (GIL-protected dict swap)."""
        self._enabled_models = dict(models)
        logger.info(f"[RemoteML] enabled_models updated: {self._enabled_models}")

    def detect(
        self,
        frame,
        camera_id: str = "default",
        safe_zone_polygon: list | None = None,
    ) -> list[Detection]:
        try:
            _, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 75])
            jpg_b64 = base64.b64encode(buf.tobytes()).decode("ascii")

            body = {
                "frame_b64":         jpg_b64,
                "camera_id":         camera_id,
                "safe_zone_polygon": safe_zone_polygon or [],
                "enabled_models":    self._enabled_models,
            }

            urls_to_try = [self.detect_url]
            if self._fallback_detect_url and self._fallback_detect_url != self.detect_url:
                urls_to_try.append(self._fallback_detect_url)

            for url in urls_to_try:
                try:
                    resp = self._client.post(url, json=body)
                    resp.raise_for_status()
                    if url != self.detect_url:
                        self.detect_url = url
                        logger.info(f"[RemoteML] switched ML endpoint to {url}")

                    data = resp.json()
                    detections: list[Detection] = []
                    for item in data.get("detections", []):
                        type_str = item.get("type", "other")
                        vtype = _VIOLATION_MAP.get(type_str, ViolationType.other)
                        severity = _SEVERITY_MAP.get(item.get("severity", "medium"), Severity.medium)
                        bbox = item.get("bbox", [])
                        conf = float(item.get("confidence", 0.0))
                        display_only = item.get("display_only", False) or (vtype in _DISPLAY_ONLY)
                        composite_label = item.get("composite_label")
                        detections.append(Detection(
                            type=vtype,
                            severity=severity,
                            confidence=conf,
                            bbox=bbox,
                            display_only=display_only,
                            composite_label=composite_label,
                        ))
                    return detections
                except httpx.HTTPStatusError as e:
                    status = e.response.status_code
                    if status in (404, 405) and url == urls_to_try[0] and len(urls_to_try) > 1:
                        logger.warning(f"[RemoteML] primary ML URL {url} returned {status}; trying fallback...")
                        continue
                    logger.warning(f"[RemoteML] Unexpected error: {e}")
                    return []
                except (httpx.ConnectError, httpx.TimeoutException) as e:
                    if url == urls_to_try[-1]:
                        logger.debug(f"[RemoteML] ML service unreachable at {url}: {e}")
                        return []
                    logger.warning(f"[RemoteML] primary ML URL {url} failed: {e}; trying fallback...")
                    continue
            return []
        except httpx.ConnectError:
            logger.debug("[RemoteML] ML service unreachable")
            return []
        except httpx.TimeoutException:
            logger.debug("[RemoteML] ML service timed out")
            return []
        except Exception as e:
            logger.warning(f"[RemoteML] Unexpected error: {e}")
            return []

    def __del__(self):
        try:
            self._client.close()
        except Exception:
            pass
