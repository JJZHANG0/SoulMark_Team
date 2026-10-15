from collections import Counter
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.activity import ConversationReview, PracticeSession
from app.models.challenge import ChallengeProgress, ChallengeReflection
from app.models.contact import Contact
from app.models.user import User
from app.schemas.challenge import (
    RelationshipMix,
    ReportDimension,
    ReportHighlight,
    SelfAwarenessReport,
)
from app.services.challenge_catalog import CHALLENGES, CHALLENGES_BY_KEY, DIMENSIONS
from app.services.growth import get_growth

INSIGHTS: dict[str, tuple[str, str, str]] = {
    # (起步, 成长中, 稳定)
    "openness": (
        "试着让信任的人说说你，答案常在别人眼里。",
        "你开始主动邀请反馈，盲区正在变小。",
        "你愿意被看见，也敢于听见，这是很难得的开放。",
    ),
    "clarity": (
        "还没有梳理过自己的价值排序，可以从一次小练习开始。",
        "你对自己在意什么越来越清楚，选择也更笃定。",
        "你的价值与日常高度一致，内在有一根稳定的轴。",
    ),
    "emotion": (
        "给情绪起个准确的名字，是照顾它的第一步。",
        "你能更快察觉情绪，并留出回应的空间。",
        "你能稳稳地接住情绪，并把它转成清晰的表达。",
    ),
    "relation": (
        "关系是一面镜子，多看看不同关系里的自己。",
        "你在关系里逐渐看清自己的模式与需要。",
        "你在不同关系里都能保持真实，同时照顾彼此。",
    ),
}

STRENGTHS: dict[str, str] = {
    "openness": "愿意倾听反馈，乐于让别人走近",
    "clarity": "清楚自己在意什么，选择更有方向",
    "emotion": "能觉察并命名情绪，回应更从容",
    "relation": "在关系中保持真实，也懂得体察彼此",
}

EDGES: dict[str, str] = {
    "openness": "多一点自我暴露，也多问一句“你怎么看我”",
    "clarity": "把“应该”换成“我想要”，再做一次价值排序",
    "emotion": "被触发时先停六秒，让感受有名字再开口",
    "relation": "留意自己在不同人面前的变化，找到不变的部分",
}


def _clamp(value: float) -> int:
    return int(max(0, min(100, round(value))))


async def build_report(session: AsyncSession, user: User) -> SelfAwarenessReport:
    growth = await get_growth(session, user.id)
    progress_rows = list(
        (
            await session.scalars(
                select(ChallengeProgress).where(ChallengeProgress.owner_id == user.id)
            )
        ).all()
    )
    reflections = list(
        (
            await session.scalars(
                select(ChallengeReflection)
                .where(ChallengeReflection.owner_id == user.id)
                .order_by(ChallengeReflection.created_at.desc())
            )
        ).all()
    )
    contacts = list(
        (await session.scalars(select(Contact).where(Contact.owner_id == user.id))).all()
    )
    reviews_count, average_score = (
        await session.execute(
            select(func.count(ConversationReview.id), func.avg(ConversationReview.score)).where(
                ConversationReview.owner_id == user.id
            )
        )
    ).one()
    practices_count = int(
        await session.scalar(
            select(func.count(PracticeSession.id)).where(PracticeSession.owner_id == user.id)
        )
        or 0
    )
    average = float(average_score) if average_score is not None else None

    progress_by_id = {row.id: row for row in progress_rows}
    completed_keys = {row.challenge_key for row in progress_rows if row.completion_count > 0}
    dimensions: list[ReportDimension] = []
    for key, title in DIMENSIONS.items():
        dim_keys = {c.key for c in CHALLENGES if c.dimension == key}
        completed = len(dim_keys & completed_keys)
        dim_reflections = [
            r
            for r in reflections
            if (p := progress_by_id.get(r.progress_id)) is not None and p.challenge_key in dim_keys
        ]
        ratings = [r.rating for r in dim_reflections if r.rating is not None]
        score = 30 + 22 * completed + min(10, 2 * len(dim_reflections))
        if ratings:
            score += (sum(ratings) / len(ratings) - 3) * 5
        if key == "emotion" and average is not None:
            score += max(-10, min(10, (average - 50) / 5))
        if key == "relation":
            score += min(10, 2 * len(contacts))
        score = _clamp(score)
        tier = 0 if score < 50 else 1 if score < 75 else 2
        dimensions.append(
            ReportDimension(
                key=key,
                title=title,
                score=score,
                completed_challenges=completed,
                insight=INSIGHTS[key][tier],
            )
        )

    ranked = sorted(dimensions, key=lambda d: d.score, reverse=True)
    overall = _clamp(sum(d.score for d in dimensions) / len(dimensions))
    top, weakest = ranked[0], ranked[-1]
    if not completed_keys:
        headline = "认识自己的旅程，刚刚开始"
        summary = "完成一个自我觉察挑战，这份报告会长出属于你的洞察。"
    else:
        headline = f"你最亮的一面：{top.title}"
        summary = (
            f"你已完成 {len(completed_keys)} 个挑战、写下 {len(reflections)} 条反思。"
            f"在「{top.title}」上你走得最远，下一步可以多照顾「{weakest.title}」。"
        )

    next_steps: list[str] = []
    for dim in reversed(ranked):
        for challenge in CHALLENGES:
            if challenge.dimension == dim.key and challenge.key not in completed_keys:
                next_steps.append(f"挑战「{challenge.title}」：{challenge.subtitle}")
                break
        if len(next_steps) == 3:
            break
    if reviews_count == 0:
        next_steps.append("做一次沟通复盘，看看你的表达如何影响他人")

    highlights = [
        ReportHighlight(
            challenge_title=CHALLENGES_BY_KEY[p.challenge_key].title,
            step_title=CHALLENGES_BY_KEY[p.challenge_key].steps[r.step_index].title,
            response=r.response[:140],
            created_at=r.created_at,
        )
        for r in reflections
        if len(r.response) >= 8
        and (p := progress_by_id.get(r.progress_id)) is not None
        and p.challenge_key in CHALLENGES_BY_KEY
        and r.step_index < len(CHALLENGES_BY_KEY[p.challenge_key].steps)
    ][:3]

    mix = Counter((c.relationship_label or "其他").strip() or "其他" for c in contacts)
    return SelfAwarenessReport(
        generated_at=datetime.now(UTC),
        display_name=user.display_name or "Soul User",
        headline=headline,
        summary=summary,
        overall_score=overall,
        level=growth.level,
        title_key=growth.title_key,
        experience_balance=growth.balance,
        challenges_completed=len(completed_keys),
        challenges_active=sum(1 for row in progress_rows if row.status == "active"),
        reflections_count=len(reflections),
        reviews_count=int(reviews_count or 0),
        average_review_score=round(average, 1) if average is not None else None,
        practices_count=practices_count,
        contacts_count=len(contacts),
        dimensions=dimensions,
        strengths=[STRENGTHS[d.key] for d in ranked[:2] if d.score >= 50] or ["愿意开始认识自己"],
        growth_edges=[EDGES[d.key] for d in ranked[-2:]],
        next_steps=next_steps[:3],
        highlights=highlights,
        relationship_mix=[RelationshipMix(label=k, count=v) for k, v in mix.most_common(5)],
    )
