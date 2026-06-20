"""
Pure Python enums and types for the safety detection system.
No SQLAlchemy — all persistence goes through Firebase Firestore.
"""
import enum


class UserRole(str, enum.Enum):
    admin = "admin"
    supervisor = "supervisor"


class CameraStatus(str, enum.Enum):
    online = "online"
    offline = "offline"
    error = "error"


class ViolationType(str, enum.Enum):
    no_helmet = "no_helmet"
    no_vest = "no_vest"
    no_gloves = "no_gloves"
    no_boots = "no_boots"
    no_mask = "no_mask"
    unauthorized_zone = "unauthorized_zone"
    unsafe_material = "unsafe_material"
    # Fire / smoke
    fire_detected = "fire_detected"
    smoke_detected = "smoke_detected"
    # Face recognition
    unknown_face = "unknown_face"
    # Restricted area / safe zone
    restricted_area_entrance = "restricted_area_entrance"
    # Person (display-only — drawn on stream but NOT recorded as violation)
    person = "person"
    other = "other"



class Severity(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class ViolationStatus(str, enum.Enum):
    open = "open"
    acknowledged = "acknowledged"
    resolved = "resolved"
    false_positive = "false_positive"


class AlertChannel(str, enum.Enum):
    websocket = "websocket"
    push = "push"
    email = "email"
