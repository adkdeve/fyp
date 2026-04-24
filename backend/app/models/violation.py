import enum
from datetime import datetime
from sqlalchemy import String, DateTime, Enum, ForeignKey, Float, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from ..core.db import Base


class ViolationType(str, enum.Enum):
    no_helmet = "no_helmet"
    no_vest = "no_vest"
    no_gloves = "no_gloves"
    no_boots = "no_boots"
    no_mask = "no_mask"
    unauthorized_zone = "unauthorized_zone"
    unsafe_material = "unsafe_material"
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


class Violation(Base):
    __tablename__ = "violations"

    id: Mapped[int] = mapped_column(primary_key=True)
    camera_id: Mapped[int] = mapped_column(ForeignKey("cameras.id", ondelete="CASCADE"), nullable=False, index=True)
    type: Mapped[ViolationType] = mapped_column(Enum(ViolationType), nullable=False, index=True)
    severity: Mapped[Severity] = mapped_column(Enum(Severity), default=Severity.medium, nullable=False, index=True)
    status: Mapped[ViolationStatus] = mapped_column(Enum(ViolationStatus), default=ViolationStatus.open, nullable=False, index=True)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    snapshot_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    bbox_json: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON string of detection bboxes
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    detected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    resolved_by_id: Mapped[int | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    camera = relationship("Camera", lazy="joined")
    resolved_by = relationship("User", lazy="joined")
