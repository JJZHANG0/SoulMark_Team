from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.security import hash_password, verify_password
from app.models.user import User
from app.schemas.auth import RegisterRequest


def normalize_email(email: str) -> str:
    return email.strip().lower()


async def register_user(session: AsyncSession, payload: RegisterRequest) -> User:
    email = normalize_email(str(payload.email))
    existing = await session.scalar(select(User).where(User.email == email))
    if existing is not None:
        raise AppError(
            "email_already_registered",
            "An account with this email already exists.",
            409,
        )

    user = User(
        email=email,
        password_hash=hash_password(payload.password),
        display_name=payload.display_name.strip(),
    )
    session.add(user)
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise AppError(
            "email_already_registered",
            "An account with this email already exists.",
            409,
        ) from exc
    await session.refresh(user)
    return user


async def authenticate_user(session: AsyncSession, email: str, password: str) -> User:
    user = await session.scalar(select(User).where(User.email == normalize_email(email)))
    if user is None or not verify_password(password, user.password_hash):
        raise AppError("invalid_credentials", "The email or password is incorrect.", 401)
    if not user.is_active:
        raise AppError("inactive_user", "This account is inactive.", 401)
    return user
