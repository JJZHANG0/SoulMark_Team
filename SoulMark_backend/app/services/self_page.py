"""Weekly self page: read-only draft, then confirm, then coverage.

Quotes come from challenge responses, practice user transcripts, review lines the
user marks, or a sentence the user dates themselves. Model analysis is not a quote.
"""

from collections import Counter
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.activity import ConversationReview, PracticeSession
from app.models.challenge import ChallengeProgress, ChallengeReflection
from app.models.contact import Contact, ContactEvent
from app.models.self_page import SelfEvidence, SelfPage
from app.models.user import User, utc_now
from app.schemas.self_page import (
    Bookkeeping,
    ConfirmCellRequest,
    DraftCandidate,
    EvidenceIn,
    EvidenceOut,
    PageCell,
    SelfAwarenessReport,
)
from app.services.growth import ZONE

SLOTS: tuple[str, ...] = (
    "who",
    "pursuit",
    "fear",
    "pattern_1",
    "pattern_2",
    "pattern_3",
    "blind_spot",
    "weekly_step",
)
PATTERN_SLOTS = frozenset({"pattern_1", "pattern_2", "pattern_3"})
TITLES: dict[str, str] = {
    "who": "我是谁",
    "pursuit": "在追",
    "fear": "在怕",
    "pattern_1": "模式",
    "pattern_2": "模式",
    "pattern_3": "模式",
    "blind_spot": "盲区",
    "weekly_step": "本周一步",
}
QUOTE_SOURCES = frozenset(
    {"challenge_reflection", "practice_session", "review_line", "user_note", "contact_event"}
)
DISTRESS_PHRASES = (
    "不想活",
    "想死",
    "自杀",
    "活不下去",
    "不想活了",
    "结束生命",
    "伤害自己",
    "割腕",
    "没有活着的意义",
    "活着没意思",
    "kill myself",
    "want to die",
    "suicide",
    "end my life",
    "hurt myself",
    "self-harm",
    "self harm",
    "don't want to live",
    "do not want to live",
)


@dataclass
class VerifiedEvidence:
    source_type: str
    source_id: UUID | None
    quote: str
    detail: str
    occurred_on: date
    challenge_key: str | None = None
    step_index: int | None = None


@dataclass
class ReflectionRow:
    reflection: ChallengeReflection
    progress: ChallengeProgress


def looks_in_distress(text: str) -> bool:
    folded = " ".join(text.casefold().split())
    return any(phrase in folded for phrase in DISTRESS_PHRASES)


def singapore_today(now: datetime | None = None) -> date:
    current = now or datetime.now(UTC)
    if current.tzinfo is None:
        current = current.replace(tzinfo=UTC)
    return current.astimezone(ZONE).date()


def week_start_on(day: date) -> date:
    return day - timedelta(days=day.weekday())


def _sg_date(moment: datetime) -> date:
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=UTC)
    return moment.astimezone(ZONE).date()


def _cell_text(page: SelfPage | None, slot: str) -> str:
    if page is None:
        return ""
    raw = getattr(page, f"{slot}_text", None)
    return raw.strip() if isinstance(raw, str) else ""


def _set_cell_text(page: SelfPage, slot: str, text: str | None) -> None:
    setattr(page, f"{slot}_text", text)


def _qualified(rows: list[SelfEvidence], slot: str) -> list[SelfEvidence]:
    return [
        row
        for row in rows
        if row.slot == slot and row.confirmed and row.quote.strip() and row.detail.strip()
    ]


def _covered(slot: str, text: str, rows: list[SelfEvidence]) -> bool:
    if not text.strip():
        return False
    count = len(_qualified(rows, slot))
    if slot in PATTERN_SLOTS:
        return count >= 2
    return count >= 1


def _candidate(
    slot: str,
    source_type: str,
    source_id: UUID | None,
    quote: str,
    detail: str,
    occurred_on: date | None,
    prompt: str,
    ready: bool,
) -> DraftCandidate:
    return DraftCandidate(
        slot=slot,
        source_type=source_type,
        source_id=source_id,
        quote=quote.strip(),
        detail=detail.strip(),
        occurred_on=occurred_on,
        prompt=prompt,
        ready=ready and bool(quote.strip()) and occurred_on is not None and bool(detail.strip()),
    )


