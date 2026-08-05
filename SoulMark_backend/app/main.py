from typing import Annotated

from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.activity import router as activity_router
from app.api.v1.auth import router as auth_router
from app.api.v1.contacts import router as contacts_router
from app.api.v1.realtime import router as realtime_router
from app.api.v1.users import router as users_router
from app.core.config import get_settings
from app.core.errors import AppError, app_error_handler
from app.db.session import get_db


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(title=settings.app_name, version="0.1.0")
    application.add_exception_handler(AppError, app_error_handler)
    application.include_router(auth_router, prefix="/api/v1")
    application.include_router(activity_router, prefix="/api/v1")
    application.include_router(users_router, prefix="/api/v1")
    application.include_router(contacts_router, prefix="/api/v1")
    application.include_router(realtime_router, prefix="/api/v1")

    @application.get("/health", tags=["health"])
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "soulmark-backend"}

    @application.get("/health/ready", tags=["health"])
    async def readiness(
        session: Annotated[AsyncSession, Depends(get_db)],
    ) -> dict[str, str]:
        try:
            await session.execute(text("SELECT 1"))
        except SQLAlchemyError as exc:
            raise AppError("database_unavailable", "The database is unavailable.", 503) from exc
        return {"status": "ready", "database": "ok"}

    return application


app = create_app()
