import asyncio
import json
import logging
from typing import Any
from uuid import UUID

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel, Field, ValidationError

from app.ai.qwen import QwenRealtimeSession, decode_audio_delta
from app.core.config import Settings, get_settings
from app.core.errors import AppError
from app.core.security import decode_access_token
from app.db.session import async_session_factory
from app.services.ai_memory import build_user_memory_context

router = APIRouter(tags=["realtime"])
logger = logging.getLogger(__name__)

SCENARIO_EMOTION_KEYWORDS = {
    "caring": ("难过", "伤心", "害怕", "焦虑", "痛苦", "sad", "afraid", "anxious"),
    "happy": ("太好了", "开心", "成功", "高兴", "great news", "happy", "succeeded"),
    "serious": ("必须", "底线", "严重", "认真", "must", "boundary", "serious"),
    "encouraging": ("试一试", "想试", "努力", "勇敢", "开始", "try", "brave", "start"),
}


def classify_scenario_emotion(text: str) -> str:
    normalized = text.casefold()
    for emotion, keywords in SCENARIO_EMOTION_KEYWORDS.items():
        if any(keyword in normalized for keyword in keywords):
            return emotion
    return "calm"


class ScenarioRealtimeStart(BaseModel):
    type: str
    participant_name: str = Field(min_length=1, max_length=80)
    participant_note: str = Field(default="", max_length=500)
    relationship_label: str = Field(default="", max_length=80)
    mode_title: str = Field(min_length=1, max_length=80)
    mode_guidance: str = Field(default="", max_length=800)
    language: str = Field(default="zh", pattern="^(zh|en)$")


class SessionFinished(Exception):
    pass


def build_scenario_instructions(
    start: ScenarioRealtimeStart,
    memory_context: str = "",
) -> str:
    response_language = "简体中文" if start.language == "zh" else "English"
    return (
        "你正在 SoulMark 的情景模拟中扮演一位对话对象。"
        f"你的角色名是 {start.participant_name}，关系是 {start.relationship_label or '未说明'}。"
        f"角色背景：{start.participant_note or '没有额外背景'}。"
        f"当前练习模式：{start.mode_title}。沟通目标：{start.mode_guidance or '自然地继续对话'}。"
        f"始终使用{response_language}，像真实语音通话一样自然、简洁，每次通常回答一到三句。"
        "保持角色一致，回应用户刚才说的话，不要自称语言模型，不要替真实人物作保证或预测。"
        f"可用的 SoulMark 用户记忆如下：\n{memory_context or '暂无长期记忆。'}\n"
        "只在相关时自然利用这些记忆，尤其优先考虑当前人物的关系、备注和事件时间线；"
        "不要机械复述记忆库，也不要捏造未记录的经历。"
        "这是沟通练习；若出现自伤、伤害他人或紧急危险，立即停止角色扮演并建议联系当地紧急服务或可信任的人。"
    )


async def reject(websocket: WebSocket, code: str, message: str, close_code: int) -> None:
    await websocket.accept()
    await websocket.send_json({"type": "error", "code": code, "message": message})
    await websocket.close(code=close_code)


def websocket_identity(
    websocket: WebSocket, settings: Settings
) -> tuple[bool, UUID | None]:
    authorization = websocket.headers.get("authorization", "")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        return (settings.environment != "production", None)
    try:
        return True, decode_access_token(token)
    except AppError:
        return False, None


async def receive_start(websocket: WebSocket) -> ScenarioRealtimeStart:
    raw = await asyncio.wait_for(websocket.receive_text(), timeout=10)
    payload = json.loads(raw)
    start = ScenarioRealtimeStart.model_validate(payload)
    if start.type != "session.start":
        raise ValueError("The first event must be session.start")
    return start


async def relay_client_audio(
    websocket: WebSocket,
    qwen: QwenRealtimeSession,
    settings: Settings,
) -> None:
    while True:
        message = await websocket.receive()
        if message["type"] == "websocket.disconnect":
            raise SessionFinished

        audio = message.get("bytes")
        if audio is not None:
            if (
                not audio
                or len(audio) % 2 != 0
                or len(audio) > settings.realtime_max_audio_frame_bytes
            ):
                await websocket.send_json(
                    {
                        "type": "error",
                        "code": "invalid_audio_format",
                        "message": "Audio must be non-empty signed 16-bit mono PCM.",
                        "recoverable": True,
                    }
                )
                continue
            await qwen.send_audio(audio)
            continue

        text = message.get("text")
        if text is None:
            continue
        try:
            event = json.loads(text)
        except json.JSONDecodeError:
            event = {}
        event_type = event.get("type") if isinstance(event, dict) else None
        if event_type == "response.cancel":
            await qwen.cancel_response()
        elif event_type == "session.complete":
            raise SessionFinished
        else:
            await websocket.send_json(
                {
                    "type": "error",
                    "code": "invalid_realtime_event",
                    "message": "Unsupported realtime control event.",
                    "recoverable": True,
                }
            )


