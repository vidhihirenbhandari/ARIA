from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    assistant_name: Mapped[str] = mapped_column(String(100), default="ARIA", nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    oauth_provider: Mapped[str] = mapped_column(String(50), nullable=False)  # google/apple/microsoft
    oauth_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    fcm_token: Mapped[str | None] = mapped_column(String(512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # Relationships
    events: Mapped[list["Event"]] = relationship(  # noqa: F821
        "Event", back_populates="user", cascade="all, delete-orphan"
    )
    tasks: Mapped[list["Task"]] = relationship(  # noqa: F821
        "Task", back_populates="user", cascade="all, delete-orphan"
    )
    memories: Mapped[list["Memory"]] = relationship(  # noqa: F821
        "Memory", back_populates="user", cascade="all, delete-orphan"
    )
    conversations: Mapped[list["Conversation"]] = relationship(  # noqa: F821
        "Conversation", back_populates="user", cascade="all, delete-orphan"
    )
    travels: Mapped[list["Travel"]] = relationship(  # noqa: F821
        "Travel", back_populates="user", cascade="all, delete-orphan"
    )
    permission: Mapped["Permission | None"] = relationship(  # noqa: F821
        "Permission", back_populates="user", uselist=False, cascade="all, delete-orphan"
    )
    integrations: Mapped[list["Integration"]] = relationship(  # noqa: F821
        "Integration", back_populates="user", cascade="all, delete-orphan"
    )
