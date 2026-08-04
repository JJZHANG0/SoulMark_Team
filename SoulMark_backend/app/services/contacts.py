from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.contact import Contact
from app.schemas.contact import ContactCreate, ContactUpdate

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
) -> None:
    contact = await get_owned_contact(session, owner_id, contact_id)
    await session.delete(contact)
    await session.commit()