async def _reflections(session: AsyncSession, owner_id: UUID) -> list[ReflectionRow]:
    result = await session.execute(
        select(ChallengeReflection, ChallengeProgress)
        .join(ChallengeProgress, ChallengeReflection.progress_id == ChallengeProgress.id)
        .where(ChallengeReflection.owner_id == owner_id)
    )
    return [
        ReflectionRow(reflection=reflection, progress=progress)
        for reflection, progress in result.all()
    ]


def _find(
    rows: list[ReflectionRow], key: str, step_index: int
) -> ReflectionRow | None:
    for row in rows:
        if row.progress.challenge_key == key and row.reflection.step_index == step_index:
            if row.reflection.response.strip():
                return row
    return None


async def _page(session: AsyncSession, owner_id: UUID, start: date) -> SelfPage | None:
    return await session.scalar(
        select(SelfPage).where(SelfPage.owner_id == owner_id, SelfPage.week_start == start)
    )


async def _ensure_page(session: AsyncSession, owner_id: UUID, start: date) -> SelfPage:
    page = await _page(session, owner_id, start)
    if page is not None:
        return page
    now = utc_now()
    page = SelfPage(
        owner_id=owner_id,
        week_start=start,
        created_at=now,
        updated_at=now,
    )
    session.add(page)
    await session.flush()
    return page


async def _evidence(session: AsyncSession, page_id: UUID) -> list[SelfEvidence]:
    rows = await session.scalars(select(SelfEvidence).where(SelfEvidence.page_id == page_id))
    return list(rows.all())


