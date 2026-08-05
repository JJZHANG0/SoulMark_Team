from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.review import ReviewAnalyzerDependency
from app.api.dependencies import CurrentUser
from app.db.session import get_db
from app.schemas.activity import (
    DashboardStats,
    PracticeCreate,
    PracticeResponse,
    ReviewAnalyzeRequest,
    ReviewCreate,
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

router = APIRouter(tags=["activity"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


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


@router.post(
    "/reviews/analyze",
    response_model=ReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
async def analyze_review(
    payload: ReviewAnalyzeRequest,
    current_user: CurrentUser,
    session: DatabaseSession,
    analyzer: ReviewAnalyzerDependency,
) -> ReviewResponse:
    analysis = await analyzer.analyze(payload.transcript, payload.language)
    review = ReviewCreate(
        practice_id=payload.practice_id,
        title=payload.title,
        source=payload.source,
        transcript=payload.transcript,
        score=analysis.score,
        reason=analysis.reason,
        advice=analysis.advice,
    )
    return ReviewResponse.model_validate(await create_review(session, current_user.id, review))


@router.delete("/reviews/{review_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_review(
    review_id: UUID, current_user: CurrentUser, session: DatabaseSession
) -> Response:
    await delete_review(session, current_user.id, review_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/stats", response_model=DashboardStats)
async def get_stats(current_user: CurrentUser, session: DatabaseSession) -> DashboardStats:
    return DashboardStats.model_validate(await dashboard_stats(session, current_user.id))
