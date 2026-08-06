from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import utc_now


class Contact(Base):
    __tablename__ = "contacts"
    __table_args__ = (
        CheckConstraint("strength >= 0 AND strength <= 100", name="ck_contacts_strength"),
        CheckConstraint("trust_score >= 0 AND trust_score <= 100", name="ck_contacts_trust_score"),
        CheckConstraint(
            "emotional_depth_score >= 0 AND emotional_depth_score <= 100",
            name="ck_contacts_emotional_depth_score",
        ),
        CheckConstraint(
            "reciprocity_score >= 0 AND reciprocity_score <= 100",
            name="ck_contacts_reciprocity_score",
        ),
        CheckConstraint(
            "support_score >= 0 AND support_score <= 100",
            name="ck_contacts_support_score",
        ),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    name: Mapped[str] = mapped_column(String(100))
    relationship_label: Mapped[str] = mapped_column(String(100))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    strength: Mapped[int] = mapped_column(Integer, default=50)
    trust_score: Mapped[int] = mapped_column(Integer, default=50)
    emotional_depth_score: Mapped[int] = mapped_column(Integer, default=50)
    reciprocity_score: Mapped[int] = mapped_column(Integer, default=50)
    support_score: Mapped[int] = mapped_column(Integer, default=50)
    event_count: Mapped[int] = mapped_column(Integer, default=0)
    intimacy_calculated: Mapped[bool] = mapped_column(Boolean, default=False)
    position_x: Mapped[float] = mapped_column(Float, default=0.5)
    position_y: Mapped[float] = mapped_column(Float, default=0.5)
    symbol: Mapped[str] = mapped_column(String(80), default="person.fill")
    memory: Mapped[str | None] = mapped_column(Text, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )


class ContactEvent(Base):
    __tablename__ = "contact_events"

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    contact_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("contacts.id", ondelete="CASCADE"),
        index=True,
    )
    title: Mapped[str] = mapped_column(String(160))
    details: Mapped[str] = mapped_column(Text)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    image_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    trust_delta: Mapped[int] = mapped_column(Integer, default=0)
    emotional_depth_delta: Mapped[int] = mapped_column(Integer, default=0)
    reciprocity_delta: Mapped[int] = mapped_column(Integer, default=0)
    support_delta: Mapped[int] = mapped_column(Integer, default=0)
    strength_delta: Mapped[int] = mapped_column(Integer, default=0)
    impact_explanation: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )
