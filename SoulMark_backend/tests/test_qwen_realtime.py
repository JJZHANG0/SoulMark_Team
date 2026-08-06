import base64
import json
import ssl
from collections.abc import AsyncIterator
from typing import Any

from app.ai.qwen import QwenRealtimeSession, decode_audio_delta
from app.api.v1.realtime import ScenarioRealtimeStart, build_scenario_instructions
from app.core.config import Settings


class FakeTransport:
    def __init__(self, incoming: list[dict[str, Any]] | None = None) -> None:
        self.sent: list[dict[str, Any]] = []
        self.incoming = incoming or []
        self.closed = False
        self.events_read = 0

    async def send(self, message: str) -> None:
        self.sent.append(json.loads(message))

    async def close(self) -> None:
        self.closed = True

    async def _events(self) -> AsyncIterator[str | bytes]:
        for event in self.incoming:
            self.events_read += 1
            yield json.dumps(event)

    def __aiter__(self) -> AsyncIterator[str | bytes]:
        return self._events()


async def test_qwen_session_configures_and_sends_audio() -> None:
    transport = FakeTransport([{"type": "session.updated"}])

    async def fake_connect(*args: Any, **kwargs: Any) -> FakeTransport:
        assert "model=qwen3.5-omni-plus-realtime" in args[0]
        assert kwargs["additional_headers"] == {"Authorization": "Bearer test-key"}
        assert kwargs["proxy"] is None
        assert isinstance(kwargs["ssl"], ssl.SSLContext)
        return transport

    settings = Settings(
        qwen_api_key="test-key",
        qwen_workspace_id="ws-test",
        qwen_region="cn-beijing",
    )
    session = await QwenRealtimeSession.connect(
        settings,
        "system instructions",
        connect_callable=fake_connect,
    )
    assert transport.events_read == 1
    await session.send_audio(b"\x00\x01")
    await session.cancel_response()

    assert transport.sent[0] == {
        "type": "session.update",
        "session": {
            "modalities": ["text", "audio"],
            "voice": "Ethan",
            "input_audio_format": "pcm",
            "output_audio_format": "pcm",
            "instructions": "system instructions",
            "turn_detection": {"type": "semantic_vad"},
            "input_audio_transcription": {"model": "qwen3-asr-flash-realtime"},
        },
    }
    assert transport.sent[1] == {
        "type": "input_audio_buffer.append",
        "audio": base64.b64encode(b"\x00\x01").decode("ascii"),
    }
    assert transport.sent[2] == {"type": "response.cancel"}


def test_qwen_realtime_url_uses_workspace_region() -> None:
    settings = Settings(
        _env_file=None,
        qwen_workspace_id="ws-test",
        qwen_region="cn-beijing",
    )

    assert settings.qwen_realtime_base_url == (
        "wss://ws-test.cn-beijing.maas.aliyuncs.com/api-ws/v1/realtime"
    )


def test_audio_delta_decodes_pcm() -> None:
    assert (
        decode_audio_delta(
            {"type": "response.audio.delta", "delta": base64.b64encode(b"pcm").decode()}
        )
        == b"pcm"
    )
    assert decode_audio_delta({"type": "response.done"}) is None


def test_scenario_prompt_contains_role_and_safety_boundary() -> None:
    start = ScenarioRealtimeStart(
        type="session.start",
        participant_name="Wren",
        participant_note="一位值得信任的朋友",
        relationship_label="朋友",
        mode_title="冲突沟通",
        mode_guidance="先说事实，再说感受",
        language="zh",
    )

    prompt = build_scenario_instructions(start)

    assert "Wren" in prompt
    assert "冲突沟通" in prompt
    assert "不要替真实人物作保证或预测" in prompt
