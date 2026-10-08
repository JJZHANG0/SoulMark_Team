from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.models.user import utc_now


class UserGrowth(Base):
    __tablename__ = "user_growth"
    __table_args__ = (CheckConstraint("balance >= 0", name="ck_growth_balance"),)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    balance: Mapped[int] = mapped_column(Integer, default=0)
    peak_level: Mapped[int] = mapped_column(Integer, default=1)
    last_active_date: Mapped[date] = mapped_column(Date)
    decay_settled_through: Mapped[date] = mapped_column(Date)


class ExperienceEvent(Base):
    __tablename__ = "experience_events"
    __table_args__ = (UniqueConstraint("owner_id", "event_key", name="uq_experience_event"),)
    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    owner_id: Mapped[UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    event_key: Mapped[str] = mapped_column(String(160))
    kind: Mapped[str] = mapped_column(String(20))
    delta: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    source_id: Mapped[UUID | None] = mapped_column(Uuid, nullable=True)
    request_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
