from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import CurrentUser
from app.core.errors import AppError
from app.core.security import verify_password
from app.db.session import get_db
from app.models.activity import ConversationReview, PracticeSession
from app.models.challenge import ChallengeProgress, ChallengeReflection
from app.models.contact import Contact, ContactEvent
from app.schemas.activity import PracticeResponse, ReviewResponse
from app.schemas.contact import ContactResponse
from app.schemas.contact_event import ContactEventResponse
from app.schemas.self_page import ConfirmCellRequest, SelfAwarenessReport
from app.schemas.user import AccountDeletionRequest, TutorialProgress, UserResponse, UserUpdate
from app.services.avatar_storage import AvatarStorage, get_avatar_storage
from app.services.event_image_storage import EventImageStorage, get_event_image_storage
from app.services.external_auth import SmsSender, authenticate_phone, get_sms_sender
from app.services.self_page import build_report, complete_weekly_step, confirm_cell, pause_page
from app.services.users import advance_tutorial, update_profile

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: CurrentUser) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.patch("/me", response_model=UserResponse)
async def patch_me(
    payload: UserUpdate,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> UserResponse:
    user = await update_profile(session, current_user, payload)
    return UserResponse.model_validate(user)


@router.patch("/me/tutorial", response_model=UserResponse)
async def patch_tutorial_progress(
    payload: TutorialProgress,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> UserResponse:
    user = await advance_tutorial(session, current_user, payload.step)
    return UserResponse.model_validate(user)


@router.get("/me/export")
async def export_my_data(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    contacts = list(
        (await session.scalars(select(Contact).where(Contact.owner_id == current_user.id))).all()
    )
    events = list(
        (
            await session.scalars(
                select(ContactEvent).where(ContactEvent.owner_id == current_user.id)
            )
        ).all()
    )
    practices = list(
        (
            await session.scalars(
                select(PracticeSession).where(PracticeSession.owner_id == current_user.id)
            )
        ).all()
    )
    reviews = list(
        (
            await session.scalars(
                select(ConversationReview).where(ConversationReview.owner_id == current_user.id)
            )
        ).all()
    )
    challenge_progress = list(
        (
            await session.scalars(
                select(ChallengeProgress).where(ChallengeProgress.owner_id == current_user.id)
            )
        ).all()
    )
    challenge_reflections = list(
        (
            await session.scalars(
                select(ChallengeReflection).where(ChallengeReflection.owner_id == current_user.id)
            )
        ).all()
    )
    return {
        "exported_at": datetime.now(UTC),
        "user": UserResponse.model_validate(current_user).model_dump(mode="json"),
        "contacts": [
            ContactResponse.model_validate(item).model_dump(mode="json") for item in contacts
        ],
        "contact_events": [
            ContactEventResponse.model_validate(item).model_dump(mode="json") for item in events
        ],
        "practices": [
            PracticeResponse.model_validate(item).model_dump(mode="json") for item in practices
        ],
        "reviews": [
            ReviewResponse.model_validate(item).model_dump(mode="json") for item in reviews
        ],
        "challenges": [
            {
                "challenge_key": item.challenge_key,
                "status": item.status,
                "completed_steps": item.completed_steps,
                "completion_count": item.completion_count,
                "started_at": item.started_at.isoformat(),
                "completed_at": item.completed_at.isoformat() if item.completed_at else None,
                "reflections": [
                    {
                        "step_index": reflection.step_index,
                        "response": reflection.response,
                        "rating": reflection.rating,
                    }
                    for reflection in challenge_reflections
                    if reflection.progress_id == item.id
                ],
            }
            for item in challenge_progress
        ],
    }


@router.get("/me/self-awareness-report", response_model=SelfAwarenessReport)
async def get_self_awareness_report(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> SelfAwarenessReport:
    return await build_report(session, current_user)


@router.put("/me/self-page/cells", response_model=SelfAwarenessReport)
async def put_self_page_cell(
    payload: ConfirmCellRequest,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> SelfAwarenessReport:
    return await confirm_cell(session, current_user, payload)


@router.post("/me/self-page/pause", response_model=SelfAwarenessReport)
async def post_self_page_pause(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> SelfAwarenessReport:
    return await pause_page(session, current_user)


@router.post("/me/self-page/step", response_model=SelfAwarenessReport)
async def post_self_page_step(
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
) -> SelfAwarenessReport:
    return await complete_weekly_step(session, current_user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_account(
    payload: AccountDeletionRequest,
    current_user: CurrentUser,
    session: Annotated[AsyncSession, Depends(get_db)],
    avatar_storage: Annotated[AvatarStorage, Depends(get_avatar_storage)],
    event_image_storage: Annotated[EventImageStorage, Depends(get_event_image_storage)],
    sms_sender: Annotated[SmsSender, Depends(get_sms_sender)],
) -> Response:
    if current_user.password_hash is not None:
        if payload.password is None or not verify_password(
            payload.password,
            current_user.password_hash,
        ):
            raise AppError("account_deletion_auth_failed", "密码不正确。", 401)
    elif current_user.phone_number is not None:
        if payload.code is None:
            raise AppError("account_deletion_code_required", "请输入短信验证码。", 422)
        verified_user = await authenticate_phone(
            session,
            current_user.phone_number,
            payload.code,
            sms_sender,
        )
        if verified_user.id != current_user.id:
            raise AppError("account_deletion_auth_failed", "身份验证失败。", 401)
    else:
        raise AppError(
            "account_deletion_reauth_unavailable",
            "当前登录方式暂不支持直接删除，请先绑定邮箱或手机号。",
            409,
        )

    avatar_urls = list(
        (
            await session.scalars(
                select(Contact.avatar_url).where(Contact.owner_id == current_user.id)
            )
        ).all()
    )
    event_image_urls = list(
        (
            await session.scalars(
                select(ContactEvent.image_url).where(ContactEvent.owner_id == current_user.id)
            )
        ).all()
    )
    await session.delete(current_user)
    await session.commit()
    for avatar_url in avatar_urls:
        avatar_storage.delete(avatar_url)
    for image_url in event_image_urls:
        event_image_storage.delete(image_url)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
