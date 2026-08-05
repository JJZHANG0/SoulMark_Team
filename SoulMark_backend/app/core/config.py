from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SoulMark API"
    environment: Literal["development", "test", "production"] = "development"
    database_url: str = "postgresql+psycopg://soulmark:soulmark_local@localhost:5432/soulmark"
    jwt_secret: str = "change-this-secret-before-production"
    jwt_algorithm: str = "HS256"
    jwt_access_token_minutes: int = 60 * 24 * 30
    qwen_api_key: str | None = None
    qwen_realtime_url: str = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
    qwen_realtime_model: str = "qwen3.5-omni-plus-realtime"
    qwen_voice: str = "Ethan"
    qwen_input_transcription_model: str = "qwen3-asr-flash-realtime"
    realtime_input_sample_rate_hz: int = 16000
    realtime_output_sample_rate_hz: int = 24000
    realtime_max_audio_frame_bytes: int = 65536

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="SOULMARK_",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
