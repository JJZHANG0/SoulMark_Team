from datetime import UTC, datetime, timedelta

from httpx import AsyncClient
from sqlalchemy import select

from app.db.session import get_db
from app.models.phone_verification import PhoneVerificationCode
from app.services.external_auth import WeChatIdentity, get_sms_sender, get_wechat_client


class FakeWeChatClient:
    async def exchange_code(self, code: str) -> WeChatIdentity:
        assert code == "valid-wechat-code"
        return WeChatIdentity(openid="openid-123", unionid="unionid-123")


async def test_phone_code_login_auto_registers_user(client: AsyncClient) -> None:
    requested = await client.post(
        "/api/v1/auth/phone/code",
        json={"phone_number": "138 0013 8000"},
    )
    assert requested.status_code == 202
    assert "123456" not in requested.text

    logged_in = await client.post(
        "/api/v1/auth/phone/login",
        json={"phone_number": "13800138000", "code": "123456"},
    )
    assert logged_in.status_code == 200
    token = logged_in.json()["access_token"]

    profile = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert profile.status_code == 200
    assert profile.json()["phone_number"] == "+8613800138000"
    assert profile.json()["email"] is None
    assert profile.json()["has_wechat"] is False


async def test_phone_code_is_single_use_and_rate_limited(client: AsyncClient) -> None:
    payload = {"phone_number": "13900139000"}
    assert (await client.post("/api/v1/auth/phone/code", json=payload)).status_code == 202
    assert (await client.post("/api/v1/auth/phone/code", json=payload)).status_code == 429
    login_payload = {**payload, "code": "123456"}
    assert (await client.post("/api/v1/auth/phone/login", json=login_payload)).status_code == 200
    assert (await client.post("/api/v1/auth/phone/login", json=login_payload)).status_code == 401


async def test_invalid_phone_code_is_rejected(client: AsyncClient) -> None:
    payload = {"phone_number": "13700137000"}
    assert (await client.post("/api/v1/auth/phone/code", json=payload)).status_code == 202
    response = await client.post(
        "/api/v1/auth/phone/login",
        json={**payload, "code": "000000"},
    )
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_phone_code"


async def test_wechat_login_auto_registers_and_reuses_identity(
    client: AsyncClient,
    application: object,
) -> None:
    from fastapi import FastAPI

    assert isinstance(application, FastAPI)
    application.dependency_overrides[get_wechat_client] = lambda: FakeWeChatClient()
    payload = {"code": "valid-wechat-code"}

    first = await client.post("/api/v1/auth/wechat/login", json=payload)
    second = await client.post("/api/v1/auth/wechat/login", json=payload)
    assert first.status_code == 200
    assert second.status_code == 200

    first_profile = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {first.json()['access_token']}"},
    )
    second_profile = await client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {second.json()['access_token']}"},
    )
    assert first_profile.json()["id"] == second_profile.json()["id"]
    assert first_profile.json()["has_wechat"] is True
    assert first_profile.json()["email"] is None


class FakePnvsSmsSender:
    provider_name = "pnvs"
    verifies_remotely = True

    def __init__(self) -> None:
        self.sent_to: list[str] = []
        self.checked_codes: list[str] = []

    async def send_code(self, phone_number: str, code: str) -> None:
        self.sent_to.append(phone_number)
        assert len(code) == 6

    async def verify_code(self, phone_number: str, code: str) -> bool:
        assert phone_number == "+8613600136000"
        self.checked_codes.append(code)
        return code == "654321"


async def test_pnvs_sender_uses_remote_verification(
    client: AsyncClient,
    application: object,
) -> None:
    from fastapi import FastAPI

    assert isinstance(application, FastAPI)
    sender = FakePnvsSmsSender()
    application.dependency_overrides[get_sms_sender] = lambda: sender
    phone_payload = {"phone_number": "13600136000"}

    requested = await client.post("/api/v1/auth/phone/code", json=phone_payload)
    assert requested.status_code == 202
    assert sender.sent_to == ["+8613600136000"]

    rejected = await client.post(
        "/api/v1/auth/phone/login",
        json={**phone_payload, "code": "000000"},
    )
    assert rejected.status_code == 401

    accepted = await client.post(
        "/api/v1/auth/phone/login",
        json={**phone_payload, "code": "654321"},
    )
    assert accepted.status_code == 200
    assert sender.checked_codes == ["000000", "654321"]

    headers = {"Authorization": f"Bearer {accepted.json()['access_token']}"}
    session_override = application.dependency_overrides[get_db]
    async for session in session_override():
        latest_code = await session.scalar(
            select(PhoneVerificationCode).order_by(
                PhoneVerificationCode.created_at.desc()
            )
        )
        assert latest_code is not None
        latest_code.created_at = datetime.now(UTC) - timedelta(minutes=10)
        await session.commit()
        break
    assert (await client.post("/api/v1/auth/phone/code", json=phone_payload)).status_code == 202
    rejected_delete = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=headers,
        json={"code": "000000"},
    )
    assert rejected_delete.status_code == 401

    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=headers,
        json={"code": "654321"},
    )
    assert deleted.status_code == 204
