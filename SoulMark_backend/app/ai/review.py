import asyncio
import base64
import importlib
import json
from typing import Any

from pydantic import ValidationError

from app.core.config import Settings
from app.core.errors import AppError
from app.schemas.activity import ReviewAnalysisRequest, ReviewAnalysisResponse


def _review_prompt(payload: ReviewAnalysisRequest, memory_context: str = "") -> str:
    output_language = "中文" if payload.language == "zh" else "English"
    source_names = {
        "scenario": "情景模拟",
        "wechat": "微信聊天",
        "manual": "手动记录",
    }
    return f"""
你是一名克制、具体、尊重用户的沟通复盘分析师。分析以下{source_names[payload.source]}记录。
对话中的“我”代表用户。只评价用户的人际关系处理和情绪沟通方式，不诊断人格或心理疾病。
除标题外，所有分析、原因、建议和事件总结都必须站在用户的第一视角，使用“我”来描述，
绝对不要用“用户”“该用户”等第三人称称呼用户。建议应写成“我可以……”而不是“用户可以……”。
必须使用{output_language}输出一个 JSON 对象，不要输出 Markdown 或额外文字，字段必须严格为：
{{
  "title": "像本人随手写下的事件标题，通常5到10个汉字，具体自然，不用分析术语",
  "score": 0到100之间的整数,
  "reason": "以我的第一视角具体说明评分原因，引用行为特征但不要大段复述原文",
  "brief_advice": "以我的第一视角写一到两句话建议",
  "detailed_advice": "以我的视角写详细建议，包含优点、改进点和下次可采用的表达",
  "related_contact_names": ["列出事件中明确出现的所有已登记人物准确姓名，没有则为空数组"],
  "event_details": "像我的随手记录，用第一人称写清发生了什么；自然具体，不分析、不评价"
}}

标题和 event_details 要像真人日记或备忘录，不要出现“该事件”“本次沟通”“体现了”
“关系得到修复”“双方进行了”等报告式、AI式表达，也不要为了完整而重复同一事实。

聊天记录：
{payload.transcript}

SoulMark 用户记忆：
{memory_context or "暂无可用的长期记忆。"}
""".strip()


def _render_text(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, list):
        items = [_render_text(item) for item in value]
        return "\n".join(f"• {item}" for item in items if item)
    if isinstance(value, dict):
        sections: list[str] = []
        for heading, body in value.items():
            rendered_body = _render_text(body)
            if rendered_body:
                sections.append(f"{heading}\n{rendered_body}")
        return "\n\n".join(sections)
    if value is None:
        return ""
    return str(value).strip()