def _draft(
    reflections: list[ReflectionRow],
    practices: list[PracticeSession],
    reviews: list[ConversationReview],
    events: list[ContactEvent],
    pool: list[SelfEvidence],
    today: date,
) -> list[DraftCandidate]:
    items: list[DraftCandidate] = []
    stable = _find(reflections, "self_concept_ten", 1)
    if stable is not None:
        items.append(
            _candidate(
                "who",
                "challenge_reflection",
                stable.reflection.id,
                stable.reflection.response,
                "十个「我是」里标成最稳定的那句",
                _sg_date(stable.reflection.created_at),
                "这是你写下的底色。可以改一句再确认。没有这句，我是谁留空。",
                True,
            )
        )
    values = _find(reflections, "values_compass", 1)
    if values is not None:
        items.append(
            _candidate(
                "who",
                "challenge_reflection",
                values.reflection.id,
                values.reflection.response,
                "价值指南针留下的三个词",
                _sg_date(values.reflection.created_at),
                "这是你留下的词。它不能代替那句稳定的「我是」。",
                True,
            )
        )
    for step_index, detail in ((0, "日常里怎么描述自己"), (1, "希望被看成什么样")):
        seen = _find(reflections, "how_i_want_to_be_seen", step_index)
        if seen is not None:
            items.append(
                _candidate(
                    "who",
                    "challenge_reflection",
                    seen.reflection.id,
                    seen.reflection.response,
                    detail,
                    _sg_date(seen.reflection.created_at),
                    "这是你自己写的。确认之前，这一格仍是空的。",
                    True,
                )
            )

    pursuit_sources = (
        ("awareness_wheel", 3, "觉察之轮里写下的「我想要」"),
        ("emotion_naming", 2, "情绪命名第三天写下的需要"),
        ("values_compass", 2, "价值指南针里那次真实选择"),
    )
    for key, step_index, detail in pursuit_sources:
        row = _find(reflections, key, step_index)
        if row is None:
            continue
        written = _sg_date(row.reflection.created_at).isoformat()
        quote = row.reflection.response.strip()
        prompt = f"你在 {written} 写过「{quote}」。这是在追它，还是在挡开什么？"
        for slot in ("pursuit", "fear"):
            items.append(
                _candidate(
                    slot,
                    "challenge_reflection",
                    row.reflection.id,
                    quote,
                    detail,
                    _sg_date(row.reflection.created_at),
                    prompt,
                    True,
                )
            )

    pattern_sources = (
        ("six_second_pause", 0, "暂停六秒里记下的那件事"),
        ("awareness_wheel", 0, "觉察之轮里的事实"),
        ("emotion_naming", 0, "情绪命名第一天的事"),
        ("emotion_naming", 1, "情绪命名第二天的事"),
        ("emotion_naming", 2, "情绪命名第三天的事"),
    )
    for key, step_index, detail in pattern_sources:
        row = _find(reflections, key, step_index)
        if row is None:
            continue
        items.append(
            _candidate(
                "pattern",
                "challenge_reflection",
                row.reflection.id,
                row.reflection.response,
                detail,
                _sg_date(row.reflection.created_at),
                "这是一条有日期的材料。模式要你自己命名，并勾上两到三条。",
                True,
            )
        )
    for practice in practices:
        quote = practice.user_transcript.strip()
        if not quote:
            continue
        items.append(
            _candidate(
                "pattern",
                "practice_session",
                practice.id,
                quote,
                f"练习 {practice.participant_name} · {practice.mode_title}",
                _sg_date(practice.created_at),
                "这是你当时说的话，不是对方的话。",
                True,
            )
        )
    for review in reviews:
        items.append(
            _candidate(
                "pattern",
                "review_line",
                review.id,
                "",
                review.title,
                _sg_date(review.created_at),
                "复盘标题和日期可以当细节。原话要在详情里点「这句是我说的」。",
                False,
            )
        )
    for event in events:
        items.append(
            _candidate(
                "pattern",
                "contact_event",
                event.id,
                "",
                f"{event.title} {event.details}".strip(),
                _sg_date(event.occurred_at),
                "这是一件有日期的事。原话需要你补上，或从挑战、练习、复盘里指认。",
                False,
            )
        )
    blind = _find(reflections, "johari_blind_spot", 1)
    if blind is not None:
        items.append(
            _candidate(
                "blind_spot",
                "challenge_reflection",
                blind.reflection.id,
                blind.reflection.response,
                "盲区来信里记下的对方原话",
                _sg_date(blind.reflection.created_at),
                "这是对方的原话。选定最大的一处差距再确认。没有你自己的那句「我是」，这一格留空。",
                True,
            )
        )
    horizon = today - timedelta(days=30)
    for event in events:
        occurred = _sg_date(event.occurred_at)
        if occurred < horizon:
            continue
        items.append(
            _candidate(
                "weekly_step",
                "contact_event",
                event.id,
                "",
                f"{event.title} {event.details}".strip(),
                occurred,
                "近 30 天的事。选定后还要配一句你的话，并已有一个确认过的模式。",
                False,
            )
        )
    for review in reviews:
        occurred = _sg_date(review.created_at)
        if occurred < horizon:
            continue
        items.append(
            _candidate(
                "weekly_step",
                "review_line",
                review.id,
                "",
                review.title,
                occurred,
                "近 30 天的复盘。先点出你自己的一句，再决定它是不是本周这一步。",
                False,
            )
        )
    action = _find(reflections, "awareness_wheel", 4)
    if action is not None:
        items.append(
            _candidate(
                "weekly_step",
                "challenge_reflection",
                action.reflection.id,
                action.reflection.response,
                "觉察之轮最后一步的「我会做」",
                _sg_date(action.reflection.created_at),
                "这是候选句子。是否当作本周这一步，由你定。没有已确认的模式或近事，这一格留空。",
                True,
            )
        )
    for picked in pool:
        items.append(
            _candidate(
                "marked",
                picked.source_type,
                picked.source_id,
                picked.quote,
                picked.detail,
                picked.occurred_on,
                "这是你在复盘里指认的自己的句子。",
                True,
            )
        )
    return items


