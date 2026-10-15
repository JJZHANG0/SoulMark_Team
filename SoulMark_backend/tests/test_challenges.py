from app.services.challenge_catalog import CHALLENGES, CHALLENGES_BY_KEY


def test_catalog_is_curated_and_consistent():
    assert 6 <= len(CHALLENGES) <= 10
    assert len(CHALLENGES_BY_KEY) == len(CHALLENGES)
    models = {c.model for c in CHALLENGES}
    assert {"johari", "values", "emotional_intelligence", "awareness_wheel"} <= models
    for challenge in CHALLENGES:
        assert challenge.steps and challenge.duration_minutes > 0
        assert all(step.kind in {"text", "rating"} for step in challenge.steps)


async def test_challenges_require_auth(client):
    assert (await client.get("/api/v1/challenges")).status_code == 401
    assert (await client.get("/api/v1/users/me/self-awareness-report")).status_code == 401


async def test_list_and_detail(client, auth_headers):
    listing = await client.get("/api/v1/challenges", headers=auth_headers)
    assert listing.status_code == 200
    body = listing.json()
    assert len(body["challenges"]) == len(CHALLENGES)
    assert body["active_count"] == 0
    assert all(item["status"] == "not_started" for item in body["challenges"])
    detail = await client.get("/api/v1/challenges/values_compass", headers=auth_headers)
    assert detail.status_code == 200
    assert detail.json()["steps"][0]["response"] is None
    missing = await client.get("/api/v1/challenges/nope", headers=auth_headers)
    assert missing.status_code == 404


async def test_full_challenge_flow_awards_once(client, auth_headers):
    key = "values_compass"
    base = f"/api/v1/challenges/{key}"
    not_started = await client.put(f"{base}/steps/0", headers=auth_headers, json={"response": "x"})
    assert not_started.status_code == 409
    started = await client.post(f"{base}/start", headers=auth_headers)
    assert started.status_code == 200
    assert started.json()["status"] == "active"

    locked = await client.put(
        f"{base}/steps/2", headers=auth_headers, json={"response": "跳过前面的步骤看看"}
    )
    assert locked.status_code == 409
    short = await client.put(f"{base}/steps/0", headers=auth_headers, json={"response": "短"})
    assert short.status_code == 422

    answers = [
        "自由、成长、真诚、家人、创造",
        "成长、真诚、家人；最难舍的是自由",
        "换工作时我选择了成长，放弃了稳定",
    ]
    for index, text in enumerate(answers):
        result = await client.put(
            f"{base}/steps/{index}", headers=auth_headers, json={"response": text}
        )
        assert result.status_code == 200, result.text
        assert result.json()["challenge"]["completed_steps"] == index + 1
    no_rating = await client.put(f"{base}/steps/3", headers=auth_headers, json={})
    assert no_rating.status_code == 422
    done = await client.put(f"{base}/steps/3", headers=auth_headers, json={"rating": 4})
    assert done.status_code == 200
    payload = done.json()
    assert payload["challenge"]["status"] == "completed"
    assert payload["awarded_experience"] == 20
    assert payload["growth"]["balance"] == 20

    again = await client.post(f"{base}/complete", headers=auth_headers)
    assert again.status_code == 200
    assert again.json()["awarded_experience"] == 0

    restarted = await client.post(f"{base}/start", headers=auth_headers)
    assert restarted.json()["completed_steps"] == 0
    assert restarted.json()["completion_count"] == 1

    listing = (await client.get("/api/v1/challenges", headers=auth_headers)).json()
    assert listing["completed_count"] == 1
    assert listing["active_count"] == 1

    export = (await client.get("/api/v1/users/me/export", headers=auth_headers)).json()
    assert export["challenges"][0]["challenge_key"] == key


async def test_report_empty_and_after_challenge(client, auth_headers):
    empty = await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    assert empty.status_code == 200
    body = empty.json()
    assert body["challenges_completed"] == 0
    assert len(body["dimensions"]) == 4
    assert body["next_steps"]

    base = "/api/v1/challenges/six_second_pause"
    await client.post(f"{base}/start", headers=auth_headers)
    for index in range(3):
        await client.put(
            f"{base}/steps/{index}",
            headers=auth_headers,
            json={"response": "同事在会上打断我，我停下来深呼吸后再回应"},
        )
    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    assert report["challenges_completed"] == 1
    emotion = next(d for d in report["dimensions"] if d["key"] == "emotion")
    clarity = next(d for d in report["dimensions"] if d["key"] == "clarity")
    assert emotion["score"] > clarity["score"]
    assert report["highlights"]
    assert report["headline"].startswith("你最亮的一面")