async def relay_qwen_events(websocket: WebSocket, qwen: QwenRealtimeSession) -> None:
    assistant_text = ""
    emotion_sent = True
    async for event in qwen.events():
        event_type = event.get("type")
        if event_type == "response.audio.delta":
            try:
                audio = decode_audio_delta(event)
            except (ValueError, TypeError):
                audio = None
            if audio:
                await websocket.send_bytes(audio)
        elif event_type == "conversation.item.input_audio_transcription.completed":
            await send_transcript(websocket, "user.transcript.completed", event)
        elif event_type == "response.audio_transcript.delta":
            delta = event.get("delta")
            if isinstance(delta, str) and delta:
                assistant_text += delta
                if not emotion_sent and assistant_text.strip():
                    await websocket.send_json(
                        {
                            "type": "assistant.emotion",
                            "emotion": classify_scenario_emotion(assistant_text),
                        }
                    )
                    emotion_sent = True
            await send_transcript(websocket, "assistant.transcript.delta", event, "delta")
        elif event_type == "response.audio_transcript.done":
            await send_transcript(websocket, "assistant.transcript.completed", event)
        elif event_type == "input_audio_buffer.speech_started":
            await websocket.send_json({"type": "input.speech_started"})
        elif event_type == "input_audio_buffer.speech_stopped":
            await websocket.send_json({"type": "input.speech_stopped"})
        elif event_type == "response.created":
            assistant_text = ""
            emotion_sent = False
            await websocket.send_json({"type": "assistant.response_started"})
        elif event_type == "response.done":
            await websocket.send_json({"type": "assistant.response_completed"})
        elif event_type == "error":
            await websocket.send_json(
                {
                    "type": "error",
                    "code": "ai_service_error",
                    "message": "The AI voice service returned an error.",
                    "recoverable": False,
                }
            )
            raise SessionFinished

    await websocket.send_json(
        {
            "type": "error",
            "code": "ai_service_unavailable",
            "message": "The AI voice service disconnected.",
            "recoverable": False,
        }
    )
    raise SessionFinished


async def send_transcript(
    websocket: WebSocket,
    event_type: str,
    event: dict[str, Any],
    field: str = "transcript",
) -> None:
    transcript = event.get(field)
    if isinstance(transcript, str) and transcript:
        await websocket.send_json({"type": event_type, "text": transcript})


@router.websocket("/realtime/scenario")
async def scenario_realtime(websocket: WebSocket) -> None:
    settings = get_settings()
    authorized, owner_id = websocket_identity(websocket, settings)
    if not authorized:
        await reject(websocket, "not_authenticated", "Authentication is required.", 4401)
        return
    if not settings.qwen_api_key:
        await reject(
            websocket,
            "ai_not_configured",
            "The realtime AI service is not configured.",
            1011,
        )
        return

    await websocket.accept()
    qwen: QwenRealtimeSession | None = None
    try:
        start = await receive_start(websocket)
        memory_context = ""
        if owner_id is not None:
            async with async_session_factory() as session:
                memory_context = await build_user_memory_context(
                    session,
                    owner_id,
                    focus_contact_name=start.participant_name,
                )
        qwen = await QwenRealtimeSession.connect(
            settings,
            instructions=build_scenario_instructions(start, memory_context),
        )
        await websocket.send_json(
            {
                "type": "session.ready",
                "input_sample_rate_hz": settings.realtime_input_sample_rate_hz,
                "output_sample_rate_hz": settings.realtime_output_sample_rate_hz,
                "model": settings.qwen_realtime_model,
            }
        )

        client_task = asyncio.create_task(relay_client_audio(websocket, qwen, settings))
        provider_task = asyncio.create_task(relay_qwen_events(websocket, qwen))
        done, pending = await asyncio.wait(
            {client_task, provider_task},
            return_when=asyncio.FIRST_COMPLETED,
        )
        for task in pending:
            task.cancel()
        await asyncio.gather(*pending, return_exceptions=True)
        for task in done:
            task.result()
    except (WebSocketDisconnect, SessionFinished):
        pass
    except (ValidationError, json.JSONDecodeError, ValueError, TimeoutError):
        await websocket.send_json(
            {
                "type": "error",
                "code": "invalid_session_start",
                "message": "A valid session.start event is required.",
                "recoverable": False,
            }
        )
    except Exception:
        logger.exception("Realtime scenario session failed")
        await websocket.send_json(
            {
                "type": "error",
                "code": "ai_service_unavailable",
                "message": "The AI voice service is temporarily unavailable.",
                "recoverable": False,
            }
        )
    finally:
        if qwen is not None:
            await qwen.close()
        try:
            await websocket.close()
        except (RuntimeError, WebSocketDisconnect):
            pass
