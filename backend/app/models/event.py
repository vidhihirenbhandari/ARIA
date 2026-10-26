from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, JSON, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Event(Base):
    __tablename__ = "events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    start_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    location: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # List of {name: str, email: str}
    attendees: Mapped[list] = mapped_column(JSON, default=list, nullable=False)
    # whatsapp / email / manual / calendar_sync
    source: Mapped[str] = mapped_column(String(50), default="manual", nullable=False)
    # 0.0 – 1.0
    confidence_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    # pending / approved / rejected / synced
    status: Mapped[str] = mapped_column(String(50), default="pending", nullable=False, index=True)
    # Google Calendar / Outlook event ID after sync
    external_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    # Original text that triggered AI detection
    raw_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="events")  # noqa: F821
