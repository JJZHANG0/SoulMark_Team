from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import utc_now


class PracticeSession(Base):
    __tablename__ = "practice_sessions"
    __table_args__ = (CheckConstraint("duration_seconds >= 0", name="ck_practice_duration"),)

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    contact_id: Mapped[UUID | None] = mapped_column(
        Uuid, ForeignKey("contacts.id", ondelete="SET NULL"), nullable=True
    )
    participant_name: Mapped[str] = mapped_column(String(100))
    mode_title: Mapped[str] = mapped_column(String(100))
    mode_guidance: Mapped[str | None] = mapped_column(Text, nullable=True)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)
    user_transcript: Mapped[str] = mapped_column(Text, default="")
    assistant_transcript: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)


class ConversationReview(Base):
    __tablename__ = "conversation_reviews"
    __table_args__ = (CheckConstraint("score >= 0 AND score <= 100", name="ck_reviews_score"),)

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    practice_id: Mapped[UUID | None] = mapped_column(
        Uuid, ForeignKey("practice_sessions.id", ondelete="SET NULL"), nullable=True
    )
    title: Mapped[str] = mapped_column(String(160))
    source: Mapped[str] = mapped_column(String(30))
    transcript: Mapped[str] = mapped_column(Text)
    score: Mapped[int] = mapped_column(Integer)
    reason: Mapped[str] = mapped_column(Text)
    advice: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
