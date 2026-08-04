from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentUser
from app.db.session import get_db
from app.schemas.contact import ContactCreate, ContactResponse, ContactUpdate
from app.services.contacts import (
    create_contact,
    delete_contact,
    get_owned_contact,
    list_contacts,
    update_contact,
)

router = APIRouter(prefix="/contacts", tags=["contacts"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


@router.get("", response_model=list[ContactResponse])
async def get_contacts(
    current_user: CurrentUser, session: DatabaseSession
) -> list[ContactResponse]:
    contacts = await list_contacts(session, current_user.id)
    return [ContactResponse.model_validate(contact) for contact in contacts]


@router.post("", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
async def post_contact(
    payload: ContactCreate,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> ContactResponse:
    contact = await create_contact(session, current_user.id, payload)
    return ContactResponse.model_validate(contact)


@router.get("/{contact_id}", response_model=ContactResponse)
async def get_contact(
    contact_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> ContactResponse:
    contact = await get_owned_contact(session, current_user.id, contact_id)
    return ContactResponse.model_validate(contact)


@router.patch("/{contact_id}", response_model=ContactResponse)
async def patch_contact(
    contact_id: UUID,
    payload: ContactUpdate,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> ContactResponse:
    contact = await update_contact(session, current_user.id, contact_id, payload)
    return ContactResponse.model_validate(contact)


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_contact(
    contact_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> Response:
    await delete_contact(session, current_user.id, contact_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
