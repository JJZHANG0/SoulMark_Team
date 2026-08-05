from collections.abc import AsyncIterator
from pathlib import Path

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.session import get_db
from app.main import create_app
from app.models import (  # noqa: F401
    Contact,
    ContactEvent,
    ConversationReview,
    PhoneVerificationCode,
    PracticeSession,
    User,
)
from app.services.avatar_storage import AvatarStorage, get_avatar_storage
from app.services.event_image_storage import EventImageStorage, get_event_image_storage


@pytest.fixture
async def application(tmp_path: Path) -> AsyncIterator[FastAPI]:
    test_engine = create_async_engine(
        "sqlite+aiosqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(test_engine, expire_on_commit=False)

    async with test_engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)

    async def override_get_db() -> AsyncIterator[AsyncSession]:
        async with session_factory() as session:
            yield session

    test_app = create_app()
    test_app.dependency_overrides[get_db] = override_get_db
    test_app.dependency_overrides[get_avatar_storage] = lambda: AvatarStorage(
        tmp_path / "avatars",
        5 * 1024 * 1024,
    )
    test_app.dependency_overrides[get_event_image_storage] = lambda: EventImageStorage(
        tmp_path / "events",
        7 * 1024 * 1024,
    )
    yield test_app
    test_app.dependency_overrides.clear()
    await test_engine.dispose()


@pytest.fixture
async def client(application: FastAPI) -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=application)
    async with AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


@pytest.fixture
async def auth_headers(client: AsyncClient) -> dict[str, str]:
    registration = {
        "email": "profile@example.com",
        "password": "StrongPass123!",
        "display_name": "Profile Owner",
    }
    assert (await client.post("/api/v1/auth/register", json=registration)).status_code == 201
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": registration["email"], "password": registration["password"]},
    )
    return {"Authorization": f"Bearer {login.json()['access_token']}"}