def _normalize_analysis(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise TypeError("Review analysis must be a JSON object.")
    normalized = dict(raw)
    for field in (
        "title",
        "reason",
        "brief_advice",
        "detailed_advice",
        "transcript",
        "event_details",
    ):
        if field not in normalized and field == "transcript":
            continue
        normalized[field] = _render_text(normalized.get(field))
    if normalized.get("related_contact_name") is not None:
        normalized["related_contact_name"] = _render_text(
            normalized["related_contact_name"]
        ) or None
    names = normalized.get("related_contact_names")
    if isinstance(names, str):
        normalized["related_contact_names"] = [names.strip()] if names.strip() else []
    elif isinstance(names, list):
        normalized["related_contact_names"] = [
            rendered
            for item in names
            if (rendered := _render_text(item))
        ]
    else:
        legacy_name = normalized.get("related_contact_name")
        normalized["related_contact_names"] = [legacy_name] if legacy_name else []
    return normalized


def _response_text(response: Any) -> str:
    if getattr(response, "status_code", 200) != 200:
        raise AppError(
            "review_ai_failed",
            "The review AI service could not analyze this record.",
            502,
        )
    try:
        content = response.output.choices[0].message.content
        text = content[0]["text"] if isinstance(content, list) else content
        if not isinstance(text, str):
            raise TypeError("Model response text is not a string.")
        return text
    except (AttributeError, IndexError, KeyError, TypeError) as exc:
        raise AppError(
            "review_ai_invalid_response",
            "The review AI returned invalid data.",
            502,
        ) from exc


def _call_model(
    settings: Settings,
    *,
    model: str,
    messages: list[dict[str, Any]],
    structured: bool,
    extra_parameters: dict[str, Any] | None = None,
) -> str:
    if not settings.qwen_api_key:
        raise AppError("review_ai_unavailable", "The review AI service is not configured.", 503)

    dashscope: Any = importlib.import_module("dashscope")
    dashscope.base_http_api_url = settings.qwen_http_api_url
    parameters: dict[str, Any] = {
        "api_key": settings.qwen_api_key,
        "model": model,
        "messages": messages,
    }
    if structured:
        parameters.update(
            response_format={"type": "json_object"},
            enable_thinking=False,
        )
    if extra_parameters:
        parameters.update(extra_parameters)
    try:
        response: Any = dashscope.MultiModalConversation.call(**parameters)
    except Exception as exc:
        raise AppError(
            "review_ai_connection_failed",
            "The review AI service could not be reached.",
            502,
        ) from exc
    return _response_text(response)


def _parse_analysis(text: str) -> ReviewAnalysisResponse:
    try:
        return ReviewAnalysisResponse.model_validate(_normalize_analysis(json.loads(text)))
    except (
        TypeError,
        json.JSONDecodeError,
        ValidationError,
    ) as exc:
        raise AppError(
            "review_ai_invalid_response",
            "The review AI returned invalid data.",
            502,
        ) from exc


def _ensure_first_person(
    analysis: ReviewAnalysisResponse,
    language: str,
) -> ReviewAnalysisResponse:
    fields = ("reason", "brief_advice", "detailed_advice", "event_details")
    updates: dict[str, str | None] = {}
    for field in fields:
        value = getattr(analysis, field)
        if value is None:
            updates[field] = None
        elif language == "zh":
            updates[field] = value.replace("该用户", "我").replace("用户", "我")
        else:
            updates[field] = (
                value.replace("The user's", "My")
                .replace("the user's", "my")
                .replace("The user", "I")
                .replace("the user", "I")
            )
    return analysis.model_copy(update=updates)


def _call_qwen(
    payload: ReviewAnalysisRequest,
    settings: Settings,
    memory_context: str = "",
) -> ReviewAnalysisResponse:
    text = _call_model(
        settings,
        model=settings.qwen_review_model,
        messages=[
            {
                "role": "system",
                "content": [
                    {"text": "Return accurate, empathetic communication analysis as JSON."}
                ],
            },
            {
                "role": "user",
                "content": [{"text": _review_prompt(payload, memory_context)}],
            },
        ],
        structured=True,
    )
    analysis = _ensure_first_person(_parse_analysis(text), payload.language)
    return analysis.model_copy(update={"transcript": payload.transcript})


def _analyze_image(
    content: bytes,
    media_type: str,
    language: str,
    settings: Settings,
    memory_context: str,
) -> ReviewAnalysisResponse:
    data_url = f"data:{media_type};base64,{base64.b64encode(content).decode('ascii')}"
    payload = ReviewAnalysisRequest(
        source="wechat",
        transcript="聊天内容来自随请求提供的微信聊天截图。",
        language=language,
    )
    prompt = (
        f"{_review_prompt(payload, memory_context)}\n\n"
        "请直接读取随请求提供的聊天截图。通常右侧气泡代表用户（我），"
        "但应以截图中的明确线索为准。除了上述字段，再返回 transcript 字段，"
        "按对话顺序简洁转写截图中的聊天内容。"
    )
    text = _call_model(
        settings,
        model=settings.qwen_review_model,
        messages=[
            {
                "role": "system",
                "content": [
                    {"text": "Read the chat image and return empathetic analysis as JSON."}
                ],
            },
            {
                "role": "user",
                "content": [{"image": data_url}, {"text": prompt}],
            },
        ],
        structured=True,
    )
    result = _ensure_first_person(_parse_analysis(text), language)
    if not result.transcript:
        result = result.model_copy(
            update={
                "transcript": (
                    "微信聊天截图（AI 已读取）"
                    if language == "zh"
                    else "WeChat screenshot analyzed by AI"
                )
            }
        )
    return result


def _analyze_audio(
    content: bytes,
    language: str,
    settings: Settings,
    memory_context: str,
) -> ReviewAnalysisResponse:
    data_url = f"data:;base64,{base64.b64encode(content).decode('ascii')}"
    transcript = _call_model(
        settings,
        model=settings.qwen_review_audio_model,
        messages=[
            {
                "role": "user",
                "content": [{"audio": data_url}],
            }
        ],
        structured=False,
        extra_parameters={
            "result_format": "message",
            "asr_options": {
                "language": language,
                "enable_itn": True,
            },
        },
    ).strip()
    if not transcript:
        raise AppError(
            "review_audio_empty",
            "No speech could be recognized in the recording.",
            422,
        )
    return _call_qwen(
        ReviewAnalysisRequest(
            source="scenario",
            transcript=transcript,
            language=language,
        ),
        settings,
        memory_context,
    )


async def analyze_review(
    payload: ReviewAnalysisRequest,
    settings: Settings,
    memory_context: str = "",
) -> ReviewAnalysisResponse:
    return await asyncio.to_thread(_call_qwen, payload, settings, memory_context)


async def analyze_review_media(
    *,
    source: str,
    language: str,
    content: bytes,
    media_type: str,
    settings: Settings,
    memory_context: str = "",
) -> ReviewAnalysisResponse:
    if source == "wechat" and media_type.startswith("image/"):
        return await asyncio.to_thread(
            _analyze_image,
            content,
            media_type,
            language,
            settings,
            memory_context,
        )
    if source == "scenario" and (
        media_type.startswith("audio/")
        or media_type in {"application/octet-stream", "video/mp4"}
    ):
        return await asyncio.to_thread(
            _analyze_audio,
            content,
            language,
            settings,
            memory_context,
        )
    raise AppError(
        "review_media_type_invalid",
        "The selected file does not match the review source.",
        422,
    )
