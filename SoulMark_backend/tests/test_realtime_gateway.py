import asyncio
import base64
from collections.abc import AsyncIterator
from typing import Any

from fastapi.testclient import TestClient

from app.ai.qwen import QwenRealtimeSession
from app.api.v1 import realtime as realtime_api
from app.core.config import Settings
from app.main import create_app


class FakeRealtimeSession:
    def __init__(self) -> None:
        self.received_audio: list[bytes] = []
        self.cancelled = False
        self.closed = False

    async def send_audio(self, pcm: bytes) -> None:
        self.received_audio.append(pcm)

    async def cancel_response(self) -> None:
        self.cancelled = True

    async def events(self) -> AsyncIterator[dict[str, Any]]:
        yield {
            "type": "conversation.item.input_audio_transcription.completed",
            "transcript": "你好",
        }
        yield {"type": "response.audio_transcript.delta", "delta": "你好呀"}
        yield {
            "type": "response.audio.delta",
            "delta": base64.b64encode(b"assistant-pcm").decode(),
        }
        yield {"type": "response.audio_transcript.done", "transcript": "你好呀"}
        await asyncio.Event().wait()

    async def close(self) -> None:
        self.closed = True


def test_realtime_gateway_relays_binary_audio_and_transcripts(monkeypatch: Any) -> None:
    fake_session = FakeRealtimeSession()

    async def fake_connect(
        cls: type[QwenRealtimeSession],
        settings: Settings,
        instructions: str,
        connect_callable: Any = None,
    ) -> FakeRealtimeSession:
        assert "Wren" in instructions
        return fake_session

    monkeypatch.setattr(
        realtime_api,
        "get_settings",
        lambda: Settings(environment="test", qwen_api_key="test-key"),
    )
    monkeypatch.setattr(QwenRealtimeSession, "connect", classmethod(fake_connect))

    with TestClient(create_app()) as client:
        with client.websocket_connect("/api/v1/realtime/scenario") as socket:
            socket.send_json(
                {
                    "type": "session.start",
                    "participant_name": "Wren",
                    "participant_note": "朋友",
                    "relationship_label": "挚友",
                    "mode_title": "冲突沟通",
                    "mode_guidance": "先说事实",
                    "language": "zh",
                }
            )
            assert socket.receive_json()["type"] == "session.ready"
            socket.send_bytes(b"\x00\x00")
            assert socket.receive_json() == {"type": "user.transcript.completed", "text": "你好"}
            assert socket.receive_json() == {"type": "assistant.transcript.delta", "text": "你好呀"}
            assert socket.receive_bytes() == b"assistant-pcm"
            assert socket.receive_json() == {
                "type": "assistant.transcript.completed",
                "text": "你好呀",
            }
            socket.send_json({"type": "session.complete"})

    assert fake_session.received_audio == [b"\x00\x00"]
    assert fake_session.closed


def test_production_realtime_requires_bearer_token(monkeypatch: Any) -> None:
    monkeypatch.setattr(
        realtime_api,
        "get_settings",
        lambda: Settings(environment="production", qwen_api_key="test-key"),
    )

    with TestClient(create_app()) as client:
        with client.websocket_connect("/api/v1/realtime/scenario") as socket:
            assert socket.receive_json()["code"] == "not_authenticated"
