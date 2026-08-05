from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import model_validator
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
    qwen_workspace_id: str | None = None
    qwen_region: Literal["cn-beijing", "ap-southeast-1", "ap-northeast-1", "eu-central-1"] = (
        "cn-beijing"
    )
    qwen_analysis_model: str = "qwen3.7-plus"
    qwen_analysis_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    qwen_analysis_timeout_seconds: float = 45.0
    realtime_input_sample_rate_hz: int = 16000
    realtime_output_sample_rate_hz: int = 24000
    realtime_max_audio_frame_bytes: int = 65536
    avatar_upload_dir: Path = Path("uploads/avatars")
    avatar_max_bytes: int = 5 * 1024 * 1024

    # 微信开放平台移动应用配置。
    wechat_app_id: str = "REPLACE_ME_WECHAT_APP_ID"
    wechat_app_secret: str = "REPLACE_ME_WECHAT_APP_SECRET"

    # development 仅供显式的本地测试；生产环境禁止使用固定验证码。
    sms_provider: Literal["development", "aliyun", "pnvs"] = "development"
    sms_development_code: str = "123456"
    sms_code_ttl_seconds: int = 300
    sms_resend_interval_seconds: int = 60
    sms_max_attempts: int = 5

    # 阿里云短信与号码认证（PNVS）配置。
    aliyun_access_key_id: str = "REPLACE_ME_ALIYUN_ACCESS_KEY_ID"
    aliyun_access_key_secret: str = "REPLACE_ME_ALIYUN_ACCESS_KEY_SECRET"
    aliyun_sms_sign_name: str = "REPLACE_ME_SMS_SIGN_NAME"
    aliyun_sms_template_code: str = "REPLACE_ME_SMS_TEMPLATE_CODE"
    pnvs_sign_name: str = "REPLACE_ME_PNVS_SIGN_NAME"
    pnvs_template_code: str = "100001"
    pnvs_scheme_name: str = ""
    pnvs_code_length: int = 6

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="SOULMARK_",
        extra="ignore",
    )

    @model_validator(mode="after")
    def reject_insecure_production_sms(self) -> "Settings":
        if self.environment == "production" and self.sms_provider == "development":
            raise ValueError("production must use the aliyun or pnvs SMS provider")
        return self

    @property
    def qwen_analysis_base_url(self) -> str:
        return self.qwen_analysis_url.rstrip("/")


@lru_cache
def get_settings() -> Settings:
    return Settings()
