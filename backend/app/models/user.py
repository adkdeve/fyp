import enum
from datetime import datetime
from sqlalchemy import String, DateTime, Enum, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..core.db import Base


class UserRole(str, enum.Enum):
    admin = "admin"
    supervisor = "supervisor"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.supervisor, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    company: Mapped[str | None] = mapped_column(String(160), nullable=True)
    location: Mapped[str | None] = mapped_column(String(250), nullable=True)
    notify_critical_alerts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notify_medium_alerts: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
