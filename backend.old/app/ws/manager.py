import json
import logging
from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Keeps track of all active WebSocket connections and broadcasts alerts."""

    def __init__(self):
        # user_id -> list of open WebSocket connections
        self._connections: dict[int, list[WebSocket]] = {}

    async def connect(self, user_id: int, ws: WebSocket):
        await ws.accept()
        self._connections.setdefault(user_id, []).append(ws)
        logger.info(f"WS connected: user {user_id} ({self._total()} total)")

    def disconnect(self, user_id: int, ws: WebSocket):
        conns = self._connections.get(user_id, [])
        if ws in conns:
            conns.remove(ws)
        if not conns:
            self._connections.pop(user_id, None)
        logger.info(f"WS disconnected: user {user_id} ({self._total()} total)")

    async def broadcast(self, payload: dict):
        """Send payload to every connected supervisor."""
        message = json.dumps(payload)
        dead = []
        for user_id, conns in self._connections.items():
            for ws in conns:
                try:
                    await ws.send_text(message)
                except Exception:
                    dead.append((user_id, ws))
        for user_id, ws in dead:
            self.disconnect(user_id, ws)

    async def send_to_user(self, user_id: int, payload: dict):
        """Send payload only to a specific user's connections."""
        message = json.dumps(payload)
        for ws in list(self._connections.get(user_id, [])):
            try:
                await ws.send_text(message)
            except Exception:
                self.disconnect(user_id, ws)

    def _total(self):
        return sum(len(v) for v in self._connections.values())


connection_manager = ConnectionManager()
