from fastapi import FastAPI
from httpx import AsyncClient
from sqlalchemy import select

from app.db.session import get_db
from app.models.user import User

PASSWORD = "StrongPass123!"


async def _register_with_phone(application: FastAPI, client: AsyncClient) -> None:
    registered = await client.post(
        "/api/v1/auth/register",
        json={"email": "phone@example.com", "password": PASSWORD, "display_name": "Phone"},
    )
    assert registered.status_code == 201
    async for session in application.dependency_overrides[get_db]():
        user = await session.scalar(select(User).where(User.email == "phone@example.com"))
        assert user is not None
        user.phone_number = "+8615105187207"
        await session.commit()


async def test_phone_password_login_returns_token(
    application: FastAPI, client: AsyncClient
) -> None:
    await _register_with_phone(application, client)

    response = await client.post(
        "/api/v1/auth/phone/password-login",
        json={"phone_number": "151 0518 7207", "password": PASSWORD},
    )

    assert response.status_code == 200
    token = response.json()["access_token"]
    me = await client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "phone@example.com"


async def test_phone_password_login_rejects_bad_credentials(
    application: FastAPI, client: AsyncClient
) -> None:
    await _register_with_phone(application, client)

    wrong = await client.post(
        "/api/v1/auth/phone/password-login",
        json={"phone_number": "15105187207", "password": "WrongPass123!"},
    )
    unknown = await client.post(
        "/api/v1/auth/phone/password-login",
        json={"phone_number": "13800138000", "password": PASSWORD},
    )

    assert wrong.status_code == 401
    assert wrong.json()["error"]["code"] == "invalid_credentials"
    assert unknown.status_code == 401
