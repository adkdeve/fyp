import logging
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from jose import JWTError

from ..core.security import decode_token
from ..core.db import SessionLocal
from ..models.user import User
from ..ws.manager import connection_manager

router = APIRouter(tags=["WebSocket"])
logger = logging.getLogger(__name__)


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
):
    """
    Connect with:  ws://localhost:8000/ws?token=<access_token>
    Receives JSON messages whenever a new violation is detected.
    """
    # Validate token before accepting
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            await websocket.close(code=4001)
            return
        user_id = int(payload["sub"])
    except (JWTError, Exception):
        await websocket.close(code=4001)
        return

    # Verify user exists
    db = SessionLocal()
    try:
        user = db.get(User, user_id)
        if not user or not user.is_active:
            await websocket.close(code=4001)
            return
    finally:
        db.close()

    await connection_manager.connect(user_id, websocket)
    try:
        while True:
            # Keep connection alive; client can send ping
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        connection_manager.disconnect(user_id, websocket)
