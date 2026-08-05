from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import create_access_token
from app.db.session import get_db
from app.schemas.auth import (
    LoginRequest,
    MessageResponse,
    PhoneCodeRequest,
    PhoneLoginRequest,
    RegisterRequest,
    TokenResponse,
    WeChatLoginRequest,
)
from app.schemas.user import UserResponse
from app.services.auth import authenticate_user, register_user
from app.services.external_auth import (
    SmsSender,
    WeChatClient,
    authenticate_phone,
    authenticate_wechat,
    get_sms_sender,
    get_wechat_client,
    issue_phone_code,
)

router = APIRouter(prefix="/auth", tags=["authentication"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    session: DatabaseSession,
) -> UserResponse:
    user = await register_user(session, payload)
    return UserResponse.model_validate(user)


@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    session: DatabaseSession,
) -> TokenResponse:
    user = await authenticate_user(session, str(payload.email), payload.password)
    settings = get_settings()
    return TokenResponse(
        access_token=create_access_token(user.id),
        expires_in_seconds=settings.jwt_access_token_minutes * 60,
    )


@router.post(
    "/phone/code",
    response_model=MessageResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def send_phone_code(
    payload: PhoneCodeRequest,
    session: DatabaseSession,
    sender: Annotated[SmsSender, Depends(get_sms_sender)],
) -> MessageResponse:
    await issue_phone_code(session, payload.phone_number, sender)
    return MessageResponse(message="验证码已发送。")


@router.post("/phone/login", response_model=TokenResponse)
async def phone_login(
    payload: PhoneLoginRequest,
    session: DatabaseSession,
    sender: Annotated[SmsSender, Depends(get_sms_sender)],
) -> TokenResponse:
    user = await authenticate_phone(session, payload.phone_number, payload.code, sender)
    settings = get_settings()
    return TokenResponse(
        access_token=create_access_token(user.id),
        expires_in_seconds=settings.jwt_access_token_minutes * 60,
    )


@router.post("/wechat/login", response_model=TokenResponse)
async def wechat_login(
    payload: WeChatLoginRequest,
    session: DatabaseSession,
    client: Annotated[WeChatClient, Depends(get_wechat_client)],
) -> TokenResponse:
    identity = await client.exchange_code(payload.code)
    user = await authenticate_wechat(session, identity)
    settings = get_settings()
    return TokenResponse(
        access_token=create_access_token(user.id),
        expires_in_seconds=settings.jwt_access_token_minutes * 60,
    )
