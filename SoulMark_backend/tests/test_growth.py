from datetime import UTC, datetime


async def test_growth_requires_auth(client):
    assert (await client.get("/api/v1/growth")).status_code == 401


async def test_growth_initial_active_and_decay(client, auth_headers, monkeypatch):
    from app.services import growth

    clock = [datetime(2026, 10, 1, 12, tzinfo=UTC)]
    monkeypatch.setattr(growth, "utc_now", lambda: clock[0])
    initial = await client.post("/api/v1/growth/active", headers=auth_headers)
    assert initial.status_code == 200
    assert initial.json()["balance"] == 0
    payload = dict(
        title="Review", source="manual", transcript="a", score=70, reason="reason", advice="advice"
    )
    for _ in range(4):
        assert (
            await client.post("/api/v1/reviews", headers=auth_headers, json=payload)
        ).status_code == 201
    clock[0] = datetime(2026, 10, 8, 12, tzinfo=UTC)
    assert (await client.get("/api/v1/growth", headers=auth_headers)).json()["balance"] == 120
    clock[0] = datetime(2026, 10, 11, 12, tzinfo=UTC)
    result = (await client.get("/api/v1/growth", headers=auth_headers)).json()
    assert result["balance"] == 90
    assert result["level"] == 1
    assert result["peak_level"] == 2
    assert result["decayed_experience"] == 30
    assert (await client.get("/api/v1/growth", headers=auth_headers)).json()[
        "decayed_experience"
    ] == 0
    await client.post("/api/v1/growth/active", headers=auth_headers)
    clock[0] = datetime(2026, 10, 18, 12, tzinfo=UTC)
    assert (await client.get("/api/v1/growth", headers=auth_headers)).json()["balance"] == 90
    clock[0] = datetime(2026, 11, 18, 12, tzinfo=UTC)
    assert (await client.post("/api/v1/growth/active", headers=auth_headers)).json()["balance"] == 0
    await client.post("/api/v1/reviews", headers=auth_headers, json=payload)
    assert (await client.get("/api/v1/growth", headers=auth_headers)).json()["balance"] == 30
