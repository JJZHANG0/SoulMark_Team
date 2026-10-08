from datetime import UTC, datetime
from uuid import uuid4


def review(event_id=None):
    return dict(
        title="Review",
        source="manual",
        transcript="hello",
        score=70,
        reason="reason",
        advice="advice",
        event_id=str(event_id or uuid4()),
    )


def practice(event_id=None, rounds=2):
    messages = [
        dict(role=role, text=f"{role}{i}") for i in range(rounds) for role in ("user", "assistant")
    ]
    return dict(
        participant_name="Soul",
        mode_title="Practice",
        event_id=str(event_id or uuid4()),
        messages=messages,
        user_transcript="\n".join(m["text"] for m in messages if m["role"] == "user"),
        assistant_transcript="\n".join(m["text"] for m in messages if m["role"] == "assistant"),
    )


async def test_rewards_replay_and_delete(client, auth_headers):
    data = review()
    first = await client.post("/api/v1/reviews", headers=auth_headers, json=data)
    assert first.status_code == 201
    assert first.json()["awarded_experience"] == 30
    again = (await client.post("/api/v1/reviews", headers=auth_headers, json=data)).json()
    assert again["id"] == first.json()["id"]
    assert again["awarded_experience"] == 0
    altered = dict(data, transcript="different")
    assert (
        await client.post("/api/v1/reviews", headers=auth_headers, json=altered)
    ).status_code == 409
    await client.delete("/api/v1/reviews/" + first.json()["id"], headers=auth_headers)
    assert (
        await client.post("/api/v1/reviews", headers=auth_headers, json=data)
    ).status_code == 409
    assert (await client.get("/api/v1/growth", headers=auth_headers)).json()["balance"] == 30


async def test_chat_cap_rollover_and_empty(client, auth_headers, monkeypatch):
    from app.services import growth

    clock = [datetime(2026, 10, 1, 12, tzinfo=UTC)]
    monkeypatch.setattr(growth, "utc_now", lambda: clock[0])
    data = practice()
    result = await client.post("/api/v1/practices", headers=auth_headers, json=data)
    assert result.json()["awarded_experience"] == 10
    assert (await client.post("/api/v1/practices", headers=auth_headers, json=data)).json()[
        "awarded_experience"
    ] == 0
    assert (
        await client.post("/api/v1/practices", headers=auth_headers, json=practice(rounds=20))
    ).json()["awarded_experience"] == 40
    assert (await client.post("/api/v1/practices", headers=auth_headers, json=practice())).json()[
        "awarded_experience"
    ] == 0
    clock[0] = datetime(2026, 10, 2, 0, tzinfo=UTC)
    assert (await client.post("/api/v1/practices", headers=auth_headers, json=practice())).json()[
        "awarded_experience"
    ] == 10
    assert (
        await client.post("/api/v1/practices", headers=auth_headers, json=practice(rounds=0))
    ).json()["awarded_experience"] == 0
    invalid = dict(practice(), user_transcript="forged")
    assert (
        await client.post("/api/v1/practices", headers=auth_headers, json=invalid)
    ).status_code == 422


async def test_owner_isolation(client, auth_headers):
    await client.post("/api/v1/reviews", headers=auth_headers, json=review())
    await client.post(
        "/api/v1/auth/register",
        json=dict(email="other@example.com", password="StrongPass123!", display_name="Other"),
    )
    login = await client.post(
        "/api/v1/auth/login", json=dict(email="other@example.com", password="StrongPass123!")
    )
    other = {"Authorization": "Bearer " + login.json()["access_token"]}
    assert (await client.get("/api/v1/growth", headers=other)).json()["balance"] == 0


async def test_failed_award_rolls_back_activity(client, auth_headers, monkeypatch):
    import pytest

    from app.services import growth

    original = growth.award_experience

    async def fail(*args, **kwargs):
        await original(*args, **kwargs)
        raise RuntimeError("simulated write failure")

    monkeypatch.setattr(growth, "award_experience", fail)
    with pytest.raises(RuntimeError, match="simulated"):
        await client.post("/api/v1/reviews", headers=auth_headers, json=review())
    assert (await client.get("/api/v1/reviews", headers=auth_headers)).json() == []
    assert (await client.get("/api/v1/growth", headers=auth_headers)).json()["balance"] == 0
