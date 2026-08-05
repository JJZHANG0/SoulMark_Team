import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_production_rejects_fixed_development_sms_code() -> None:
    with pytest.raises(ValidationError, match="production must use"):
        Settings(
            _env_file=None,
            environment="production",
            sms_provider="development",
        )


def test_production_accepts_real_sms_provider() -> None:
    settings = Settings(
        _env_file=None,
        environment="production",
        sms_provider="pnvs",
    )

    assert settings.sms_provider == "pnvs"