def _missing(
    slot: str,
    covered: bool,
    draft: list[DraftCandidate],
    rows: list[SelfEvidence],
    pattern_covered: bool,
    has_recent: bool,
    has_self_sentence: bool,
) -> list[str]:
    if covered:
        return []
    if slot in PATTERN_SLOTS:
        ready = [item for item in draft if item.slot == "pattern" and item.ready]
        confirmed = _qualified(rows, slot)
        missing: list[str] = []
        if not ready and not confirmed:
            missing.append("原话")
        if len(confirmed) < 2 and len(ready) < 2:
            missing.append("第二条例子")
        elif len(confirmed) < 2:
            missing.append("第二条例子")
        return missing or ["原话"]
    if slot == "weekly_step":
        missing = []
        if not pattern_covered:
            missing.append("已确认的模式")
        if not has_recent:
            missing.append("近事")
        if not any(item.slot == "weekly_step" and item.ready for item in draft):
            missing.append("原话")
        return missing or ["原话"]
    if slot == "blind_spot":
        missing = []
        if not any(item.slot == "blind_spot" and item.ready for item in draft):
            missing.append("原话")
        if not has_self_sentence:
            missing.append("原话")
        return missing or ["原话"]
    if not any(item.slot == slot and item.ready for item in draft):
        return ["原话"]
    return ["原话"]


def _cells(
    page: SelfPage | None,
    rows: list[SelfEvidence],
    draft: list[DraftCandidate],
    today: date,
) -> list[PageCell]:
    pattern_covered = any(
        _covered(slot, _cell_text(page, slot), rows) for slot in PATTERN_SLOTS
    )
    horizon = today - timedelta(days=30)
    has_recent = any(
        item.slot == "weekly_step" and item.occurred_on is not None and item.occurred_on >= horizon
        for item in draft
    ) or any(
        row.slot == "weekly_step"
        and row.confirmed
        and row.source_type in {"contact_event", "review_line"}
        and row.occurred_on >= horizon
        for row in rows
    )
    has_self = _covered("who", _cell_text(page, "who"), rows) or any(
        item.slot == "who" and item.ready and item.detail.startswith("十个")
        for item in draft
    )
    cells: list[PageCell] = []
    for slot in SLOTS:
        stored = _cell_text(page, slot)
        covered = _covered(slot, stored, rows)
        cells.append(
            PageCell(
                slot=slot,
                title=TITLES[slot],
                text=stored if covered else "",
                covered=covered,
                missing=_missing(
                    slot, covered, draft, rows, pattern_covered, has_recent, has_self
                ),
            )
        )
    return cells


async def build_report(session: AsyncSession, user: User) -> SelfAwarenessReport:
    today = singapore_today()
    start = week_start_on(today)
    page = await _page(session, user.id, start)
    rows = await _evidence(session, page.id) if page is not None else []
    reflections = await _reflections(session, user.id)
    contacts = list(
        (await session.scalars(select(Contact).where(Contact.owner_id == user.id))).all()
    )
    events = list(
        (
            await session.scalars(
                select(ContactEvent)
                .where(ContactEvent.owner_id == user.id)
                .order_by(ContactEvent.occurred_at.desc())
            )
        ).all()
    )
    reviews = list(
        (
            await session.scalars(
                select(ConversationReview)
                .where(ConversationReview.owner_id == user.id)
                .order_by(ConversationReview.created_at.desc())
            )
        ).all()
    )
    practices = list(
        (
            await session.scalars(
                select(PracticeSession).where(PracticeSession.owner_id == user.id)
            )
        ).all()
    )
    pool = [row for row in rows if row.slot == "pool" and not row.confirmed]
    draft = _draft(reflections, practices, reviews, events, pool, today)
    cells = _cells(page, rows, draft, today)
    return SelfAwarenessReport(
        generated_at=utc_now(),
        week_start=start,
        paused_at=page.paused_at if page is not None else None,
        evidence_covered=sum(1 for cell in cells if cell.covered),
        evidence_total=len(SLOTS),
        weekly_step_done=bool(page and page.weekly_step_completed_at and _covered(
            "weekly_step", _cell_text(page, "weekly_step"), rows
        )),
        weekly_step_completed_at=page.weekly_step_completed_at if page is not None else None,
        cells=cells,
        draft=draft,
        bookkeeping=Bookkeeping(
            contacts_count=len(contacts),
            events_count=len(events),
            reviews_count=len(reviews),
            practices_count=len(practices),
        ),
    )


