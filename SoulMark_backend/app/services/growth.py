import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from functools import wraps
from typing import Concatenate
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import func, select, update
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.growth import ExperienceEvent, UserGrowth
from app.models.user import User
from app.models.user import utc_now as utc_now
from app.schemas.growth import GrowthSnapshot
from app.services.growth_rules import decay_due, level_progress

ZONE = ZoneInfo("Asia/Singapore")


def retry_locked_transaction[T, **P](
    function: Callable[Concatenate[AsyncSession, P], Awaitable[T]],
) -> Callable[Concatenate[AsyncSession, P], Awaitable[T]]:
    @wraps(function)
    async def wrapped(session: AsyncSession, /, *args: P.args, **kwargs: P.kwargs) -> T:
        for attempt in range(5):
            try:
                return await function(session, *args, **kwargs)
            except OperationalError as error:
                await session.rollback()
                if (
                    session.get_bind().dialect.name != "sqlite"
                    or "locked" not in str(error).lower()
                    or attempt == 4
                ):
                    raise
                await asyncio.sleep(0.025 * (attempt + 1))
        raise AssertionError("unreachable")

    return wrapped


async def lock_growth(session: AsyncSession, owner_id: UUID, now: datetime) -> UserGrowth:
    # The existing user row serializes lazy creation and all rewards across processes.
    if session.get_bind().dialect.name == "sqlite":
        await session.execute(
            update(User).where(User.id == owner_id).values(id=User.id, updated_at=User.updated_at)
        )
    user = await session.scalar(select(User).where(User.id == owner_id).with_for_update())
    if user is None:
        raise AppError("user_not_found", "Account not found.", 404)
    state = await session.scalar(
        select(UserGrowth)
        .where(UserGrowth.owner_id == owner_id)
        .execution_options(populate_existing=True)
    )
    if state is None:
        created = user.created_at
        if created.tzinfo is None:
            created = created.replace(tzinfo=UTC)
        day = min(created.astimezone(ZONE).date(), now.astimezone(ZONE).date())
        state = UserGrowth(
            owner_id=owner_id,
            balance=0,
            peak_level=1,
            last_active_date=day,
            decay_settled_through=day,
        )
        session.add(state)
        await session.flush()
    return state


async def settle_decay(session: AsyncSession, state: UserGrowth, now: datetime) -> int:
    today = now.astimezone(ZONE).date()
    amount = decay_due(state.last_active_date, state.decay_settled_through, today, state.balance)
    if amount:
        session.add(
            ExperienceEvent(
                owner_id=state.owner_id,
                event_key=f"decay:{today.isoformat()}",
                kind="decay",
                delta=-amount,
                created_at=now,
            )
        )
        state.balance -= amount
    state.decay_settled_through = max(state.decay_settled_through, today)
    await session.flush()
    return amount


def mark_active(state: UserGrowth, now: datetime) -> None:
    state.last_active_date = max(state.last_active_date, now.astimezone(ZONE).date())


async def chat_today(session: AsyncSession, owner_id: UUID, now: datetime) -> int:
    midnight = datetime.combine(now.astimezone(ZONE).date(), datetime.min.time(), ZONE).astimezone(
        UTC
    )
    return int(
        await session.scalar(
            select(func.coalesce(func.sum(ExperienceEvent.delta), 0)).where(
                ExperienceEvent.owner_id == owner_id,
                ExperienceEvent.kind == "practice",
                ExperienceEvent.created_at >= midnight,
                ExperienceEvent.created_at < midnight + timedelta(days=1),
            )
        )
        or 0
    )


async def award_experience(
    session: AsyncSession,
    state: UserGrowth,
    event_key: str,
    kind: str,
    requested: int,
    now: datetime,
    source_id: UUID,
    request_hash: str,
) -> int:
    amount = max(0, requested)
    if kind == "practice":
        amount = min(amount, max(0, 50 - await chat_today(session, state.owner_id, now)))
    session.add(
        ExperienceEvent(
            owner_id=state.owner_id,
            event_key=event_key,
            kind=kind,
            delta=amount,
            created_at=now,
            source_id=source_id,
            request_hash=request_hash,
        )
    )
    state.balance += amount
    state.peak_level = max(state.peak_level, level_progress(state.balance)[0])
    await session.flush()
    return amount


async def growth_snapshot(
    session: AsyncSession, state: UserGrowth, now: datetime, decayed_experience: int = 0
) -> GrowthSnapshot:
    level, progress, needed = level_progress(state.balance)
    milestones = [
        (1, "explorer"),
        (3, "listener"),
        (5, "communicator"),
        (10, "empath"),
        (20, "master"),
    ]
    title = next(key for threshold, key in reversed(milestones) if level >= threshold)
    next_level = next((threshold for threshold, _ in milestones if threshold > level), None)
    return GrowthSnapshot(
        balance=state.balance,
        level=level,
        level_experience=progress,
        next_level_experience=needed,
        peak_level=state.peak_level,
        chat_experience_today=await chat_today(session, state.owner_id, now),
        title_key=title,
        next_title_level=next_level,
        decayed_experience=decayed_experience,
        next_decay_date=max(
            state.last_active_date + timedelta(days=8),
            state.decay_settled_through + timedelta(days=1),
        ),
    )


@retry_locked_transaction
async def get_growth(session: AsyncSession, owner_id: UUID, active: bool = False) -> GrowthSnapshot:
    now = utc_now()
    state = await lock_growth(session, owner_id, now)
    decayed = await settle_decay(session, state, now)
    if active:
        mark_active(state, now)
    result = await growth_snapshot(session, state, now, decayed)
    await session.commit()
    return result
