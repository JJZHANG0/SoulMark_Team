from fastapi import FastAPI

from app.api.v1.auth import router as auth_router
from app.core.config import get_settings
from app.core.errors import AppError, app_error_handler


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(title=settings.app_name, version="0.1.0")
    application.add_exception_handler(AppError, app_error_handler)
    application.include_router(auth_router, prefix="/api/v1")

    @application.get("/health", tags=["health"])
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "soulmark-backend"}

    return application


app = create_app()