def _require_slot(slot: str) -> str:
    if slot not in SLOTS:
        raise AppError("self_page_slot_unknown", "没有这一格。", 404)
    return slot


async def _verify(
    session: AsyncSession, owner_id: UUID, item: EvidenceIn
) -> VerifiedEvidence:
    if item.source_type not in QUOTE_SOURCES:
        raise AppError("evidence_source_rejected", "这种材料不能当原话。", 422)
    quote = item.quote.strip()
    detail = item.detail.strip()
    if item.source_type == "user_note":
        if item.occurred_on is None:
            raise AppError("evidence_date_required", "补上的这句话要有日期。", 422)
        if not detail:
            raise AppError("evidence_detail_required", "还缺一个具体细节。", 422)
        return VerifiedEvidence("user_note", None, quote, detail, item.occurred_on)
    if item.source_id is None:
        raise AppError("evidence_source_required", "找不到这句原话。", 422)

    if item.source_type == "challenge_reflection":
        reflection = await session.get(ChallengeReflection, item.source_id)
        if reflection is None or reflection.owner_id != owner_id:
            raise AppError("evidence_source_not_found", "找不到这句原话。", 404)
        if quote not in reflection.response:
            raise AppError("evidence_not_a_quote", "原话要来自你写下的回答。", 422)
        if not detail:
            raise AppError("evidence_detail_required", "还缺一个具体细节。", 422)
        progress = await session.get(ChallengeProgress, reflection.progress_id)
        return VerifiedEvidence(
            "challenge_reflection",
            reflection.id,
            quote,
            detail,
            _sg_date(reflection.created_at),
            progress.challenge_key if progress is not None else None,
            reflection.step_index,
        )

    if item.source_type == "practice_session":
        practice = await session.get(PracticeSession, item.source_id)
        if practice is None or practice.owner_id != owner_id:
            raise AppError("evidence_source_not_found", "找不到这次练习。", 404)
        if quote not in practice.user_transcript:
            raise AppError("evidence_not_a_quote", "原话只取你自己说的那一段。", 422)
        if not detail:
            detail = f"练习 {practice.participant_name}"
        return VerifiedEvidence(
            "practice_session",
            practice.id,
            quote,
            detail,
            _sg_date(practice.created_at),
        )

    if item.source_type == "review_line":
        review = await session.get(ConversationReview, item.source_id)
        if review is None or review.owner_id != owner_id:
            raise AppError("evidence_source_not_found", "找不到这条复盘。", 404)
        if quote not in review.transcript:
            raise AppError("evidence_not_a_quote", "这一句不在复盘原文里。", 422)
        return VerifiedEvidence(
            "review_line",
            review.id,
            quote,
            detail or review.title,
            _sg_date(review.created_at),
        )

    event = await session.get(ContactEvent, item.source_id)
    if event is None or event.owner_id != owner_id:
        raise AppError("evidence_source_not_found", "找不到这件事。", 404)
    explanation = (event.impact_explanation or "").strip()
    if explanation and quote == explanation:
        raise AppError("evidence_not_a_quote", "这一句是分析，不能当原话。", 422)
    return VerifiedEvidence(
        "contact_event",
        event.id,
        quote,
        f"{event.title} {event.details}".strip(),
        _sg_date(event.occurred_at),
    )


