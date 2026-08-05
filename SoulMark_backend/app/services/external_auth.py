import asyncio
import json
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Protocol

import httpx
from pydantic import BaseModel
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.errors import AppError
from app.core.security import hash_password, verify_password
from app.models.phone_verification import PhoneVerificationCode
from app.models.user import User


def normalize_phone_number(phone_number: str) -> str:
    compact = phone_number.strip().replace(" ", "").replace("-", "")
    if compact.startswith("+86"):
        compact = compact[3:]
    elif compact.startswith("86") and len(compact) == 13:
        compact = compact[2:]
    return f"+86{compact}"


class SmsSender(Protocol):
    provider_name: str
    verifies_remotely: bool

    async def send_code(self, phone_number: str, code: str) -> None: ...

    async def verify_code(self, phone_number: str, code: str) -> bool: ...


class DevelopmentSmsSender:
    provider_name = "development"
    verifies_remotely = False

    async def send_code(self, phone_number: str, code: str) -> None:
        # 本地开发模式故意不调用真实短信服务。验证码由环境变量固定。
        del phone_number, code

    async def verify_code(self, phone_number: str, code: str) -> bool:
        del phone_number, code
        return False


class AliyunSmsSender:
    """普通阿里云短信服务，保留给具有企业短信资质的部署使用。"""

    provider_name = "aliyun"
    verifies_remotely = False

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def _send_sync(self, phone_number: str, code: str) -> None:
        from alibabacloud_dysmsapi20170525 import models as sms_models
        from alibabacloud_dysmsapi20170525.client import Client
        from alibabacloud_tea_openapi import models as open_api_models

        config = open_api_models.Config(
            access_key_id=self.settings.aliyun_access_key_id,
            access_key_secret=self.settings.aliyun_access_key_secret,
        )
        config.endpoint = "dysmsapi.aliyuncs.com"
        client = Client(config)
        request = sms_models.SendSmsRequest(
            phone_numbers=phone_number.removeprefix("+86"),
            sign_name=self.settings.aliyun_sms_sign_name,
            template_code=self.settings.aliyun_sms_template_code,
            template_param=json.dumps({"code": code}, ensure_ascii=False),
        )
        response = client.send_sms(request)
        if response.body is None or response.body.code != "OK":
            raise AppError("sms_delivery_failed", "验证码发送失败，请稍后重试。", 502)

    async def send_code(self, phone_number: str, code: str) -> None:
        try:
            await asyncio.to_thread(self._send_sync, phone_number, code)
        except AppError:
            raise
        except Exception as exc:
            raise AppError("sms_delivery_failed", "验证码发送失败，请稍后重试。", 502) from exc

    async def verify_code(self, phone_number: str, code: str) -> bool:
        del phone_number, code
        return False


