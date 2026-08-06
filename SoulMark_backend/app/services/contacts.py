from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.contact import Contact, ContactEvent
from app.schemas.contact import ContactCreate, ContactUpdate
from app.schemas.contact_event import ContactEventCreate
from app.services.avatar_storage import AvatarStorage
from app.services.event_image_storage import EventImageStorage
from app.services.relationship_strength import (
    reset_dimensions_to_strength,
)

FREE_CONTACT_LIMIT = 5


async def list_contacts(session: AsyncSession, owner_id: UUID) -> list[Contact]:
    result = await session.scalars(
        select(Contact).where(Contact.owner_id == owner_id).order_by(Contact.created_at)
    )
    return list(result.all())


async def get_owned_contact(session: AsyncSession, owner_id: UUID, contact_id: UUID) -> Contact:
    contact = await session.scalar(
        select(Contact).where(Contact.id == contact_id, Contact.owner_id == owner_id)
    )
    if contact is None:
        raise AppError("contact_not_found", "The contact was not found.", 404)
    return contact


async def create_contact(
    session: AsyncSession,
    owner_id: UUID,
    payload: ContactCreate,
) -> Contact:
    count = await session.scalar(select(func.count(Contact.id)).where(Contact.owner_id == owner_id))
    if count is not None and count >= FREE_CONTACT_LIMIT:
        raise AppError(
            "contact_limit_reached",
            "The free plan supports up to five contacts.",
            400,
        )

    values = payload.model_dump()
    values["name"] = payload.name.strip()
    values["relationship_label"] = payload.relationship_label.strip()
    contact = Contact(owner_id=owner_id, **values)
    contact.strength = 0
    reset_dimensions_to_strength(contact)
    contact.intimacy_calculated = False
    contact.event_count = 0
    session.add(contact)
    await session.commit()
    await session.refresh(contact)
    return contact


async def update_contact(
    session: AsyncSession,
    owner_id: UUID,
    contact_id: UUID,
    payload: ContactUpdate,
) -> Contact:
    contact = await get_owned_contact(session, owner_id, contact_id)
    changes = payload.model_dump(exclude_unset=True)
    changes.pop("strength", None)
    for required_field in ("name", "relationship_label", "strength"):
        if changes.get(required_field) is None:
            changes.pop(required_field, None)
    for text_field in ("name", "relationship_label"):
        if text_field in changes:
            changes[text_field] = changes[text_field].strip()
    for field, value in changes.items():
        setattr(contact, field, value)

    await session.commit()
    await session.refresh(contact)
    return contact


async def delete_contact(
    session: AsyncSession,
    owner_id: UUID,
    contact_id: UUID,
    avatar_storage: AvatarStorage | None = None,
    event_image_storage: EventImageStorage | None = None,
) -> None:
    contact = await get_owned_contact(session, owner_id, contact_id)
    if avatar_storage is not None:
        avatar_storage.delete(contact.avatar_url)
    if event_image_storage is not None:
        image_urls = (
            await session.scalars(
                select(ContactEvent.image_url).where(
                    ContactEvent.owner_id == owner_id,
                    ContactEvent.contact_id == contact_id,
                )
            )
        ).all()
        for image_url in image_urls:
            event_image_storage.delete(image_url)
    await session.delete(contact)
    await session.commit()


async def update_contact_avatar(
    session: AsyncSession,
    contact: Contact,
    avatar_storage: AvatarStorage,
    content: bytes,
    content_type: str | None,
) -> Contact:
    previous_url = contact.avatar_url
    contact.avatar_url = avatar_storage.save(content, content_type)
    await session.commit()
    await session.refresh(contact)
    avatar_storage.delete(previous_url)
    return contact


async def delete_contact_avatar(
    session: AsyncSession,
    contact: Contact,
    avatar_storage: AvatarStorage,
) -> Contact:
    previous_url = contact.avatar_url
    contact.avatar_url = None
    await session.commit()
    await session.refresh(contact)
    avatar_storage.delete(previous_url)
    return contact


async def list_contact_events(
    session: AsyncSession, owner_id: UUID, contact_id: UUID
) -> list[ContactEvent]:
    await get_owned_contact(session, owner_id, contact_id)
    result = await session.scalars(
        select(ContactEvent)
        .where(
            ContactEvent.owner_id == owner_id,
            ContactEvent.contact_id == contact_id,
        )
        .order_by(ContactEvent.occurred_at.desc())
    )
    return list(result.all())


async def create_contact_event(
    session: AsyncSession,
    owner_id: UUID,
    contact_id: UUID,
    payload: ContactEventCreate,
) -> ContactEvent:
    contact = await get_owned_contact(session, owner_id, contact_id)
    event = ContactEvent(
        owner_id=owner_id,
        contact_id=contact_id,
        title=payload.title,
        details=payload.details,
        occurred_at=payload.occurred_at,
        trust_delta=0,
        emotional_depth_delta=0,
        reciprocity_delta=0,
        support_delta=0,
        strength_delta=0,
        impact_explanation=None,
    )
    contact.event_count += 1
    session.add(event)
    await session.commit()
    await session.refresh(event)
    return event


async def get_owned_contact_event(
    session: AsyncSession,
    owner_id: UUID,
    contact_id: UUID,
    event_id: UUID,
) -> ContactEvent:
    event = await session.scalar(
        select(ContactEvent).where(
            ContactEvent.id == event_id,
            ContactEvent.contact_id == contact_id,
            ContactEvent.owner_id == owner_id,
        )
    )
    if event is None:
        raise AppError("contact_event_not_found", "Contact event not found.", 404)
    return event


async def update_contact_event_image(
    session: AsyncSession,
    event: ContactEvent,
    storage: EventImageStorage,
    content: bytes,
    content_type: str | None,
) -> ContactEvent:
    previous_url = event.image_url
    event.image_url = storage.save(content, content_type)
    await session.commit()
    await session.refresh(event)
    storage.delete(previous_url)
    return event


async def delete_contact_event(
    session: AsyncSession,
    owner_id: UUID,
    contact_id: UUID,
    event_id: UUID,
    storage: EventImageStorage,
) -> None:
    event = await get_owned_contact_event(session, owner_id, contact_id, event_id)
    contact = await get_owned_contact(session, owner_id, contact_id)
    contact.event_count = max(0, contact.event_count - 1)
    image_url = event.image_url
    await session.delete(event)
    await session.commit()
    storage.delete(image_url)
