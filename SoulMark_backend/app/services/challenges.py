import hashlib
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.review import draft_challenge_keep
from app.core.config import get_settings
from app.core.errors import AppError
from app.models.challenge import ChallengeProgress, ChallengeReflection
from app.schemas.challenge import (
    ChallengeActionResponse,
    ChallengeDetail,
    ChallengeKeepDraft,
    ChallengeList,
    ChallengeStepResponse,
    ChallengeStepSubmission,
    ChallengeSummary,
)
from app.schemas.self_page import EvidenceOut
from app.services import growth as growth_service
from app.services.challenge_catalog import (
    CHALLENGES,
    CHALLENGES_BY_KEY,
    DIMENSIONS,
    MODELS,
    Challenge,
    ChallengeStep,
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


async def _written_rows(
    session: AsyncSession, progress: ChallengeProgress, challenge: Challenge
) -> list[tuple[ChallengeStep, ChallengeReflection]]:
    rows = await session.scalars(
        select(ChallengeReflection).where(ChallengeReflection.progress_id == progress.id)
    )
    by_index = {row.step_index: row for row in rows}
    written: list[tuple[ChallengeStep, ChallengeReflection]] = []
    for index, step in enumerate(challenge.steps):
        if step.kind == "rating":
            continue
        row = by_index.get(index)
        if row is None or not row.response.strip():
            continue
        written.append((step, row))
    return written


async def _offer_keep(
    session: AsyncSession, owner_id: UUID, challenge: Challenge
) -> ChallengeKeepDraft | None:
    """One model call after completion. Distress and a bad excerpt produce no draft."""
    progress = await _progress(session, owner_id, challenge.key)
    if progress is None:
        return None
    written = await _written_rows(session, progress, challenge)
    if not written:
        return None
    combined = "\n".join(row.response.strip() for _, row in written)
    if _in_distress(combined):
        return None
    answers = [(step.title, row.response.strip()) for step, row in written]
    try:
        sentence, question = await draft_challenge_keep(challenge.title, answers, get_settings())
    except AppError:
        return None
    sentence = sentence.strip()
    question = question.strip()
    if not sentence or not question:
        return None
    matched = next(((step, row) for step, row in written if sentence in row.response), None)
    if matched is None:
        return None
    step, row = matched
    return ChallengeKeepDraft(
        sentence=sentence,
        question=question,
        reflection_id=row.id,
        detail=step.title,
    )


async def _with_keep(
    session: AsyncSession,
    owner_id: UUID,
    challenge: Challenge,
    result: ChallengeActionResponse,
) -> ChallengeActionResponse:
    keep = await _offer_keep(session, owner_id, challenge)
    if keep is None:
        return result
    return result.model_copy(update={"keep": keep})


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
    finished = progress.completed_steps >= len(challenge.steps)
    await session.commit()
    if finished:
        result = await _complete(session, owner_id, challenge, progress)
        return await _with_keep(session, owner_id, challenge, result)
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
    fresh = progress.status != "completed"
    result = await _complete(session, owner_id, challenge, progress)
    if not fresh:
        return result
    return await _with_keep(session, owner_id, challenge, result)


async def confirm_keep(
    session: AsyncSession,
    owner_id: UUID,
    key: str,
    reflection_id: UUID,
    sentence: str,
) -> EvidenceOut:
    """Store the kept sentence. Reflections and the eight cells stay as they were."""
    from app.services.self_page import keep_challenge_quote

    challenge = get_challenge(key)
    reflection = await session.get(ChallengeReflection, reflection_id)
    if reflection is None or reflection.owner_id != owner_id:
        raise AppError("evidence_source_not_found", "找不到这句原话。", 404)
    progress = await session.get(ChallengeProgress, reflection.progress_id)
    if progress is None or progress.owner_id != owner_id or progress.challenge_key != key:
        raise AppError("evidence_source_not_found", "找不到这句原话。", 404)
    if reflection.step_index < 0 or reflection.step_index >= len(challenge.steps):
        raise AppError("challenge_step_not_found", "没有这一步。", 404)
    step = challenge.steps[reflection.step_index]
    if step.kind == "rating":
        raise AppError("evidence_not_a_quote", "原话要来自你写下的回答。", 422)
    return await keep_challenge_quote(session, owner_id, reflection, sentence, step.title)
