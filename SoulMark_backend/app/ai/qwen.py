import asyncio
import base64
import json
import ssl
from collections.abc import AsyncIterator, Callable
from typing import Any, Protocol
from urllib.parse import urlencode

import certifi
from websockets.asyncio.client import ClientConnection, connect

from app.core.config import Settings


class RealtimeTransport(Protocol):
    async def send(self, message: str) -> None: ...

    def __aiter__(self) -> AsyncIterator[str | bytes]: ...

    async def close(self) -> None: ...


ConnectCallable = Callable[..., Any]


class QwenRealtimeSession:
    def __init__(self, transport: RealtimeTransport, settings: Settings) -> None:
        self._transport = transport
        self._events_iterator = transport.__aiter__()
        self._settings = settings

    @classmethod
    async def connect(
        cls,
        settings: Settings,
        instructions: str,
        connect_callable: ConnectCallable = connect,
    ) -> "QwenRealtimeSession":
        if not settings.qwen_api_key:
            raise RuntimeError("Qwen realtime is not configured")

        query = urlencode({"model": settings.qwen_realtime_model})
        ssl_context = ssl.create_default_context(cafile=certifi.where())
        transport: ClientConnection = await connect_callable(
            f"{settings.qwen_realtime_base_url}?{query}",
            additional_headers={"Authorization": f"Bearer {settings.qwen_api_key}"},
            max_size=8 * 1024 * 1024,
            proxy=None,
            ssl=ssl_context,
        )
        session = cls(transport, settings)
        await session._send(
            {
                "type": "session.update",
                "session": {
                    "modalities": ["text", "audio"],
                    "voice": settings.qwen_voice,
                    "input_audio_format": "pcm",
                    "output_audio_format": "pcm",
                    "instructions": instructions,
                    "turn_detection": {"type": "semantic_vad"},
                    "input_audio_transcription": {"model": settings.qwen_input_transcription_model},
                },
            }
        )
        await session._wait_until_ready()
        return session

    async def send_audio(self, pcm: bytes) -> None:
        await self._send(
            {
                "type": "input_audio_buffer.append",
                "audio": base64.b64encode(pcm).decode("ascii"),
            }
        )

    async def cancel_response(self) -> None:
        await self._send({"type": "response.cancel"})

    async def events(self) -> AsyncIterator[dict[str, Any]]:
        async for raw_message in self._events_iterator:
            if isinstance(raw_message, bytes):
                continue
            payload = json.loads(raw_message)
            if isinstance(payload, dict):
                yield payload

    async def _wait_until_ready(self) -> None:
        async with asyncio.timeout(10):
            async for raw_message in self._events_iterator:
                if isinstance(raw_message, bytes):
                    continue
                payload = json.loads(raw_message)
                if not isinstance(payload, dict):
                    continue
                event_type = payload.get("type")
                if event_type == "session.updated":
                    return
                if event_type == "error":
                    message = payload.get("error", {}).get("message") or payload.get("message")
                    raise RuntimeError(message or "Qwen realtime session update failed")
        raise TimeoutError("Qwen realtime session did not become ready")

    async def close(self) -> None:
        await self._transport.close()

    async def _send(self, payload: dict[str, Any]) -> None:
        await self._transport.send(json.dumps(payload, ensure_ascii=False))


def decode_audio_delta(event: dict[str, Any]) -> bytes | None:
    if event.get("type") != "response.audio.delta":
        return None
    delta = event.get("delta")
    if not isinstance(delta, str):
        return None
    return base64.b64decode(delta, validate=True)
