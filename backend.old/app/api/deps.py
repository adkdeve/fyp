from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import false
from sqlalchemy.orm import Session
from jose import JWTError

from ..core.db import get_db
from ..core.security import decode_token
from ..models.camera import Camera
from ..models.user import User, UserRole

bearer_scheme = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    token = credentials.credentials
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise ValueError("Wrong token type")
        user_id: int = int(payload["sub"])
    except (JWTError, ValueError, KeyError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user = db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user


def require_supervisor(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role not in (UserRole.admin, UserRole.supervisor):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Supervisor access required")
    return current_user


def is_admin(user: User) -> bool:
    return user.role == UserRole.admin


def is_supervisor(user: User) -> bool:
    return user.role == UserRole.supervisor


def scope_site_query(query, current_user: User, site_field):
    if is_admin(current_user):
        return query
    if current_user.site_id is None:
        return query.filter(false())
    return query.filter(site_field == current_user.site_id)


def scope_camera_query(query, current_user: User):
    return scope_site_query(query, current_user, Camera.site_id)


def can_access_camera(current_user: User, camera: Camera | None) -> bool:
    if camera is None:
        return False
    if is_admin(current_user):
        return True
    return current_user.site_id is not None and camera.site_id == current_user.site_id
