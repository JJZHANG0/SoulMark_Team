import hashlib
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.challenge import ChallengeProgress, ChallengeReflection
from app.schemas.challenge import (
    ChallengeActionResponse,
    ChallengeDetail,
    ChallengeList,
    ChallengeStepResponse,
    ChallengeStepSubmission,
    ChallengeSummary,
)
from app.services import growth as growth_service
from app.services.challenge_catalog import (
    CHALLENGES,
    CHALLENGES_BY_KEY,
    DIMENSIONS,
    MODELS,
    Challenge,
)


def _in_distress(text: str) -> bool:
    from app.services.self_page import looks_in_distress

    return looks_in_distress(text)


def get_challenge(key: str) -> Challenge:
    challenge = CHALLENGES_BY_KEY.get(key)
    if challenge is None:
        raise AppError("challenge_not_found", "没有找到这个挑战。", 404)
    return challenge


async def _progress_map(session: AsyncSession, owner_id: UUID) -> dict[str, ChallengeProgress]:
    rows = await session.scalars(
        select(ChallengeProgress).where(ChallengeProgress.owner_id == owner_id)
    )
    return {row.challenge_key: row for row in rows}


async def _progress(session: AsyncSession, owner_id: UUID, key: str) -> ChallengeProgress | None:
    return await session.scalar(
        select(ChallengeProgress).where(
            ChallengeProgress.owner_id == owner_id, ChallengeProgress.challenge_key == key
        )
    )


def _summary_fields(challenge: Challenge, progress: ChallengeProgress | None) -> dict:
    return dict(
        key=challenge.key,
        title=challenge.title,
        subtitle=challenge.subtitle,
        model=challenge.model,
        model_title=MODELS[challenge.model],
        dimension=challenge.dimension,
        dimension_title=DIMENSIONS[challenge.dimension],
        icon=challenge.icon,
        duration_minutes=challenge.duration_minutes,
        span_days=challenge.span_days,
        step_count=len(challenge.steps),
        reward_experience=challenge.reward_experience,
        status=progress.status if progress else "not_started",
        completed_steps=progress.completed_steps if progress else 0,
        completion_count=progress.completion_count if progress else 0,
        started_at=progress.started_at if progress else None,
        completed_at=progress.completed_at if progress else None,
    )


async def _detail(
    session: AsyncSession,
    owner_id: UUID,
    challenge: Challenge,
    progress: ChallengeProgress | None,
) -> ChallengeDetail:
    from app.services.self_page import challenge_context
    answers: dict[int, ChallengeReflection] = {}
    if progress is not None:
        rows = await session.scalars(
            select(ChallengeReflection).where(ChallengeReflection.progress_id == progress.id)
        )
        answers = {row.step_index: row for row in rows}
    steps = [
        ChallengeStepResponse(
            index=index,
            title=step.title,
            instruction=step.instruction,
            prompt=step.prompt,
            kind=step.kind,
            min_chars=step.min_chars,
            response=answers[index].response if index in answers else None,
            rating=answers[index].rating if index in answers else None,
        )
        for index, step in enumerate(challenge.steps)
    ]
    return ChallengeDetail(
        **_summary_fields(challenge, progress),
        intro=challenge.intro,
        completion_rule=challenge.completion_rule,
        steps=steps,
        context_notes=await challenge_context(session, owner_id, challenge.key),
    )


async def list_challenges(session: AsyncSession, owner_id: UUID) -> ChallengeList:
    progress = await _progress_map(session, owner_id)
    items = [ChallengeSummary(**_summary_fields(c, progress.get(c.key))) for c in CHALLENGES]
    return ChallengeList(
        challenges=items,
        active_count=sum(1 for item in items if item.status == "active"),
        completed_count=sum(1 for item in items if item.completion_count > 0),
    )


async def challenge_detail(session: AsyncSession, owner_id: UUID, key: str) -> ChallengeDetail:
    challenge = get_challenge(key)
    return await _detail(session, owner_id, challenge, await _progress(session, owner_id, key))


