import base64
import json
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.activity import ConversationReview, PracticeSession
from app.models.contact import Contact, ContactEvent
from app.models.user import User

CONTACT_INFO_MARKER = "\n__SOULMARK_CONTACT_INFO__:"


def _decode_contact_memory(value: str | None) -> tuple[str, list[dict[str, str]]]:
    if not value or CONTACT_INFO_MARKER not in value:
        return value or "", []
    memory, encoded = value.rsplit(CONTACT_INFO_MARKER, 1)
    try:
        fields = json.loads(base64.b64decode(encoded).decode())
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
        fields = []
    return memory, fields if isinstance(fields, list) else []


async def build_user_memory_context(
    session: AsyncSession,
    owner_id: UUID,
    *,
    focus_contact_name: str | None = None,
) -> str:
    user = await session.scalar(select(User).where(User.id == owner_id))
    contacts = list(
        (
            await session.scalars(
                select(Contact)
                .where(Contact.owner_id == owner_id)
                .order_by(Contact.created_at)
            )
        ).all()
    )
    events = list(
        (
            await session.scalars(
                select(ContactEvent)
                .where(ContactEvent.owner_id == owner_id)
                .order_by(ContactEvent.occurred_at.desc())
            )
        ).all()
    )
    practices = list(
        (
            await session.scalars(
                select(PracticeSession)
                .where(PracticeSession.owner_id == owner_id)
                .order_by(PracticeSession.created_at.desc())
            )
        ).all()
    )
    reviews = list(
        (
            await session.scalars(
                select(ConversationReview)
                .where(ConversationReview.owner_id == owner_id)
                .order_by(ConversationReview.created_at.desc())
            )
        ).all()
    )
    events_by_contact: dict[UUID, list[ContactEvent]] = {}
    for event in events:
        events_by_contact.setdefault(event.contact_id, []).append(event)

    lines = [
        "以下是仅属于当前登录用户的 SoulMark 长期记忆。只在与当前任务相关时自然使用，"
        "不要声称掌握未记录的事实，也不要逐字复述整个记忆库。",
    ]
    if user is not None:
        lines.append(
            "用户资料："
            f"姓名={user.display_name}；语言={user.preferred_language}；"
            f"沟通目标={user.communication_goal or '未记录'}。"
        )
    if focus_contact_name:
        lines.append(f"当前重点人物：{focus_contact_name}。")

    for contact in contacts:
        memory, fields = _decode_contact_memory(contact.memory)
        lines.append(
            f"\n人物：{contact.name}\n"
            f"关系：{contact.relationship_label}\n"
            f"备注：{contact.notes or '未记录'}\n"
            f"关系记忆：{memory or '未记录'}\n"
            f"亲密度：{contact.strength}/100"
        )
        useful_fields = [
            f"{field.get('label', '')}={field.get('value', '')}"
            for field in fields
            if isinstance(field, dict) and field.get("label") and field.get("value")
        ]
        if useful_fields:
            lines.append("相关信息：" + "；".join(useful_fields))
        for event in events_by_contact.get(contact.id, []):
            lines.append(
                f"事件[{event.occurred_at.isoformat()}] {event.title}：{event.details}"
                + ("（附有图片）" if event.image_url else "")
            )

    if not contacts:
        lines.append("关系图谱中暂无人物记录。")
    for practice in practices:
        lines.append(
            "\n历史情景模拟："
            f"对象={practice.participant_name}；模式={practice.mode_title}；"
            f"用户表达={practice.user_transcript or '未记录'}；"
            f"对方回应={practice.assistant_transcript or '未记录'}。"
        )
    for review in reviews:
        lines.append(
            "\n历史沟通复盘："
            f"标题={review.title}；来源={review.source}；评分={review.score}/100；"
            f"内容={review.transcript}；评分原因={review.reason}；"
            f"建议={review.advice}；详细建议={review.detailed_advice}。"
        )
    return "\n".join(lines)
