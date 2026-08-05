from httpx import AsyncClient


async def test_practices_reviews_and_stats_persist_for_owner(
    client: AsyncClient, auth_headers: dict[str, str]
) -> None:
    practice = await client.post(
        "/api/v1/practices",
        headers=auth_headers,
        json={
            "participant_name": "Soul",
            "mode_title": "冲突沟通",
            "duration_seconds": 42,
            "user_transcript": "我希望下次先把事实说清楚。",
            "assistant_transcript": "可以先描述发生了什么。",
        },
    )
    assert practice.status_code == 201

    review = await client.post(
        "/api/v1/reviews",
        headers=auth_headers,
        json={
            "practice_id": practice.json()["id"],
            "title": "第一次复盘",
            "source": "scenario",
            "transcript": "我希望下次先把事实说清楚。",
            "score": 86,
            "reason": "表达清晰",
            "advice": "继续补充具体需求",
        },
    )
    assert review.status_code == 201

    practices = await client.get("/api/v1/practices", headers=auth_headers)
    reviews = await client.get("/api/v1/reviews", headers=auth_headers)
    stats = await client.get("/api/v1/stats", headers=auth_headers)

    assert len(practices.json()) == 1
    assert len(reviews.json()) == 1
    assert stats.json() == {
        "contacts_count": 0,
        "practices_count": 1,
        "reviews_count": 1,
        "relationship_categories_count": 0,
        "average_review_score": 86.0,
    }


async def test_activity_requires_authentication(client: AsyncClient) -> None:
    assert (await client.get("/api/v1/practices")).status_code == 401
    assert (await client.get("/api/v1/reviews")).status_code == 401
    assert (await client.get("/api/v1/stats")).status_code == 401
