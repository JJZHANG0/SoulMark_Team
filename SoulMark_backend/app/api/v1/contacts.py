from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Response, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentUser
from app.core.config import get_settings
from app.core.errors import AppError
from app.db.session import get_db
from app.schemas.contact import ContactCreate, ContactResponse, ContactUpdate
from app.schemas.contact_event import ContactEventCreate, ContactEventResponse
from app.services.avatar_storage import AvatarStorage, get_avatar_storage
from app.services.contacts import (
    create_contact,
    create_contact_event,
    delete_contact,
    delete_contact_avatar,
    delete_contact_event,
    get_owned_contact,
    get_owned_contact_event,
    list_contact_events,
    list_contacts,
    update_contact,
    update_contact_avatar,
    update_contact_event_image,
)
from app.services.event_image_storage import EventImageStorage, get_event_image_storage
from app.services.intimacy import recalculate_contact_intimacy

router = APIRouter(prefix="/contacts", tags=["contacts"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]
AvatarStore = Annotated[AvatarStorage, Depends(get_avatar_storage)]
EventImageStore = Annotated[EventImageStorage, Depends(get_event_image_storage)]


@router.get("", response_model=list[ContactResponse])
async def get_contacts(
    current_user: CurrentUser, session: DatabaseSession
) -> list[ContactResponse]:
    contacts = await list_contacts(session, current_user.id)
    for index, contact in enumerate(contacts):
        if contact.event_count >= 10 and not contact.intimacy_calculated:
            try:
                contacts[index] = (
                    await recalculate_contact_intimacy(
                        session,
                        current_user.id,
                        contact.id,
                        get_settings(),
                    )
                    or contact
                )
            except AppError:
                pass
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
    if contact.event_count >= 10 and not contact.intimacy_calculated:
        try:
            contact = (
                await recalculate_contact_intimacy(
                    session,
                    current_user.id,
                    contact_id,
                    get_settings(),
                )
                or contact
            )
        except AppError:
            pass
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
    event_image_storage: EventImageStore,
) -> Response:
    await delete_contact(
        session,
        current_user.id,
        contact_id,
        avatar_storage,
        event_image_storage,
    )
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


@router.get("/{contact_id}/events", response_model=list[ContactEventResponse])
async def get_contact_events(
    contact_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> list[ContactEventResponse]:
    events = await list_contact_events(session, current_user.id, contact_id)
    return [ContactEventResponse.model_validate(event) for event in events]


@router.post(
    "/{contact_id}/events",
    response_model=ContactEventResponse,
    status_code=status.HTTP_201_CREATED,
)
async def post_contact_event(
    contact_id: UUID,
    payload: ContactEventCreate,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> ContactEventResponse:
    event = await create_contact_event(session, current_user.id, contact_id, payload)
    try:
        await recalculate_contact_intimacy(
            session,
            current_user.id,
            contact_id,
            get_settings(),
        )
    except AppError:
        pass
    return ContactEventResponse.model_validate(event)


@router.post(
    "/{contact_id}/events/{event_id}/image",
    response_model=ContactEventResponse,
)
async def post_contact_event_image(
    contact_id: UUID,
    event_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    image_storage: EventImageStore,
    file: Annotated[UploadFile, File()],
) -> ContactEventResponse:
    event = await get_owned_contact_event(session, current_user.id, contact_id, event_id)
    content = await file.read(image_storage.max_bytes + 1)
    updated = await update_contact_event_image(
        session,
        event,
        image_storage,
        content,
        file.content_type,
    )
    return ContactEventResponse.model_validate(updated)


@router.delete(
    "/{contact_id}/events/{event_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_contact_event(
    contact_id: UUID,
    event_id: UUID,
    current_user: CurrentUser,
    session: DatabaseSession,
    image_storage: EventImageStore,
) -> Response:
    await delete_contact_event(
        session,
        current_user.id,
        contact_id,
        event_id,
        image_storage,
    )
    try:
        await recalculate_contact_intimacy(
            session,
            current_user.id,
            contact_id,
            get_settings(),
        )
    except AppError:
        pass
    return Response(status_code=status.HTTP_204_NO_CONTENT)
