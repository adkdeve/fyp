import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from ..ws.manager import connection_manager

router = APIRouter(tags=["WebSocket"])
logger = logging.getLogger(__name__)


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """
    Connect with: ws://localhost:8000/ws
    Receives JSON messages whenever a new violation is detected.
    """
    await connection_manager.connect("global", websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        connection_manager.disconnect("global", websocket)
