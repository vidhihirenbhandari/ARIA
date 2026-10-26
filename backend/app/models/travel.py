from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, JSON, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Travel(Base):
    __tablename__ = "travels"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # flight / hotel / train / car_rental
    travel_type: Mapped[str] = mapped_column(String(50), nullable=False)
    # {airline, flight_no, from, to, booking_ref, seat, class, confirmation_no, ...}
    details: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    departure_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    arrival_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # upcoming / completed / cancelled
    status: Mapped[str] = mapped_column(String(30), default="upcoming", nullable=False)
    # email / manual
    source: Mapped[str] = mapped_column(String(50), default="email", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    user: Mapped["User"] = relationship("User", back_populates="travels")  # noqa: F821
