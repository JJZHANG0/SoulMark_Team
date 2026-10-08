from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.user import User, utc_now
from app.schemas.user import UserUpdate


async def update_profile(session: AsyncSession, user: User, payload: UserUpdate) -> User:
    changes = payload.model_dump(exclude_unset=True)
    if "display_name" in changes:
        changes["display_name"] = changes["display_name"].strip()
    if changes.get("onboarding_completed") and not user.onboarding_completed:
        changes["onboarding_completed_at"] = utc_now()

    for field, value in changes.items():
        setattr(user, field, value)

    await session.commit()
    await session.refresh(user)
    return user


async def advance_tutorial(session: AsyncSession, user: User, requested_step: int) -> User:
    if requested_step not in {user.tutorial_step, user.tutorial_step + 1}:
        raise AppError(
            "tutorial_step_conflict",
            "新手指引必须按顺序完成。",
            409,
        )

    if requested_step == user.tutorial_step:
        return user

    user.tutorial_step = requested_step
    if requested_step == 4 and user.tutorial_completed_at is None:
        user.tutorial_completed_at = utc_now()
    await session.commit()
    await session.refresh(user)
    return user
