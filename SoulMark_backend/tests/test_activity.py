from httpx import AsyncClient
from pytest import MonkeyPatch

from app.ai.review import _normalize_analysis
from app.api.v1 import activity as activity_api
from app.schemas.activity import ReviewAnalysisResponse


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
    assert reviews.json()[0]["detailed_advice"] == "暂无详细建议。"
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
    assert (
        await client.post(
            "/api/v1/reviews/analyze",
            json={"source": "manual", "transcript": "一次沟通", "language": "zh"},
        )
    ).status_code == 401


async def test_review_analysis_returns_structured_qwen_result(
    client: AsyncClient,
    auth_headers: dict[str, str],
    monkeypatch: MonkeyPatch,
) -> None:
    async def fake_analysis(*args: object, **kwargs: object) -> ReviewAnalysisResponse:
        return ReviewAnalysisResponse(
            title="误会后的沟通",
            score=82,
            reason="用户表达了感受，但具体请求还不够清晰。",
            brief_advice="把期待改成一个明确、可回应的请求。",
            detailed_advice="先确认事实，再说明感受，最后提出具体请求。",
        )

    monkeypatch.setattr(activity_api, "analyze_review", fake_analysis)
    response = await client.post(
        "/api/v1/reviews/analyze",
        headers=auth_headers,
        json={
            "source": "wechat",
            "transcript": "我有点难过，希望你下次提前告诉我。",
            "language": "zh",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "title": "误会后的沟通",
        "score": 82,
        "reason": "用户表达了感受，但具体请求还不够清晰。",
        "brief_advice": "把期待改成一个明确、可回应的请求。",
        "detailed_advice": "先确认事实，再说明感受，最后提出具体请求。",
        "transcript": None,
    }


def test_review_analysis_normalizes_structured_advice_sections() -> None:
    normalized = _normalize_analysis(
        {
            "title": "一次沟通",
            "score": 82,
            "reason": "表达了感受。",
            "brief_advice": ["说明需要", "提出请求"],
            "detailed_advice": {
                "做得好的地方": ["先陈述事实", "愿意倾听"],
                "下次可以这样说": "我希望我们可以先确认彼此的理解。",
            },
        }
    )

    assert normalized["brief_advice"] == "• 说明需要\n• 提出请求"
    assert normalized["detailed_advice"] == (
        "做得好的地方\n• 先陈述事实\n• 愿意倾听\n\n"
        "下次可以这样说\n我希望我们可以先确认彼此的理解。"
    )


async def test_review_media_analysis_accepts_chat_image(
    client: AsyncClient,
    auth_headers: dict[str, str],
    monkeypatch: MonkeyPatch,
) -> None:
    async def fake_media_analysis(*args: object, **kwargs: object) -> ReviewAnalysisResponse:
        return ReviewAnalysisResponse(
            title="截图沟通复盘",
            score=78,
            reason="表达了立场，但回应较急。",
            brief_advice="先确认对方的感受。",
            detailed_advice="先复述对方的重点，再说明自己的需要。",
            transcript="我：我们需要谈谈。\n对方：好的。",
        )

    monkeypatch.setattr(activity_api, "analyze_review_media", fake_media_analysis)
    response = await client.post(
        "/api/v1/reviews/analyze-media",
        headers=auth_headers,
        data={"source": "wechat", "language": "zh"},
        files={"file": ("chat.jpg", b"fake-image", "image/jpeg")},
    )

    assert response.status_code == 200
    assert response.json()["transcript"] == "我：我们需要谈谈。\n对方：好的。"


async def test_review_delete_persists(
    client: AsyncClient,
    auth_headers: dict[str, str],
) -> None:
    created = await client.post(
        "/api/v1/reviews",
        headers=auth_headers,
        json={
            "title": "需要删除的复盘",
            "source": "manual",
            "transcript": "一次沟通",
            "score": 70,
            "reason": "原因",
            "advice": "建议",
            "detailed_advice": "详细建议",
        },
    )

    deleted = await client.delete(
        f"/api/v1/reviews/{created.json()['id']}",
        headers=auth_headers,
    )

    assert deleted.status_code == 204
    assert (await client.get("/api/v1/reviews", headers=auth_headers)).json() == []


async def test_review_ai_memory_contains_only_current_users_relationships(
    client: AsyncClient,
    auth_headers: dict[str, str],
    monkeypatch: MonkeyPatch,
) -> None:
    contact = await client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={
            "name": "Lin",
            "relationship_label": "仇人",
            "notes": "关系紧张",
            "strength": 10,
        },
    )
    await client.post(
        f"/api/v1/contacts/{contact.json()['id']}/events",
        headers=auth_headers,
        json={
            "title": "去年表白",
            "details": "我在公园向她表白。",
            "occurred_at": "2025-03-01T10:00:00Z",
        },
    )
    await client.post(
        "/api/v1/auth/register",
        json={
            "email": "memory-other@example.com",
            "password": "StrongPass123!",
            "display_name": "Other",
        },
    )
    other_login = await client.post(
        "/api/v1/auth/login",
        json={"email": "memory-other@example.com", "password": "StrongPass123!"},
    )
    other_headers = {
        "Authorization": f"Bearer {other_login.json()['access_token']}"
    }
    await client.post(
        "/api/v1/contacts",
        headers=other_headers,
        json={
            "name": "Private Other Contact",
            "relationship_label": "秘密",
            "notes": "不属于当前用户",
            "strength": 50,
        },
    )

    captured: dict[str, str] = {}

    async def fake_analysis(
        payload: object, settings: object, memory_context: str
    ) -> ReviewAnalysisResponse:
        captured["memory"] = memory_context
        return ReviewAnalysisResponse(
            title="一次复盘",
            score=80,
            reason="原因",
            brief_advice="建议",
            detailed_advice="详细建议",
        )

    monkeypatch.setattr(activity_api, "analyze_review", fake_analysis)
    response = await client.post(
        "/api/v1/reviews/analyze",
        headers=auth_headers,
        json={"source": "manual", "transcript": "一次沟通", "language": "zh"},
    )

    assert response.status_code == 200
    assert "Lin" in captured["memory"]
    assert "仇人" in captured["memory"]
    assert "去年表白" in captured["memory"]
    assert "我在公园向她表白" in captured["memory"]
    assert "Private Other Contact" not in captured["memory"]
