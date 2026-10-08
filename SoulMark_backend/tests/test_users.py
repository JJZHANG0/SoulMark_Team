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


async def test_new_user_advances_tutorial_in_order_and_retries_are_idempotent(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    current = await client.get("/api/v1/users/me", headers=auth_headers)
    assert current.status_code == 200
    assert current.json()["tutorial_step"] == 0
    assert current.json()["tutorial_completed_at"] is None

    first = await client.patch(
        "/api/v1/users/me/tutorial",
        headers=auth_headers,
        json={"step": 1},
    )
    assert first.status_code == 200
    assert first.json()["tutorial_step"] == 1
    assert first.json()["tutorial_completed_at"] is None

    repeated = await client.patch(
        "/api/v1/users/me/tutorial",
        headers=auth_headers,
        json={"step": 1},
    )
    assert repeated.status_code == 200
    assert repeated.json()["tutorial_step"] == 1

    for step in (2, 3, 4):
        advanced = await client.patch(
            "/api/v1/users/me/tutorial",
            headers=auth_headers,
            json={"step": step},
        )
        assert advanced.status_code == 200
        assert advanced.json()["tutorial_step"] == step

    completed_at = advanced.json()["tutorial_completed_at"]
    assert completed_at is not None
    repeated_completion = await client.patch(
        "/api/v1/users/me/tutorial",
        headers=auth_headers,
        json={"step": 4},
    )
    assert repeated_completion.status_code == 200
    assert repeated_completion.json()["tutorial_completed_at"] == completed_at


async def test_tutorial_rejects_skips_backwards_steps_and_out_of_range_values(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    skipped = await client.patch(
        "/api/v1/users/me/tutorial",
        headers=auth_headers,
        json={"step": 2},
    )
    assert skipped.status_code == 409
    assert skipped.json()["error"]["code"] == "tutorial_step_conflict"

    assert (
        await client.patch(
            "/api/v1/users/me/tutorial",
            headers=auth_headers,
            json={"step": 1},
        )
    ).status_code == 200
    backwards = await client.patch(
        "/api/v1/users/me/tutorial",
        headers=auth_headers,
        json={"step": 0},
    )
    assert backwards.status_code == 409
    assert backwards.json()["error"]["code"] == "tutorial_step_conflict"

    for invalid_step in (-1, 5):
        invalid = await client.patch(
            "/api/v1/users/me/tutorial",
            headers=auth_headers,
            json={"step": invalid_step},
        )
        assert invalid.status_code == 422


async def test_tutorial_progress_is_isolated_per_account(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    assert (
        await client.patch(
            "/api/v1/users/me/tutorial",
            headers=auth_headers,
            json={"step": 1},
        )
    ).status_code == 200

    registration = {
        "email": "second-tutorial-user@example.com",
        "password": "StrongPass123!",
        "display_name": "Second User",
    }
    created = await client.post("/api/v1/auth/register", json=registration)
    assert created.status_code == 201
    assert created.json()["tutorial_step"] == 0

    login = await client.post(
        "/api/v1/auth/login",
        json={"email": registration["email"], "password": registration["password"]},
    )
    second_headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    second = await client.get("/api/v1/users/me", headers=second_headers)
    assert second.status_code == 200
    assert second.json()["tutorial_step"] == 0


async def test_user_can_save_jade_green_theme(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    updated = await client.patch(
        "/api/v1/users/me",
        headers=auth_headers,
        json={"gender": "green"},
    )

    assert updated.status_code == 200
    assert updated.json()["gender"] == "green"

    current = await client.get("/api/v1/users/me", headers=auth_headers)
    assert current.status_code == 200
    assert current.json()["gender"] == "green"


async def test_user_can_export_and_delete_account(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    exported = await client.get("/api/v1/users/me/export", headers=auth_headers)

    assert exported.status_code == 200
    assert exported.json()["user"]["display_name"] == "Profile Owner"
    assert exported.json()["contacts"] == []
    assert exported.json()["contact_events"] == []
    assert exported.json()["practices"] == []
    assert exported.json()["reviews"] == []

    rejected = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=auth_headers,
        json={"password": "WrongPass123!"},
    )
    assert rejected.status_code == 401
    assert (await client.get("/api/v1/users/me", headers=auth_headers)).status_code == 200

    deleted = await client.request(
        "DELETE",
        "/api/v1/users/me",
        headers=auth_headers,
        json={"password": "StrongPass123!"},
    )
    assert deleted.status_code == 204
    assert (await client.get("/api/v1/users/me", headers=auth_headers)).status_code == 401