class PnvsSmsSender:
    """阿里云号码认证短信服务，由平台生成并校验验证码。"""

    provider_name = "pnvs"
    verifies_remotely = True

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def _create_client(self) -> object:
        from alibabacloud_dypnsapi20170525.client import Client
        from alibabacloud_tea_openapi import models as open_api_models

        config = open_api_models.Config(
            access_key_id=self.settings.aliyun_access_key_id,
            access_key_secret=self.settings.aliyun_access_key_secret,
        )
        config.endpoint = "dypnsapi.aliyuncs.com"
        return Client(config)

    def _send_sync(self, phone_number: str) -> None:
        from alibabacloud_dypnsapi20170525 import models as pnvs_models

        client = self._create_client()
        request = pnvs_models.SendSmsVerifyCodeRequest(
            scheme_name=self.settings.pnvs_scheme_name or None,
            country_code="86",
            phone_number=phone_number.removeprefix("+86"),
            sign_name=self.settings.pnvs_sign_name,
            template_code=self.settings.pnvs_template_code,
            template_param=json.dumps(
                {"code": "##code##", "min": str(self.settings.sms_code_ttl_seconds // 60)},
                ensure_ascii=False,
            ),
            code_length=self.settings.pnvs_code_length,
            valid_time=self.settings.sms_code_ttl_seconds,
            duplicate_policy=1,
            interval=self.settings.sms_resend_interval_seconds,
            code_type=1,
            return_verify_code=False,
        )
        response = client.send_sms_verify_code(request)  # type: ignore[attr-defined]
        if response.body is None or response.body.code != "OK":
            raise AppError("sms_delivery_failed", "验证码发送失败，请稍后重试。", 502)

    def _verify_sync(self, phone_number: str, code: str) -> bool:
        from alibabacloud_dypnsapi20170525 import models as pnvs_models

        client = self._create_client()
        request = pnvs_models.CheckSmsVerifyCodeRequest(
            scheme_name=self.settings.pnvs_scheme_name or None,
            country_code="86",
            phone_number=phone_number.removeprefix("+86"),
            verify_code=code,
            case_auth_policy=1,
        )
        response = client.check_sms_verify_code(request)  # type: ignore[attr-defined]
        body = response.body
        return bool(
            body is not None
            and body.code == "OK"
            and body.model is not None
            and body.model.verify_result == "PASS"
        )

    async def send_code(self, phone_number: str, code: str) -> None:
        del code
        try:
            await asyncio.to_thread(self._send_sync, phone_number)
        except AppError:
            raise
        except Exception as exc:
            raise AppError("sms_delivery_failed", "验证码发送失败，请稍后重试。", 502) from exc

    async def verify_code(self, phone_number: str, code: str) -> bool:
        try:
            return await asyncio.to_thread(self._verify_sync, phone_number, code)
        except Exception as exc:
            raise AppError(
                "sms_verification_unavailable",
                "验证码服务暂时不可用，请稍后重试。",
                502,
            ) from exc


def _has_placeholder(*values: str) -> bool:
    return any(not value or value.startswith("REPLACE_ME") for value in values)


def get_sms_sender() -> SmsSender:
    settings = get_settings()
    if settings.sms_provider == "development":
        return DevelopmentSmsSender()
    if settings.sms_provider == "pnvs":
        if _has_placeholder(
            settings.aliyun_access_key_id,
            settings.aliyun_access_key_secret,
            settings.pnvs_sign_name,
            settings.pnvs_template_code,
        ):
            raise AppError("sms_not_configured", "号码认证短信服务尚未完成配置。", 503)
        return PnvsSmsSender(settings)
    if _has_placeholder(
        settings.aliyun_access_key_id,
        settings.aliyun_access_key_secret,
        settings.aliyun_sms_sign_name,
        settings.aliyun_sms_template_code,
    ):
        raise AppError("sms_not_configured", "短信服务尚未完成配置。", 503)
    return AliyunSmsSender(settings)


async def issue_phone_code(
    session: AsyncSession,
    phone_number: str,
    sender: SmsSender,
) -> None:
    settings = get_settings()
    phone = normalize_phone_number(phone_number)
    now = datetime.now(UTC)
    resend_after = now - timedelta(seconds=settings.sms_resend_interval_seconds)
    recent = await session.scalar(
        select(PhoneVerificationCode)
        .where(
            PhoneVerificationCode.phone_number == phone,
            PhoneVerificationCode.created_at >= resend_after,
        )
        .order_by(PhoneVerificationCode.created_at.desc())
    )
    if recent is not None:
        raise AppError("sms_too_frequent", "验证码发送过于频繁，请稍后重试。", 429)

    if sender.provider_name == "development":
        code = settings.sms_development_code
    else:
        code = f"{secrets.randbelow(1_000_000):06d}"
    await sender.send_code(phone, code)
    verification = PhoneVerificationCode(
        phone_number=phone,
        provider=sender.provider_name,
        code_hash=None if sender.verifies_remotely else hash_password(code),
        expires_at=now + timedelta(seconds=settings.sms_code_ttl_seconds),
    )
    session.add(verification)
    await session.commit()


async def authenticate_phone(
    session: AsyncSession,
    phone_number: str,
    code: str,
    sender: SmsSender,
) -> User:
    settings = get_settings()
    phone = normalize_phone_number(phone_number)
    now = datetime.now(UTC)
    verification = await session.scalar(
        select(PhoneVerificationCode)
        .where(
            PhoneVerificationCode.phone_number == phone,
            PhoneVerificationCode.consumed_at.is_(None),
            PhoneVerificationCode.expires_at > now,
        )
        .order_by(PhoneVerificationCode.created_at.desc())
    )
    if verification is None or verification.provider != sender.provider_name:
        raise AppError("invalid_phone_code", "验证码无效或已过期。", 401)
    if verification.attempts >= settings.sms_max_attempts:
        raise AppError("phone_code_locked", "验证码尝试次数过多，请重新获取。", 429)

    if sender.verifies_remotely:
        is_valid = await sender.verify_code(phone, code)
    else:
        is_valid = verification.code_hash is not None and verify_password(
            code, verification.code_hash
        )
    if not is_valid:
        verification.attempts += 1
        await session.commit()
        raise AppError("invalid_phone_code", "验证码无效或已过期。", 401)

    verification.consumed_at = now
    user = await session.scalar(select(User).where(User.phone_number == phone))
    if user is None:
        user = User(phone_number=phone, display_name=f"用户{phone[-4:]}", is_active=True)
        session.add(user)
    if not user.is_active:
        raise AppError("inactive_user", "This account is inactive.", 401)
    await session.commit()
    await session.refresh(user)
    return user


@dataclass(frozen=True)
class WeChatIdentity:
    openid: str
    unionid: str | None = None


class WeChatTokenPayload(BaseModel):
    openid: str | None = None
    unionid: str | None = None
    errcode: int | None = None
    errmsg: str | None = None


class WeChatClient(Protocol):
    async def exchange_code(self, code: str) -> WeChatIdentity: ...


class HttpWeChatClient:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def exchange_code(self, code: str) -> WeChatIdentity:
        if self.settings.wechat_app_id.startswith(
            "REPLACE_ME"
        ) or self.settings.wechat_app_secret.startswith("REPLACE_ME"):
            raise AppError("wechat_not_configured", "微信登录尚未完成配置。", 503)
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.get(
                "https://api.weixin.qq.com/sns/oauth2/access_token",
                params={
                    "appid": self.settings.wechat_app_id,
                    "secret": self.settings.wechat_app_secret,
                    "code": code,
                    "grant_type": "authorization_code",
                },
            )
        if response.is_error:
            raise AppError("wechat_unavailable", "微信服务暂时不可用。", 502)
        payload = WeChatTokenPayload.model_validate(response.json())
        if payload.errcode is not None or payload.openid is None:
            raise AppError("invalid_wechat_code", "微信授权失败，请重新尝试。", 401)
        return WeChatIdentity(openid=payload.openid, unionid=payload.unionid)


def get_wechat_client() -> WeChatClient:
    return HttpWeChatClient(get_settings())


async def authenticate_wechat(session: AsyncSession, identity: WeChatIdentity) -> User:
    conditions = [User.wechat_openid == identity.openid]
    if identity.unionid is not None:
        conditions.append(User.wechat_unionid == identity.unionid)
    user = await session.scalar(select(User).where(or_(*conditions)))
    if user is None:
        user = User(
            wechat_openid=identity.openid,
            wechat_unionid=identity.unionid,
            display_name="微信用户",
            is_active=True,
        )
        session.add(user)
    else:
        user.wechat_openid = identity.openid
        if identity.unionid is not None:
            user.wechat_unionid = identity.unionid
    if not user.is_active:
        raise AppError("inactive_user", "This account is inactive.", 401)
    await session.commit()
    await session.refresh(user)
    return user