async def start_challenge(session: AsyncSession, owner_id: UUID, key: str) -> ChallengeDetail:
    challenge = get_challenge(key)
    progress = await _progress(session, owner_id, key)
    now = growth_service.utc_now()
    if progress is None:
        progress = ChallengeProgress(
            owner_id=owner_id, challenge_key=key, status="active", started_at=now, updated_at=now
        )
        session.add(progress)
    elif progress.status == "completed":
        await session.execute(
            delete(ChallengeReflection).where(ChallengeReflection.progress_id == progress.id)
        )
        progress.status = "active"
        progress.completed_steps = 0
        progress.started_at = now
        progress.completed_at = None
    await session.flush()
    result = await _detail(session, owner_id, challenge, progress)
    await session.commit()
    return result


@growth_service.retry_locked_transaction
async def _complete(
    session: AsyncSession, owner_id: UUID, challenge: Challenge, progress: ChallengeProgress
) -> ChallengeActionResponse:
    now = growth_service.utc_now()
    state = await growth_service.lock_growth(session, owner_id, now)
    decayed = await growth_service.settle_decay(session, state, now)
    growth_service.mark_active(state, now)
    progress = await session.get(ChallengeProgress, progress.id, populate_existing=True)
    assert progress is not None
    awarded = 0
    if progress.status != "completed":
        first_time = progress.completion_count == 0
        progress.status = "completed"
        progress.completion_count += 1
        progress.completed_at = now
        if first_time:
            event_key = f"challenge:{challenge.key}"
            awarded = await growth_service.award_experience(
                session,
                state,
                event_key,
                "challenge",
                challenge.reward_experience,
                now,
                progress.id,
                hashlib.sha256(event_key.encode()).hexdigest(),
            )
    snapshot = await growth_service.growth_snapshot(session, state, now, decayed)
    detail = await _detail(session, owner_id, challenge, progress)
    await session.commit()
    return ChallengeActionResponse(challenge=detail, awarded_experience=awarded, growth=snapshot)


async def submit_step(
    session: AsyncSession,
    owner_id: UUID,
    key: str,
    index: int,
    payload: ChallengeStepSubmission,
) -> ChallengeActionResponse:
    challenge = get_challenge(key)
    progress = await _progress(session, owner_id, key)
    if progress is None or progress.status != "active":
        raise AppError("challenge_not_active", "请先开始这个挑战。", 409)
    if index < 0 or index >= len(challenge.steps):
        raise AppError("challenge_step_not_found", "没有这一步。", 404)
    if index > progress.completed_steps:
        raise AppError("challenge_step_locked", "请先完成前面的步骤。", 409)
    step = challenge.steps[index]
    text = payload.response.strip()
    if (
        step.kind != "rating"
        and text
        and not payload.continue_anyway
        and _in_distress(text)
    ):
        raise AppError("distress_check", "你现在还好吗", 409)
    if step.kind == "rating":
        if payload.rating is None:
            raise AppError("challenge_rating_required", "请选择 1–5 的分数。", 422)
    elif len(text) < step.min_chars:
        raise AppError(
            "challenge_reflection_too_short", f"再多写一点吧（至少 {step.min_chars} 个字）。", 422
        )
    reflection = await session.scalar(
        select(ChallengeReflection).where(
            ChallengeReflection.progress_id == progress.id,
            ChallengeReflection.step_index == index,
        )
    )
    if reflection is None:
        session.add(
            ChallengeReflection(
                progress_id=progress.id,
                owner_id=owner_id,
                step_index=index,
                response=text,
                rating=payload.rating,
            )
        )
        progress.completed_steps += 1
    else:
        reflection.response = text
        reflection.rating = payload.rating
    progress.updated_at = growth_service.utc_now()
    await session.commit()
    if progress.completed_steps >= len(challenge.steps):
        return await _complete(session, owner_id, challenge, progress)
    return ChallengeActionResponse(
        challenge=await _detail(session, owner_id, challenge, progress)
    )


async def complete_challenge(
    session: AsyncSession, owner_id: UUID, key: str
) -> ChallengeActionResponse:
    challenge = get_challenge(key)
    progress = await _progress(session, owner_id, key)
    if progress is None:
        raise AppError("challenge_not_active", "请先开始这个挑战。", 409)
    if progress.status != "completed" and progress.completed_steps < len(challenge.steps):
        raise AppError("challenge_incomplete", "还有步骤没有完成。", 409)
    return await _complete(session, owner_id, challenge, progress)
