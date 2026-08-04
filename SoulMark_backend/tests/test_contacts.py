from httpx import AsyncClient

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
