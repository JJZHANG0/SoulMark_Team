from httpx import AsyncClient


async def _answer(client: AsyncClient, headers: dict[str, str], key: str, texts: list[str]) -> None:
    base = f"/api/v1/challenges/{key}"
    assert (await client.post(f"{base}/start", headers=headers)).status_code == 200
    for index, text in enumerate(texts):
        result = await client.put(
            f"{base}/steps/{index}", headers=headers, json={"response": text}
        )
        assert result.status_code == 200, result.text


def _draft(report: dict, slot: str, source_id: str | None = None) -> dict:
    matches = [
        item
        for item in report["draft"]
        if item["slot"] == slot
        and item["ready"]
        and (source_id is None or item["source_id"] == source_id)
    ]
    assert matches, report["draft"]
    return matches[0]


async def test_distress_stops_without_xp_or_a_conclusion(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    base = "/api/v1/challenges/values_compass"
    await client.post(f"{base}/start", headers=auth_headers)
    blocked = await client.put(
        f"{base}/steps/0",
        headers=auth_headers,
        json={"response": "我今天不想活了，什么都不想做"},
    )
    assert blocked.status_code == 409
    assert blocked.json()["error"]["code"] == "distress_check"
    detail = (await client.get(f"{base}", headers=auth_headers)).json()
    assert detail["completed_steps"] == 0
    growth = (await client.get("/api/v1/growth", headers=auth_headers)).json()
    assert growth["balance"] == 0

    paused = await client.post("/api/v1/users/me/self-page/pause", headers=auth_headers)
    assert paused.status_code == 200
    page = paused.json()
    assert page["paused_at"] is not None
    assert all(cell["text"] == "" for cell in page["cells"])
    assert page["evidence_covered"] == 0
    assert (await client.get("/api/v1/growth", headers=auth_headers)).json()["balance"] == 0

    continued = await client.put(
        f"{base}/steps/0",
        headers=auth_headers,
        json={"response": "我今天不想活了，什么都不想做", "continue_anyway": True},
    )
    assert continued.status_code == 200
    assert continued.json()["awarded_experience"] == 0
    assert continued.json()["challenge"]["completed_steps"] == 1


async def test_confirm_writes_cells_and_leaves_thin_evidence_blank(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    await _answer(
        client,
        auth_headers,
        "self_concept_ten",
        [
            "我是会赶稿的人。我是会迟到的人。我是会把话咽回去的人。",
            "最稳定的一句是：我是会把话咽回去的人。",
        ],
    )
    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    who = next(cell for cell in report["cells"] if cell["slot"] == "who")
    assert who["text"] == ""
    assert who["covered"] is False
    stable = _draft(report, "who")
    assert stable["source_type"] == "challenge_reflection"

    thin = await client.put(
        "/api/v1/users/me/self-page/cells",
        headers=auth_headers,
        json={"slot": "pattern_1", "text": "我一被打断就先闭嘴", "evidence": [stable]},
    )
    assert thin.status_code == 422
    still = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    assert all(cell["text"] == "" for cell in still["cells"])

    confirmed = await client.put(
        "/api/v1/users/me/self-page/cells",
        headers=auth_headers,
        json={
            "slot": "who",
            "text": "我是会把话咽回去的人",
            "evidence": [stable],
        },
    )
    assert confirmed.status_code == 200, confirmed.text
    page = confirmed.json()
    who = next(cell for cell in page["cells"] if cell["slot"] == "who")
    assert who["covered"] is True
    assert who["text"] == "我是会把话咽回去的人"
    assert page["evidence_covered"] == 1
    assert "overall_score" not in page

    await _answer(
        client,
        auth_headers,
        "six_second_pause",
        ["会上被打断后我想立刻反驳"],
    )
    await _answer(
        client,
        auth_headers,
        "emotion_naming",
        ["第一天的词是委屈，因为会上被打断"],
    )
    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    examples = [item for item in report["draft"] if item["slot"] == "pattern" and item["ready"]]
    assert len(examples) >= 2
    pattern = await client.put(
        "/api/v1/users/me/self-page/cells",
        headers=auth_headers,
        json={
            "slot": "pattern_1",
            "text": "被打断时我会先闭嘴",
            "evidence": examples[:2],
        },
    )
    assert pattern.status_code == 200, pattern.text
    assert next(cell for cell in pattern.json()["cells"] if cell["slot"] == "pattern_1")["covered"]


async def test_review_line_is_evidence_and_does_not_change_analysis(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    created = await client.post(
        "/api/v1/reviews",
        headers=auth_headers,
        json={
            "title": "会上那句",
            "source": "manual",
            "transcript": "我当时说先把事实讲清楚。",
            "score": 81,
            "reason": "表达清晰",
            "advice": "你应该更冷静一点",
        },
    )
    assert created.status_code == 201
    review_id = created.json()["id"]
    rejected = await client.post(
        f"/api/v1/reviews/{review_id}/my-line",
        headers=auth_headers,
        json={"quote": "你应该更冷静一点"},
    )
    assert rejected.status_code == 422
    marked = await client.post(
        f"/api/v1/reviews/{review_id}/my-line",
        headers=auth_headers,
        json={"quote": "我当时说先把事实讲清楚"},
    )
    assert marked.status_code == 200, marked.text
    assert marked.json()["confirmed"] is False
    assert marked.json()["slot"] == "pool"
    stored = (await client.get("/api/v1/reviews", headers=auth_headers)).json()
    assert stored[0]["score"] == 81
    assert stored[0]["advice"] == "你应该更冷静一点"
    report = (
        await client.get("/api/v1/users/me/self-awareness-report", headers=auth_headers)
    ).json()
    marked = [item for item in report["draft"] if item["slot"] == "marked"]
    assert any("先把事实讲清楚" in item["quote"] for item in marked)
    assert all("你应该更冷静" not in item["quote"] for item in report["draft"])
    assert all(cell["text"] == "" for cell in report["cells"])
