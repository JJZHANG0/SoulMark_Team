from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.contact import Contact
from app.schemas.contact import ContactCreate, ContactUpdate
from app.services.avatar_storage import AvatarStorage

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
) -> None:
    contact = await get_owned_contact(session, owner_id, contact_id)
    if avatar_storage is not None:
        avatar_storage.delete(contact.avatar_url)
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
