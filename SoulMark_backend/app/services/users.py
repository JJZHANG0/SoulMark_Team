from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.user import UserUpdate


async def update_profile(session: AsyncSession, user: User, payload: UserUpdate) -> User:
    changes = payload.model_dump(exclude_unset=True)
    if "display_name" in changes:
        changes["display_name"] = changes["display_name"].strip()

    for field, value in changes.items():
        setattr(user, field, value)

    await session.commit()
    await session.refresh(user)
    return user
