from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.review import analyze_relationship_profile
from app.core.config import Settings
from app.models.activity import ConversationReview, ReviewRelationshipImpact
from app.models.contact import Contact, ContactEvent
from app.services.relationship_strength import calculate_strength

INTIMACY_EVENT_THRESHOLD = 10


async def recalculate_contact_intimacy(
    session: AsyncSession,
    owner_id: UUID,
    contact_id: UUID,
    settings: Settings,
) -> Contact | None:
    contact = await session.scalar(
        select(Contact).where(Contact.id == contact_id, Contact.owner_id == owner_id)
    )
    if contact is None:
        return None

    event_count = (
        await session.scalar(
            select(func.count(ContactEvent.id)).where(
                ContactEvent.owner_id == owner_id,
                ContactEvent.contact_id == contact_id,
            )
        )
    ) or 0
    contact.event_count = event_count
    if event_count < INTIMACY_EVENT_THRESHOLD:
        contact.trust_score = 0
        contact.emotional_depth_score = 0
        contact.reciprocity_score = 0
        contact.support_score = 0
        contact.strength = 0
        contact.intimacy_calculated = False
        await session.commit()
        await session.refresh(contact)
        return contact

    events = (
        await session.scalars(
            select(ContactEvent)
            .where(
                ContactEvent.owner_id == owner_id,
                ContactEvent.contact_id == contact_id,
            )
            .order_by(ContactEvent.occurred_at)
        )
    ).all()
    reviews = (
        await session.scalars(
            select(ConversationReview)
            .join(
                ReviewRelationshipImpact,
                ReviewRelationshipImpact.review_id == ConversationReview.id,
            )
            .where(
                ReviewRelationshipImpact.owner_id == owner_id,
                ReviewRelationshipImpact.contact_id == contact_id,
            )
            .order_by(ConversationReview.created_at)
        )
    ).all()
    events_text = "\n".join(
        f"- {event.occurred_at.isoformat()}｜{event.title}：{event.details}"
        for event in events
    )
    reviews_text = "\n".join(
        (
            f"- {review.created_at.isoformat()}｜{review.title}：{review.transcript}\n"
            f"  复盘原因：{review.reason}\n  复盘建议：{review.advice}"
        )
        for review in reviews
    )
    profile = await analyze_relationship_profile(
        contact_name=contact.name,
        relationship_label=contact.relationship_label,
        contact_memory=contact.memory or "",
        events_text=events_text,
        reviews_text=reviews_text,
        settings=settings,
    )
    contact.trust_score = profile.trust_score
    contact.emotional_depth_score = profile.emotional_depth_score
    contact.reciprocity_score = profile.reciprocity_score
    contact.support_score = profile.support_score
    contact.strength = calculate_strength(contact)
    contact.intimacy_calculated = True
    await session.commit()
    await session.refresh(contact)
    return contact
