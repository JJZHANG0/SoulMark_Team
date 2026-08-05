from httpx import AsyncClient

REGISTER_PAYLOAD = {
    "email": "owner@example.com",
    "password": "StrongPass123!",
    "display_name": "Owner",
}


async def test_register_and_login_return_safe_user_and_token(client: AsyncClient) -> None:
    registered = await client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    assert registered.status_code == 201
    assert registered.json()["email"] == "owner@example.com"
    assert "password_hash" not in registered.json()

    logged_in = await client.post(
        "/api/v1/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": REGISTER_PAYLOAD["password"]},
    )

    assert logged_in.status_code == 200
    assert logged_in.json()["token_type"] == "bearer"
    assert logged_in.json()["access_token"]
    assert logged_in.json()["expires_in_seconds"] == 30 * 24 * 60 * 60


async def test_duplicate_email_returns_stable_conflict(client: AsyncClient) -> None:
    assert (await client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)).status_code == 201

    response = await client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)

    assert response.status_code == 409
    assert response.json() == {
        "error": {
            "code": "email_already_registered",
            "message": "An account with this email already exists.",
        }
    }


async def test_invalid_credentials_return_unauthorized(client: AsyncClient) -> None:
    assert (await client.post("/api/v1/auth/register", json=REGISTER_PAYLOAD)).status_code == 201

    response = await client.post(
        "/api/v1/auth/login",
        json={"email": REGISTER_PAYLOAD["email"], "password": "WrongPass123!"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_credentials"
