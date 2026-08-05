from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Response, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentUser
from app.db.session import get_db
from app.schemas.contact import ContactCreate, ContactResponse, ContactUpdate
from app.services.avatar_storage import AvatarStorage, get_avatar_storage
from app.services.contacts import (
    create_contact,
    delete_contact,
    delete_contact_avatar,
    get_owned_contact,
    list_contacts,
    update_contact,
    update_contact_avatar,
)

router = APIRouter(prefix="/contacts", tags=["contacts"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]
AvatarStore = Annotated[AvatarStorage, Depends(get_avatar_storage)]


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
    avatar_storage: AvatarStore,
) -> Response:
    await delete_contact(session, current_user.id, contact_id, avatar_storage)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{contact_id}/avatar", response_model=ContactResponse)
async def post_contact_avatar(
    contact_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    avatar_storage: AvatarStore,
    file: Annotated[UploadFile, File()],
) -> ContactResponse:
    contact = await get_owned_contact(session, current_user.id, contact_id)
    content = await file.read(avatar_storage.max_bytes + 1)
    updated = await update_contact_avatar(
        session,
        contact,
        avatar_storage,
        content,
        file.content_type,
    )
    return ContactResponse.model_validate(updated)


@router.delete("/{contact_id}/avatar", response_model=ContactResponse)
async def remove_contact_avatar(
    contact_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    avatar_storage: AvatarStore,
) -> ContactResponse:
    contact = await get_owned_contact(session, current_user.id, contact_id)
    updated = await delete_contact_avatar(session, contact, avatar_storage)
    return ContactResponse.model_validate(updated)
