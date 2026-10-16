from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import utc_now


class SelfPage(Base):
    """One confirmed self page per user per Singapore week. Cells stay empty until confirmed."""

    __tablename__ = "self_pages"
    __table_args__ = (
        UniqueConstraint("owner_id", "week_start", name="uq_self_pages_owner_week"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    week_start: Mapped[date] = mapped_column(Date)
    who_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    pursuit_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    fear_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    pattern_1_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    pattern_2_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    pattern_3_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    blind_spot_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    weekly_step_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    weekly_step_completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    paused_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )


class SelfEvidence(Base):
    """A dated quote attached to one cell. Unassigned review picks use slot 'pool'."""

    __tablename__ = "self_evidence"

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    page_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("self_pages.id", ondelete="CASCADE"), index=True
    )
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    slot: Mapped[str] = mapped_column(String(20))
    source_type: Mapped[str] = mapped_column(String(40))
    source_id: Mapped[UUID | None] = mapped_column(Uuid, nullable=True)
    quote: Mapped[str] = mapped_column(Text)
    detail: Mapped[str] = mapped_column(Text)
    occurred_on: Mapped[date] = mapped_column(Date)
    confirmed: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