def _guard_slot(
    slot: str,
    verified: list[VerifiedEvidence],
    page: SelfPage | None,
    rows: list[SelfEvidence],
    today: date,
) -> None:
    if slot in PATTERN_SLOTS and not 2 <= len(verified) <= 3:
        raise AppError("self_page_not_ready", "这个模式要有两到三条有日期的例子。", 422)
    if slot not in PATTERN_SLOTS and not verified:
        raise AppError("self_page_not_ready", "这一格还没有原话。", 422)
    if slot == "who" and not any(
        item.challenge_key == "self_concept_ten" and item.step_index == 1 for item in verified
    ):
        raise AppError("self_page_not_ready", "没有稳定的「我是」原话，这一格留空。", 422)
    if slot == "blind_spot":
        who_rows = rows
        if not _covered("who", _cell_text(page, "who"), who_rows):
            raise AppError("self_page_not_ready", "没有自己的那句，盲区留空。", 422)
        if not any(
            item.challenge_key == "johari_blind_spot" and item.step_index == 1 for item in verified
        ):
            raise AppError("self_page_not_ready", "没有对方原话，盲区留空。", 422)
    if slot == "weekly_step":
        patterns = [
            pattern
            for pattern in PATTERN_SLOTS
            if _covered(pattern, _cell_text(page, pattern), rows)
        ]
        if not patterns:
            raise AppError("self_page_not_ready", "没有已确认的模式，这一格留空。", 422)
        horizon = today - timedelta(days=30)
        recent = [
            item
            for item in verified
            if item.source_type in {"contact_event", "review_line"} and item.occurred_on >= horizon
        ]
        if not recent:
            raise AppError("self_page_not_ready", "没有选定的近事，这一格留空。", 422)


async def confirm_cell(
    session: AsyncSession, user: User, payload: ConfirmCellRequest
) -> SelfAwarenessReport:
    slot = _require_slot(payload.slot)
    text = payload.text.strip()
    combined = "\n".join([text, *[item.quote for item in payload.evidence]])
    if text and not payload.continue_anyway and looks_in_distress(combined):
        raise AppError("distress_check", "你现在还好吗", 409)

    today = singapore_today()
    start = week_start_on(today)
    existing = await _page(session, user.id, start)
    rows = await _evidence(session, existing.id) if existing is not None else []

    if not text:
        if existing is not None:
            _set_cell_text(existing, slot, None)
            if slot == "weekly_step":
                existing.weekly_step_completed_at = None
            await session.execute(
                delete(SelfEvidence).where(
                    SelfEvidence.page_id == existing.id, SelfEvidence.slot == slot
                )
            )
            existing.updated_at = utc_now()
            await session.commit()
        return await build_report(session, user)

    verified = [await _verify(session, user.id, item) for item in payload.evidence]
    _guard_slot(slot, verified, existing, rows, today)
    page = existing or await _ensure_page(session, user.id, start)
    await session.execute(
        delete(SelfEvidence).where(SelfEvidence.page_id == page.id, SelfEvidence.slot == slot)
    )
    for item in verified:
        session.add(
            SelfEvidence(
                page_id=page.id,
                owner_id=user.id,
                slot=slot,
                source_type=item.source_type,
                source_id=item.source_id,
                quote=item.quote,
                detail=item.detail,
                occurred_on=item.occurred_on,
                confirmed=True,
            )
        )
    _set_cell_text(page, slot, text)
    page.updated_at = utc_now()
    await session.commit()
    return await build_report(session, user)


async def pause_page(session: AsyncSession, user: User) -> SelfAwarenessReport:
    start = week_start_on(singapore_today())
    page = await _ensure_page(session, user.id, start)
    page.paused_at = utc_now()
    page.updated_at = utc_now()
    await session.commit()
    return await build_report(session, user)


async def complete_weekly_step(session: AsyncSession, user: User) -> SelfAwarenessReport:
    today = singapore_today()
    page = await _page(session, user.id, week_start_on(today))
    rows = await _evidence(session, page.id) if page is not None else []
    if page is None or not _covered("weekly_step", _cell_text(page, "weekly_step"), rows):
        raise AppError("self_page_not_ready", "本周这一步还是空的。", 409)
    page.weekly_step_completed_at = utc_now()
    page.updated_at = utc_now()
    await session.commit()
    return await build_report(session, user)


