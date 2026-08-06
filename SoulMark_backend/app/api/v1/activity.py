from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Response, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.review import analyze_review, analyze_review_media
from app.api.dependencies import CurrentUser
from app.core.config import get_settings
from app.core.errors import AppError
from app.db.session import get_db
from app.models.contact import Contact
from app.schemas.activity import (
    DashboardStats,
    PracticeCreate,
    PracticeResponse,
    ReviewAnalysisRequest,
    ReviewAnalysisResponse,
    ReviewCreate,
    ReviewRelatedContact,
    ReviewResponse,
)
from app.services.activity import (
    create_practice,
    create_review,
    dashboard_stats,
    delete_practice,
    delete_review,
    list_practices,
    list_reviews,
)
from app.services.ai_memory import build_user_memory_context

router = APIRouter(tags=["activity"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


async def resolve_review_contact(
    session: AsyncSession,
    owner_id: UUID,
    analysis: ReviewAnalysisResponse,
) -> ReviewAnalysisResponse:
    suggested_names = [
        name.strip() for name in analysis.related_contact_names if name.strip()
    ]
    legacy_name = (analysis.related_contact_name or "").strip()
    if legacy_name and legacy_name.casefold() not in {
        name.casefold() for name in suggested_names
    }:
        suggested_names.append(legacy_name)
    contacts = (
        await session.scalars(select(Contact).where(Contact.owner_id == owner_id))
    ).all()
    contacts_by_name = {
        contact.name.strip().casefold(): contact for contact in contacts
    }
    matches: list[ReviewRelatedContact] = []
    matched_ids: set[UUID] = set()
    for name in suggested_names:
        contact = contacts_by_name.get(name.casefold())
        if contact is not None and contact.id not in matched_ids:
            matches.append(ReviewRelatedContact(id=contact.id, name=contact.name))
            matched_ids.add(contact.id)
    first = matches[0] if matches else None
    return analysis.model_copy(
        update={
            "related_contact_name": first.name if first else None,
            "related_contact_id": first.id if first else None,
            "related_contact_names": [contact.name for contact in matches],
            "related_contacts": matches,
        }
    )


@router.get("/practices", response_model=list[PracticeResponse])
async def get_practices(
    current_user: CurrentUser, session: DatabaseSession
) -> list[PracticeResponse]:
    rows = await list_practices(session, current_user.id)
    return [PracticeResponse.model_validate(row) for row in rows]


@router.post("/practices", response_model=PracticeResponse, status_code=status.HTTP_201_CREATED)
async def post_practice(
    payload: PracticeCreate, current_user: CurrentUser, session: DatabaseSession
) -> PracticeResponse:
    return PracticeResponse.model_validate(await create_practice(session, current_user.id, payload))


@router.delete("/practices/{practice_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_practice(
    practice_id: UUID, current_user: CurrentUser, session: DatabaseSession
) -> Response:
    await delete_practice(session, current_user.id, practice_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/reviews", response_model=list[ReviewResponse])
async def get_reviews(current_user: CurrentUser, session: DatabaseSession) -> list[ReviewResponse]:
    rows = await list_reviews(session, current_user.id)
    return [ReviewResponse.model_validate(row) for row in rows]


@router.post("/reviews", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def post_review(
    payload: ReviewCreate, current_user: CurrentUser, session: DatabaseSession
) -> ReviewResponse:
    return ReviewResponse.model_validate(await create_review(session, current_user.id, payload))


@router.post("/reviews/analyze", response_model=ReviewAnalysisResponse)
async def post_review_analysis(
    payload: ReviewAnalysisRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> ReviewAnalysisResponse:
    memory = await build_user_memory_context(session, current_user.id)
    analysis = await analyze_review(payload, get_settings(), memory)
    return await resolve_review_contact(session, current_user.id, analysis)


@router.post("/reviews/analyze-media", response_model=ReviewAnalysisResponse)
async def post_review_media_analysis(
    current_user: CurrentUser,
    session: DatabaseSession,
    source: Annotated[str, Form()],
    language: Annotated[str, Form()],
    file: Annotated[UploadFile, File()],
) -> ReviewAnalysisResponse:
    if source not in {"scenario", "wechat"} or language not in {"zh", "en"}:
        raise AppError("review_media_request_invalid", "Invalid media review request.", 422)
    settings = get_settings()
    content = await file.read(settings.review_media_max_bytes + 1)
    if not content or len(content) > settings.review_media_max_bytes:
        raise AppError(
            "review_media_size_invalid",
            "The media file is empty or larger than 7 MB.",
            413,
        )
    memory = await build_user_memory_context(session, current_user.id)
    analysis = await analyze_review_media(
        source=source,
        language=language,
        content=content,
        media_type=file.content_type or "application/octet-stream",
        settings=settings,
        memory_context=memory,
    )
    return await resolve_review_contact(session, current_user.id, analysis)


@router.delete("/reviews/{review_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_review(
    review_id: UUID, current_user: CurrentUser, session: DatabaseSession
) -> Response:
    await delete_review(session, current_user.id, review_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/stats", response_model=DashboardStats)
async def get_stats(current_user: CurrentUser, session: DatabaseSession) -> DashboardStats:
    return DashboardStats.model_validate(await dashboard_stats(session, current_user.id))
