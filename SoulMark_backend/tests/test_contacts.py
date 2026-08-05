import base64

from httpx import AsyncClient

PNG_BYTES = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)

CONTACT_PAYLOAD = {
    "name": "Wren",
    "relationship_label": "Friend",
    "notes": "A thoughtful friend.",
    "strength": 80,
}


async def create_headers(
    client: AsyncClient,
    email: str,
    display_name: str,
) -> dict[str, str]:
    password = "StrongPass123!"
    registration = {"email": email, "password": password, "display_name": display_name}
    assert (await client.post("/api/v1/auth/register", json=registration)).status_code == 201
    login = await client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": password},
    )
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


async def test_user_can_manage_owned_contact(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    created = await client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json=CONTACT_PAYLOAD,
    )

    assert created.status_code == 201
    contact_id = created.json()["id"]

    listed = await client.get("/api/v1/contacts", headers=auth_headers)
    assert listed.status_code == 200
    assert [contact["name"] for contact in listed.json()] == ["Wren"]

    updated = await client.patch(
        f"/api/v1/contacts/{contact_id}",
        headers=auth_headers,
        json={"relationship_label": "Best Friend", "strength": 95},
    )
    assert updated.status_code == 200
    assert updated.json()["relationship_label"] == "Best Friend"
    assert updated.json()["strength"] == 95

    deleted = await client.delete(f"/api/v1/contacts/{contact_id}", headers=auth_headers)
    assert deleted.status_code == 204
    assert (await client.get("/api/v1/contacts", headers=auth_headers)).json() == []


async def test_sixth_contact_is_rejected(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    for index in range(5):
        response = await client.post(
            "/api/v1/contacts",
            headers=auth_headers,
            json={
                "name": f"Person {index}",
                "relationship_label": "Friend",
                "strength": 50,
            },
        )
        assert response.status_code == 201

    response = await client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={"name": "Sixth", "relationship_label": "Friend", "strength": 50},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "contact_limit_reached"


async def test_contact_is_hidden_from_other_users(client: AsyncClient) -> None:
    owner_headers = await create_headers(client, "first@example.com", "First")
    other_headers = await create_headers(client, "second@example.com", "Second")
    created = await client.post(
        "/api/v1/contacts",
        headers=owner_headers,
        json=CONTACT_PAYLOAD,
    )
    assert created.status_code == 201
    contact_id = created.json()["id"]

    response = await client.get(f"/api/v1/contacts/{contact_id}", headers=other_headers)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "contact_not_found"


async def test_user_can_upload_replace_and_delete_contact_avatar(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    created = await client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json=CONTACT_PAYLOAD,
    )
    contact_id = created.json()["id"]

    uploaded = await client.post(
        f"/api/v1/contacts/{contact_id}/avatar",
        headers=auth_headers,
        files={"file": ("avatar.png", PNG_BYTES, "image/png")},
    )

    assert uploaded.status_code == 200
    first_url = uploaded.json()["avatar_url"]
    assert first_url.startswith("/media/avatars/")

    replaced = await client.post(
        f"/api/v1/contacts/{contact_id}/avatar",
        headers=auth_headers,
        files={"file": ("replacement.png", PNG_BYTES, "image/png")},
    )
    assert replaced.status_code == 200
    assert replaced.json()["avatar_url"] != first_url

    deleted = await client.delete(
        f"/api/v1/contacts/{contact_id}/avatar",
        headers=auth_headers,
    )
    assert deleted.status_code == 200
    assert deleted.json()["avatar_url"] is None


async def test_avatar_upload_rejects_unsupported_file_type(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    created = await client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json=CONTACT_PAYLOAD,
    )

    response = await client.post(
        f"/api/v1/contacts/{created.json()['id']}/avatar",
        headers=auth_headers,
        files={"file": ("avatar.txt", b"not an image", "text/plain")},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_avatar_type"


async def test_avatar_upload_rejects_oversized_file(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    created = await client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json=CONTACT_PAYLOAD,
    )

    response = await client.post(
        f"/api/v1/contacts/{created.json()['id']}/avatar",
        headers=auth_headers,
        files={"file": ("large.jpg", b"x" * (5 * 1024 * 1024 + 1), "image/jpeg")},
    )

    assert response.status_code == 413
    assert response.json()["error"]["code"] == "avatar_too_large"


async def test_contact_event_timeline_is_persistent_and_owner_scoped(
    client: AsyncClient,
) -> None:
    owner_headers = await create_headers(client, "timeline@example.com", "Timeline Owner")
    other_headers = await create_headers(client, "outsider@example.com", "Outsider")
    contact = await client.post(
        "/api/v1/contacts",
        headers=owner_headers,
        json=CONTACT_PAYLOAD,
    )
    contact_id = contact.json()["id"]

    created = await client.post(
        f"/api/v1/contacts/{contact_id}/events",
        headers=owner_headers,
        json={
            "title": "第一次表白",
            "details": "我向她说明了自己的感受。",
            "occurred_at": "2025-02-14T12:30:00Z",
        },
    )

    assert created.status_code == 201
    uploaded = await client.post(
        f"/api/v1/contacts/{contact_id}/events/{created.json()['id']}/image",
        headers=owner_headers,
        files={"file": ("event.png", PNG_BYTES, "image/png")},
    )
    assert uploaded.status_code == 200
    assert uploaded.json()["image_url"].startswith("/media/events/")
    listed = await client.get(
        f"/api/v1/contacts/{contact_id}/events",
        headers=owner_headers,
    )
    assert listed.json()[0]["title"] == "第一次表白"
    hidden = await client.get(
        f"/api/v1/contacts/{contact_id}/events",
        headers=other_headers,
    )
    assert hidden.status_code == 404


async def test_other_user_cannot_manage_contact_avatar(client: AsyncClient) -> None:
    owner_headers = await create_headers(client, "avatar-owner@example.com", "Owner")
    other_headers = await create_headers(client, "avatar-other@example.com", "Other")
    created = await client.post(
        "/api/v1/contacts",
        headers=owner_headers,
        json=CONTACT_PAYLOAD,
    )

    response = await client.post(
        f"/api/v1/contacts/{created.json()['id']}/avatar",
        headers=other_headers,
        files={"file": ("avatar.png", PNG_BYTES, "image/png")},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "contact_not_found"