async def mark_review_line(
    session: AsyncSession, owner_id: UUID, review_id: UUID, quote: str
) -> EvidenceOut:
    review = await session.get(ConversationReview, review_id)
    if review is None or review.owner_id != owner_id:
        raise AppError("review_not_found", "找不到这条复盘。", 404)
    text = quote.strip()
    if text not in review.transcript:
        raise AppError("evidence_not_a_quote", "这一句不在复盘原文里。", 422)
    start = week_start_on(singapore_today())
    page = await _ensure_page(session, owner_id, start)
    existing = await session.scalar(
        select(SelfEvidence).where(
            SelfEvidence.page_id == page.id,
            SelfEvidence.source_type == "review_line",
            SelfEvidence.source_id == review.id,
            SelfEvidence.quote == text,
        )
    )
    if existing is None:
        existing = SelfEvidence(
            page_id=page.id,
            owner_id=owner_id,
            slot="pool",
            source_type="review_line",
            source_id=review.id,
            quote=text,
            detail=review.title,
            occurred_on=_sg_date(review.created_at),
            confirmed=False,
        )
        session.add(existing)
        await session.flush()
    await session.commit()
    return EvidenceOut(
        id=existing.id,
        slot=existing.slot,
        source_type=existing.source_type,
        source_id=existing.source_id,
        quote=existing.quote,
        detail=existing.detail,
        occurred_on=existing.occurred_on,
        confirmed=existing.confirmed,
    )


async def challenge_context(session: AsyncSession, owner_id: UUID, key: str) -> list[str]:
    if key == "how_i_want_to_be_seen":
        rows = await _reflections(session, owner_id)
        stable = _find(rows, "self_concept_ten", 1)
        if stable is None:
            return ["还没有一句稳定的「我是」。这一格先留空，不用名字或称号填。"]
        return [f"你写下的底色：{stable.reflection.response.strip()[:80]}"]

    if key == "energy_and_reply_pace":
        contacts = list(
            (await session.scalars(select(Contact).where(Contact.owner_id == owner_id))).all()
        )
        events = list(
            (
                await session.scalars(
                    select(ContactEvent).where(ContactEvent.owner_id == owner_id)
                )
            ).all()
        )
        review_count = int(
            await session.scalar(
                select(func.count(ConversationReview.id)).where(
                    ConversationReview.owner_id == owner_id
                )
            )
            or 0
        )
        dated = len(events) + review_count
        if dated < 2:
            return ["带日期的事件或复盘还不到两件。对照先留空。这是记账频率，不是回复速度。"]
        notes = ["这是记账频率，不是回复速度。"]
        if contacts:
            busiest = max(contacts, key=lambda item: item.event_count)
            latest = [
                _sg_date(event.occurred_at)
                for event in events
                if event.contact_id == busiest.id
            ]
            latest_text = max(latest).isoformat() if latest else "还没有日期"
            notes.append(
                f"事件最多的是 {busiest.name}，{busiest.event_count} 件，最近一次在 {latest_text}。"
            )
            by_contact: dict[UUID, date] = {}
            for event in events:
                when = _sg_date(event.occurred_at)
                previous = by_contact.get(event.contact_id)
                if previous is None or when > previous:
                    by_contact[event.contact_id] = when
            if len(by_contact) >= 2:
                quiet_id = min(by_contact, key=lambda item: by_contact[item])
                quiet = next(item for item in contacts if item.id == quiet_id)
                quiet_on = by_contact[quiet_id].isoformat()
                notes.append(f"最久没有新事件的是 {quiet.name}，最近一次在 {quiet_on}。")
        return notes

    if key == "role_stance":
        contacts = list(
            (await session.scalars(select(Contact).where(Contact.owner_id == owner_id))).all()
        )
        labels = ((item.relationship_label or "未分类").strip() or "未分类" for item in contacts)
        mix = Counter(labels)
        if not mix:
            return ["图谱里还没有人。上级、同级、下级写在回答里，不新增分类。"]
        listed = "、".join(f"{label} {count}" for label, count in mix.most_common())
        return [f"现有分类：{listed}。上级、同级、下级写在回答里，不新增分类。"]
    return []
