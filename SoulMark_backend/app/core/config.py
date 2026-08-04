from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SoulMark API"
    environment: Literal["development", "test", "production"] = "development"
    database_url: str = "postgresql+psycopg://soulmark:soulmark_local@localhost:5432/soulmark"
    jwt_secret: str = "change-this-secret-before-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_minutes: int = 30

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="SOULMARK_",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()

