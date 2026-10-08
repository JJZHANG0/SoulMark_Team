import asyncio
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.db.base import Base
from app.models.growth import ExperienceEvent, UserGrowth
from app.models.user import User
from app.services import growth


async def test_concurrent_cap_and_decay_use_database_lock(tmp_path):
    engine = create_async_engine(
        f"sqlite+aiosqlite:///{tmp_path}/growth.db", connect_args={"timeout": 10}
    )
    factory = async_sessionmaker(engine, expire_on_commit=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    now = datetime(2026, 10, 1, 12, tzinfo=UTC)
    owner = uuid4()
    async with factory() as session:
        session.add(User(id=owner, display_name="Test", created_at=now))
        session.add(
            UserGrowth(
                owner_id=owner,
                balance=49,
                peak_level=1,
                last_active_date=now.date(),
                decay_settled_through=now.date(),
            )
        )
        session.add(
            ExperienceEvent(
                owner_id=owner, event_key="initial", kind="practice", delta=49, created_at=now
            )
        )
        await session.commit()

    @growth.retry_locked_transaction
    async def award(session):
        state = await growth.lock_growth(session, owner, now)
        value = await growth.award_experience(
            session, state, str(uuid4()), "practice", 5, now, uuid4(), "test"
        )
        await session.commit()
        return value

    async def one_award():
        async with factory() as session:
            return await award(session)

    assert sum(await asyncio.gather(one_award(), one_award())) == 1

    @growth.retry_locked_transaction
    async def decay(session):
        later = now + timedelta(days=9)
        state = await growth.lock_growth(session, owner, later)
        value = await growth.settle_decay(session, state, later)
        await session.commit()
        return value

    async def one_decay():
        async with factory() as session:
            return await decay(session)

    assert sum(await asyncio.gather(one_decay(), one_decay())) == 20
    async with factory() as session:
        assert (await session.get(UserGrowth, owner)).balance == 30
        assert (
            len(
                (
                    await session.scalars(
                        select(ExperienceEvent).where(ExperienceEvent.kind == "decay")
                    )
                ).all()
            )
            == 1
        )
    await engine.dispose()
