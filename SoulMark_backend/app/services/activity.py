import json
from dataclasses import dataclass
from datetime import datetime
from hashlib import sha256
from uuid import UUID, uuid4

from sqlalchemy import delete, distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.activity import (
    ConversationReview,
    PracticeSession,
    ReviewRelationshipImpact,
)
from app.models.contact import Contact
from app.models.growth import ExperienceEvent, UserGrowth
from app.schemas.activity import PracticeCreate, ReviewCreate
from app.schemas.growth import GrowthSnapshot
from app.services import growth
from app.services.growth_rules import count_completed_turns
from app.services.relationship_strength import RelationshipImpact, reverse_relationship_impact


async def list_practices(session: AsyncSession, owner_id: UUID) -> list[PracticeSession]:
    result = await session.scalars(
        select(PracticeSession)
        .where(PracticeSession.owner_id == owner_id)
        .order_by(PracticeSession.created_at.desc())
    )
    return list(result)


@dataclass
class ActivitySaveResult:
    record: PracticeSession | ConversationReview
    created: bool
    growth: GrowthSnapshot
    awarded_experience: int


async def prepare_activity(
    session: AsyncSession, owner_id: UUID, payload: PracticeCreate | ReviewCreate, kind: str
) -> tuple[UserGrowth, datetime, str, str, int, ActivitySaveResult | None]:
    now = growth.utc_now()
    state = await growth.lock_growth(session, owner_id, now)
    data = payload.model_dump(mode="json", exclude={"event_id"})
    if isinstance(payload, ReviewCreate):
        data["relationship_impacts"] = [
            item.model_dump(mode="json") for item in payload.relationship_impacts
        ]
    digest = sha256(json.dumps(data, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    key = f"{kind}:{payload.event_id or uuid4()}"
    previous = await session.scalar(
        select(ExperienceEvent).where(
            ExperienceEvent.owner_id == owner_id, ExperienceEvent.event_key == key
        )
    )
    if previous is not None:
        if previous.request_hash != digest:
            raise AppError(
                "event_conflict", "This event was already saved with different content.", 409
            )
        record: PracticeSession | ConversationReview | None
        if kind == "practice":
            record = await session.get(PracticeSession, previous.source_id)
        else:
            record = await session.get(ConversationReview, previous.source_id)
        if record is None:
            raise AppError("event_deleted", "This activity has already been deleted.", 409)
        decayed = await growth.settle_decay(session, state, now)
        snapshot = await growth.growth_snapshot(session, state, now, decayed)
        await session.commit()
        return state, now, key, digest, decayed, ActivitySaveResult(record, False, snapshot, 0)
    decayed = await growth.settle_decay(session, state, now)
    return state, now, key, digest, decayed, None


@growth.retry_locked_transaction
async def create_practice(
    session: AsyncSession, owner_id: UUID, payload: PracticeCreate
) -> ActivitySaveResult:
    state, now, key, digest, decayed, replay = await prepare_activity(
        session, owner_id, payload, "practice"
    )
    if replay is not None:
        return replay
    practice = PracticeSession(
        owner_id=owner_id, **payload.model_dump(exclude={"event_id", "messages"})
    )
    session.add(practice)
    await session.flush()
    if payload.messages is None:
        turns = int(bool(payload.user_transcript.strip() and payload.assistant_transcript.strip()))
    else:
        turns = count_completed_turns([(m.role, m.text) for m in payload.messages])
    if turns:
        growth.mark_active(state, now)
    amount = await growth.award_experience(
        session, state, key, "practice", turns * 5, now, practice.id, digest
    )
    snapshot = await growth.growth_snapshot(session, state, now, decayed)
    await session.commit()
    await session.refresh(practice)
    return ActivitySaveResult(practice, True, snapshot, amount)


async def delete_practice(session: AsyncSession, owner_id: UUID, practice_id: UUID) -> None:
    result = await session.execute(
        delete(PracticeSession).where(
            PracticeSession.id == practice_id, PracticeSession.owner_id == owner_id
        )
    )
    if result.rowcount == 0:  # type: ignore[attr-defined]
        raise AppError("practice_not_found", "Practice session not found.", 404)
    await session.commit()


async def list_reviews(session: AsyncSession, owner_id: UUID) -> list[ConversationReview]:
    result = await session.scalars(
        select(ConversationReview)
        .where(ConversationReview.owner_id == owner_id)
        .order_by(ConversationReview.created_at.desc())
    )
    return list(result)


@growth.retry_locked_transaction
async def create_review(
    session: AsyncSession, owner_id: UUID, payload: ReviewCreate
) -> ActivitySaveResult:
    state, now, key, digest, decayed, replay = await prepare_activity(
        session, owner_id, payload, "review"
    )
    if replay is not None:
        return replay
    review = ConversationReview(
        owner_id=owner_id,
        **payload.model_dump(exclude={"relationship_impacts", "event_id"}),
    )
    session.add(review)
    await session.flush()

    applied_contact_ids: set[UUID] = set()
    for requested_impact in payload.relationship_impacts:
        if requested_impact.contact_id in applied_contact_ids:
            continue
        contact = await session.scalar(
            select(Contact).where(
                Contact.id == requested_impact.contact_id,
                Contact.owner_id == owner_id,
            )
        )
        if contact is None:
            continue
        session.add(
            ReviewRelationshipImpact(
                review_id=review.id,
                contact_id=contact.id,
                owner_id=owner_id,
                trust_delta=0,
                emotional_depth_delta=0,
                reciprocity_delta=0,
                support_delta=0,
                strength_delta=0,
                explanation=requested_impact.relationship_signal.explanation,
            )
        )
        applied_contact_ids.add(contact.id)

    growth.mark_active(state, now)
    amount = await growth.award_experience(
        session, state, key, "review", 30, now, review.id, digest
    )
    snapshot = await growth.growth_snapshot(session, state, now, decayed)
    await session.commit()
    await session.refresh(review)
    return ActivitySaveResult(review, True, snapshot, amount)


async def delete_review(session: AsyncSession, owner_id: UUID, review_id: UUID) -> None:
    review = await session.scalar(
        select(ConversationReview).where(
            ConversationReview.id == review_id,
            ConversationReview.owner_id == owner_id,
        )
    )
    if review is None:
        raise AppError("review_not_found", "Conversation review not found.", 404)
    impacts = (
        await session.scalars(
            select(ReviewRelationshipImpact).where(
                ReviewRelationshipImpact.review_id == review_id,
                ReviewRelationshipImpact.owner_id == owner_id,
            )
        )
    ).all()
    for stored_impact in impacts:
        contact = await session.scalar(
            select(Contact).where(
                Contact.id == stored_impact.contact_id,
                Contact.owner_id == owner_id,
            )
        )
        if contact is None or not contact.intimacy_calculated:
            continue
        reverse_relationship_impact(
            contact,
            RelationshipImpact(
                trust_delta=stored_impact.trust_delta,
                emotional_depth_delta=stored_impact.emotional_depth_delta,
                reciprocity_delta=stored_impact.reciprocity_delta,
                support_delta=stored_impact.support_delta,
                strength_delta=stored_impact.strength_delta,
                explanation=stored_impact.explanation,
            ),
        )
    await session.delete(review)
    await session.commit()


async def dashboard_stats(session: AsyncSession, owner_id: UUID) -> dict[str, int | float | None]:
    contacts = await session.scalar(
        select(func.count(Contact.id)).where(Contact.owner_id == owner_id)
    )
    practices = await session.scalar(
        select(func.count(PracticeSession.id)).where(PracticeSession.owner_id == owner_id)
    )
    review_row = (
        await session.execute(
            select(func.count(ConversationReview.id), func.avg(ConversationReview.score)).where(
                ConversationReview.owner_id == owner_id
            )
        )
    ).one()
    categories = await session.scalar(
        select(func.count(distinct(Contact.relationship_label))).where(Contact.owner_id == owner_id)
    )
    return {
        "contacts_count": contacts or 0,
        "practices_count": practices or 0,
        "reviews_count": review_row[0] or 0,
        "relationship_categories_count": categories or 0,
        "average_review_score": float(review_row[1]) if review_row[1] is not None else None,
    }
