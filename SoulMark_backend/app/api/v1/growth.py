from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentUser
from app.db.session import get_db
from app.schemas.growth import GrowthSnapshot
from app.services.growth import get_growth

router = APIRouter(prefix="/growth", tags=["growth"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


@router.get("", response_model=GrowthSnapshot)
async def get_progress(current_user: CurrentUser, session: DatabaseSession) -> GrowthSnapshot:
    return await get_growth(session, current_user.id)


@router.post("/active", response_model=GrowthSnapshot)
async def record_active(current_user: CurrentUser, session: DatabaseSession) -> GrowthSnapshot:
    return await get_growth(session, current_user.id, active=True)
