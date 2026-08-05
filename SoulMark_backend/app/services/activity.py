from uuid import UUID

from sqlalchemy import delete, distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.activity import ConversationReview, PracticeSession
from app.models.contact import Contact
from app.schemas.activity import PracticeCreate, ReviewCreate


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
    review = ConversationReview(owner_id=owner_id, **payload.model_dump())
    session.add(review)
    await session.commit()
    await session.refresh(review)
    return review


async def delete_review(session: AsyncSession, owner_id: UUID, review_id: UUID) -> None:
    result = await session.execute(
        delete(ConversationReview).where(
            ConversationReview.id == review_id, ConversationReview.owner_id == owner_id
        )
    )
    if result.rowcount == 0:  # type: ignore[attr-defined]
        raise AppError("review_not_found", "Conversation review not found.", 404)
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
