from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


def utc_now() -> datetime:
    return datetime.now(UTC)


class User(Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    email: Mapped[str | None] = mapped_column(String(320), unique=True, index=True, nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone_number: Mapped[str | None] = mapped_column(
        String(20), unique=True, index=True, nullable=True
    )
    wechat_openid: Mapped[str | None] = mapped_column(
        String(128), unique=True, index=True, nullable=True
    )
    wechat_unionid: Mapped[str | None] = mapped_column(
        String(128), unique=True, index=True, nullable=True
    )
    display_name: Mapped[str] = mapped_column(String(100))
    preferred_language: Mapped[str] = mapped_column(String(5), default="zh")
    gender: Mapped[str | None] = mapped_column(String(20), nullable=True)
    appearance: Mapped[str] = mapped_column(String(20), default="auto")
    communication_goal: Mapped[str | None] = mapped_column(String(80), nullable=True)
    onboarding_completed: Mapped[bool] = mapped_column(Boolean, default=False)
    onboarding_completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utc_now, onupdate=utc_now
    )

    @property
    def has_wechat(self) -> bool:
        return self.wechat_openid is not None
