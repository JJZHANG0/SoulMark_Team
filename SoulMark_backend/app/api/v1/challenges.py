from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentUser
from app.db.session import get_db
from app.schemas.challenge import (
    ChallengeActionResponse,
    ChallengeDetail,
    ChallengeList,
    ChallengeStepSubmission,
)
from app.services import challenges as service

router = APIRouter(prefix="/challenges", tags=["challenges"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


@router.get("", response_model=ChallengeList)
async def list_challenges(current_user: CurrentUser, session: DatabaseSession) -> ChallengeList:
    return await service.list_challenges(session, current_user.id)


@router.get("/{key}", response_model=ChallengeDetail)
async def get_challenge(
    key: str, current_user: CurrentUser, session: DatabaseSession
) -> ChallengeDetail:
    return await service.challenge_detail(session, current_user.id, key)


@router.post("/{key}/start", response_model=ChallengeDetail)
async def start_challenge(
    key: str, current_user: CurrentUser, session: DatabaseSession
) -> ChallengeDetail:
    return await service.start_challenge(session, current_user.id, key)


@router.put("/{key}/steps/{index}", response_model=ChallengeActionResponse)
async def submit_step(
    key: str,
    index: int,
    payload: ChallengeStepSubmission,
    current_user: CurrentUser,
    session: DatabaseSession,
) -> ChallengeActionResponse:
    return await service.submit_step(session, current_user.id, key, index, payload)


@router.post("/{key}/complete", response_model=ChallengeActionResponse)
async def complete_challenge(
    key: str, current_user: CurrentUser, session: DatabaseSession
) -> ChallengeActionResponse:
    return await service.complete_challenge(session, current_user.id, key)
