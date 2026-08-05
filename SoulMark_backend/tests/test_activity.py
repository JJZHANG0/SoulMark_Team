from httpx import AsyncClient

from app.ai.review import ReviewAnalysis, get_review_analyzer


class FakeReviewAnalyzer:
    async def analyze(self, transcript: str, language: str) -> ReviewAnalysis:
        assert "我希望" in transcript
        assert language == "zh"
        return ReviewAnalysis(
            score=88,
            reason="表达了事实和需求，但对对方感受的回应还可以更充分。",
            advice="先复述对方的关注点，再提出清晰、可执行的下一步。",
        )


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


async def test_analyze_review_uses_ai_and_persists_result(
    client: AsyncClient, auth_headers: dict[str, str], application
) -> None:
    application.dependency_overrides[get_review_analyzer] = lambda: FakeReviewAnalyzer()

    response = await client.post(
        "/api/v1/reviews/analyze",
        headers=auth_headers,
        json={
            "title": "和朋友的误会",
            "source": "wechat",
            "transcript": "我希望下次我们可以先确认时间，也想听听你的感受。",
            "language": "zh",
        },
    )

    assert response.status_code == 201
    assert response.json()["score"] == 88
    assert "对方感受" in response.json()["reason"]
    reviews = await client.get("/api/v1/reviews", headers=auth_headers)
    assert len(reviews.json()) == 1
    assert reviews.json()[0]["id"] == response.json()["id"]


async def test_analyze_review_requires_authentication(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/reviews/analyze",
        json={
            "title": "测试",
            "source": "manual",
            "transcript": "这是一段需要分析的沟通内容。",
        },
    )

    assert response.status_code == 401
