import json
import logging
from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """Keeps track of all active WebSocket connections and broadcasts alerts."""

    def __init__(self):
        self._connections: dict[str, list[WebSocket]] = {}

    async def connect(self, channel: str, ws: WebSocket):
        await ws.accept()
        self._connections.setdefault(channel, []).append(ws)
        logger.info(f"WS connected: {channel} ({self._total()} total)")

    def disconnect(self, channel: str, ws: WebSocket):
        conns = self._connections.get(channel, [])
        if ws in conns:
            conns.remove(ws)
        if not conns:
            self._connections.pop(channel, None)
        logger.info(f"WS disconnected: {channel} ({self._total()} total)")

    async def broadcast(self, payload: dict):
        """Send payload to every connected client."""
        message = json.dumps(payload)
        dead = []
        for channel, conns in self._connections.items():
            for ws in conns:
                try:
                    await ws.send_text(message)
                except Exception:
                    dead.append((channel, ws))
        for channel, ws in dead:
            self.disconnect(channel, ws)

    def _total(self):
        return sum(len(v) for v in self._connections.values())


connection_manager = ConnectionManager()
