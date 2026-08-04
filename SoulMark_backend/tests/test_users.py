from httpx import AsyncClient


async def test_user_can_read_and_update_own_profile(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    current = await client.get("/api/v1/users/me", headers=auth_headers)

    assert current.status_code == 200
    assert current.json()["display_name"] == "Profile Owner"

    updated = await client.patch(
        "/api/v1/users/me",
        headers=auth_headers,
        json={
            "display_name": "New Name",
            "preferred_language": "en",
            "gender": "female",
            "appearance": "dark",
        },
    )

    assert updated.status_code == 200
    assert updated.json()["display_name"] == "New Name"
    assert updated.json()["preferred_language"] == "en"
    assert updated.json()["gender"] == "female"
    assert updated.json()["appearance"] == "dark"
    assert "password_hash" not in updated.json()


async def test_profile_requires_authentication(client: AsyncClient) -> None:
    response = await client.get("/api/v1/users/me")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"
