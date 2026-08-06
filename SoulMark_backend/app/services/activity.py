from uuid import UUID

from sqlalchemy import delete, distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.activity import (
    ConversationReview,
    PracticeSession,
    ReviewRelationshipImpact,
)
from app.models.contact import Contact
from app.schemas.activity import PracticeCreate, ReviewCreate
from app.services.relationship_strength import RelationshipImpact, reverse_relationship_impact


async def list_practices(session: AsyncSession, owner_id: UUID) -> list[PracticeSession]:
    result = await session.scalars(
        select(PracticeSession)
        .where(PracticeSession.owner_id == owner_id)
        .order_by(PracticeSession.created_at.desc())
    )
    return list(result)


async def create_practice(
    session: AsyncSession, owner_id: UUID, payload: PracticeCreate
) -> PracticeSession:
    practice = PracticeSession(owner_id=owner_id, **payload.model_dump())
    session.add(practice)
    await session.commit()
    await session.refresh(practice)
    return practice


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


async def create_review(
    session: AsyncSession, owner_id: UUID, payload: ReviewCreate
) -> ConversationReview:
    review = ConversationReview(
        owner_id=owner_id,
        **payload.model_dump(exclude={"relationship_impacts"}),
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

    await session.commit()
    await session.refresh(review)
    return review


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
