from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import utc_now


class ChallengeProgress(Base):
    """One row per user per challenge; restarting resets the same row."""

    __tablename__ = "challenge_progress"
    __table_args__ = (
        UniqueConstraint("owner_id", "challenge_key", name="uq_challenge_progress_owner_key"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    challenge_key: Mapped[str] = mapped_column(String(60))
    status: Mapped[str] = mapped_column(String(20), default="active")
    completed_steps: Mapped[int] = mapped_column(Integer, default=0)
    completion_count: Mapped[int] = mapped_column(Integer, default=0)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ChallengeReflection(Base):
    __tablename__ = "challenge_reflections"
    __table_args__ = (
        UniqueConstraint("progress_id", "step_index", name="uq_challenge_reflection_step"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    progress_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("challenge_progress.id", ondelete="CASCADE"), index=True
    )
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    step_index: Mapped[int] = mapped_column(Integer)
    response: Mapped[str] = mapped_column(Text)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
