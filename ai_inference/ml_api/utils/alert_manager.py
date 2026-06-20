"""
Alert Manager - Generates and manages real-time alerts
"""
from typing import List, Dict, Optional, Callable
from datetime import datetime
from collections import deque


class Alert:
    """Represents a single alert"""
    
    def __init__(self, alert_type: str, message: str, severity: str = "warning"):
        self.alert_type = alert_type
        self.message = message
        self.severity = severity  # info, warning, error
        self.timestamp = datetime.now()
    
    def __str__(self):
        emoji_map = {
            "fire": "",
            "unsafe_zone": "",
            "unknown_person": "",
            "distress": "",
            "camera_offline": ""
        }
        emoji = emoji_map.get(self.alert_type, "")
        time_str = self.timestamp.strftime("%H:%M:%S")
        return f"{emoji} [{time_str}] {self.message}"


class AlertManager:
    """Manages real-time alerts for the video processing system"""
    
    def __init__(self, max_alerts: int = 50):
        """
        Initialize alert manager
        
        Args:
            max_alerts: Maximum number of alerts to keep in history
        """
        self.max_alerts = max_alerts
        self.alerts = deque(maxlen=max_alerts)
        self.alert_counts = {
            "fire": 0,
            "unsafe_zone": 0,
            "unknown_person": 0,
            "distress": 0,
            "camera_offline": 0
        }
        self._listeners: List[Callable[[Alert], None]] = []

    def subscribe(self, callback: Callable[[Alert], None]):
        """Subscribe to newly created alerts."""
        self._listeners.append(callback)

    def _emit(self, alert: Alert):
        for callback in self._listeners:
            try:
                callback(alert)
            except Exception:
                # Listeners should not break processing pipeline.
                pass
    
    def add_fire_alert(self, details: str = ""):
        """Add fire/smoke detection alert"""
        msg = f"Fire/Smoke detected"
        if details:
            msg += f": {details}"
        alert = Alert("fire", msg, "error")
        self.alerts.append(alert)
        self.alert_counts["fire"] += 1
        self._emit(alert)
        return alert
    
    def add_unsafe_zone_alert(self, person_name: str = "Person", action: str = "left the safe zone"):
        """Add unsafe zone alert"""
        msg = f"{person_name} {action}"
        alert = Alert("unsafe_zone", msg, "warning")
        self.alerts.append(alert)
        self.alert_counts["unsafe_zone"] += 1
        self._emit(alert)
        return alert
    
    def add_unknown_person_alert(self, details: str = ""):
        """Add unknown person detection alert"""
        msg = "Unknown person detected"
        if details:
            msg += f": {details}"
        alert = Alert("unknown_person", msg, "warning")
        self.alerts.append(alert)
        self.alert_counts["unknown_person"] += 1
        self._emit(alert)
        return alert
    
    def add_distress_alert(self, person_name: str = "Person", emotion: str = ""):
        """Add distress/emotion alert"""
        msg = f"{person_name} showing distress"
        if emotion:
            msg += f" (emotion: {emotion})"
        alert = Alert("distress", msg, "warning")
        self.alerts.append(alert)
        self.alert_counts["distress"] += 1
        self._emit(alert)
        return alert
    
    def add_camera_offline_alert(self, camera_id: str = ""):
        """Add camera offline alert"""
        msg = "Camera offline"
        if camera_id:
            msg += f": {camera_id}"
        alert = Alert("camera_offline", msg, "error")
        self.alerts.append(alert)
        self.alert_counts["camera_offline"] += 1
        self._emit(alert)
        return alert
    
    def get_recent_alerts(self, limit: int = 10) -> List[Alert]:
        """Get most recent alerts"""
        return list(self.alerts)[-limit:]
    
    def get_all_alerts(self) -> List[Alert]:
        """Get all alerts in history"""
        return list(self.alerts)
    
    def get_alert_count(self, alert_type: Optional[str] = None) -> int:
        """Get count of alerts by type or total"""
        if alert_type:
            return self.alert_counts.get(alert_type, 0)
        return sum(self.alert_counts.values())
    
    def clear_alerts(self):
        """Clear all alerts"""
        self.alerts.clear()
        for key in self.alert_counts:
            self.alert_counts[key] = 0
    
    def get_stats(self) -> Dict:
        """Get alert statistics"""
        return {
            "total_alerts": sum(self.alert_counts.values()),
            "by_type": dict(self.alert_counts),
            "recent_count": len(self.alerts)
        }
