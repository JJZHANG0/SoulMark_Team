import asyncio
import base64
import importlib
import json
from typing import Any

from pydantic import ValidationError

from app.core.config import Settings
from app.core.errors import AppError
from app.schemas.activity import (
    RelationshipProfile,
    RelationshipSignal,
    ReviewAnalysisRequest,
    ReviewAnalysisResponse,
)


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
  "relationship_signals": [
    {{
      "contact_name": "对应的已登记人物准确姓名",
      "trust_delta": -1到1之间，表示这件事让信任降低或增加多少,
      "emotional_depth_delta": -1到1之间，表示情感理解和袒露的变化,
      "reciprocity_delta": -1到1之间，表示双方投入和回应是否平衡,
      "support_delta": -1到1之间，表示支持、照顾和可靠性的变化,
      "confidence": 0到1之间,
      "explanation": "一句具体说明，只依据记录中真实发生的行为"
    }}
  ],
  "event_details": "像我的随手记录，用第一人称写清发生了什么；自然具体，不分析、不评价"
}}

relationship_signals 必须为每一位 related_contact_names 中的人分别给出，不要直接决定亲密度总分。
普通联系应接近 0；只有明确的支持、袒露、失信、伤害或有效修复才产生较明显变化。
发生冲突不一定降低全部维度：坦诚表达和有效修复可以提升理解或信任。
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
    signals = normalized.get("relationship_signals")
    valid_signals: list[dict[str, Any]] = []
    if isinstance(signals, list):
        for signal in signals:
            try:
                valid_signals.append(
                    RelationshipSignal.model_validate(signal).model_dump()
                )
            except ValidationError:
                continue
    normalized["relationship_signals"] = valid_signals
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


def _call_relationship_signal(
    *,
    contact_name: str,
    relationship_label: str,
    current_strength: int,
    contact_memory: str,
    title: str,
    details: str,
    settings: Settings,
) -> RelationshipSignal:
    prompt = f"""
你正在为 SoulMark 分析一条已经由用户记录的人际事件。
只提取这件事对关系的变化信号，不直接决定亲密度总分，不评价人格，也不要补写未发生的事情。
普通日常事件应接近 0；明确支持、袒露、失信、伤害或有效修复才产生明显变化。
冲突不一定让全部维度下降：坦诚沟通与有效修复可以提升理解或信任。

人物：{contact_name}
关系：{relationship_label}
当前亲密度：{current_strength}/100
已有关系记忆：{contact_memory or "暂无"}
事件标题：{title}
事件详情：{details}

只返回 JSON：
{{
  "contact_name": "{contact_name}",
  "trust_delta": -1到1之间,
  "emotional_depth_delta": -1到1之间,
  "reciprocity_delta": -1到1之间,
  "support_delta": -1到1之间,
  "confidence": 0到1之间,
  "explanation": "一句具体、克制的依据说明"
}}
""".strip()
    text = _call_model(
        settings,
        model=settings.qwen_review_model,
        messages=[
            {
                "role": "system",
                "content": [{"text": "Extract one relationship signal as JSON."}],
            },
            {"role": "user", "content": [{"text": prompt}]},
        ],
        structured=True,
    )
    try:
        raw = json.loads(text)
        if isinstance(raw, dict):
            raw["contact_name"] = contact_name
        return RelationshipSignal.model_validate(raw)
    except (json.JSONDecodeError, TypeError, ValidationError) as exc:
        raise AppError(
            "relationship_signal_invalid",
            "The relationship signal could not be analyzed.",
            502,
        ) from exc


async def analyze_relationship_event(
    *,
    contact_name: str,
    relationship_label: str,
    current_strength: int,
    contact_memory: str,
    title: str,
    details: str,
    settings: Settings,
) -> RelationshipSignal:
    return await asyncio.to_thread(
        _call_relationship_signal,
        contact_name=contact_name,
        relationship_label=relationship_label,
        current_strength=current_strength,
        contact_memory=contact_memory,
        title=title,
        details=details,
        settings=settings,
    )


def _call_relationship_profile(
    *,
    contact_name: str,
    relationship_label: str,
    contact_memory: str,
    events_text: str,
    reviews_text: str,
    settings: Settings,
) -> RelationshipProfile:
    prompt = f"""
你正在根据用户长期记录的完整历史，评估用户与一个人物当前的关系亲密度。
只依据给出的事件和沟通复盘，不根据“好友、家人”等关系标签直接赠送分数，不补写事实。
四项均为0到100的整数：50代表证据中性；高分必须有持续且明确的正向证据，低分必须有明确负向证据。
记录数量刚达到门槛时也应保持克制，避免仅凭单次强烈事件给出极端分数。

人物：{contact_name}
关系标签（仅作语境，不作为初始分）：{relationship_label}
人物记忆：{contact_memory or "暂无"}

事件时间线：
{events_text}

相关沟通复盘：
{reviews_text or "暂无"}

只返回 JSON：
{{
  "trust_score": 0到100的整数,
  "emotional_depth_score": 0到100的整数,
  "reciprocity_score": 0到100的整数,
  "support_score": 0到100的整数,
  "explanation": "简要说明四项判断所依据的长期行为证据"
}}
""".strip()
    text = _call_model(
        settings,
        model=settings.qwen_review_model,
        messages=[
            {
                "role": "system",
                "content": [
                    {
                        "text": (
                            "Evaluate a relationship profile from longitudinal "
                            "evidence as JSON."
                        )
                    }
                ],
            },
            {"role": "user", "content": [{"text": prompt}]},
        ],
        structured=True,
    )
    try:
        return RelationshipProfile.model_validate(json.loads(text))
    except (json.JSONDecodeError, TypeError, ValidationError) as exc:
        raise AppError(
            "relationship_profile_invalid",
            "The relationship profile could not be analyzed.",
            502,
        ) from exc


async def analyze_relationship_profile(
    *,
    contact_name: str,
    relationship_label: str,
    contact_memory: str,
    events_text: str,
    reviews_text: str,
    settings: Settings,
) -> RelationshipProfile:
    return await asyncio.to_thread(
        _call_relationship_profile,
        contact_name=contact_name,
        relationship_label=relationship_label,
        contact_memory=contact_memory,
        events_text=events_text,
        reviews_text=reviews_text,
        settings=settings,
    )


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
