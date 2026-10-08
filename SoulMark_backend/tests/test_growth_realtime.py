import pytest

from app.api.v1.realtime import SessionFinished, relay_qwen_events


@pytest.mark.parametrize("status,expected", [("completed", 1), ("cancelled", 0), ("failed", 0)])
async def test_only_successful_response_confirms_reward_turn(status, expected):
    class Socket:
        def __init__(self):
            self.sent = []

        async def send_json(self, event):
            self.sent.append(event)

    class Stream:
        async def events(self):
            yield {"type": "response.created", "response": {"id": "r1"}}
            yield {
                "type": "response.audio_transcript.done",
                "response_id": "r1",
                "transcript": "Hello",
            }
            yield {"type": "response.done", "response": {"id": "r1", "status": status}}
            yield {"type": "response.done", "response": {"id": "r1", "status": status}}

    socket = Socket()
    with pytest.raises(SessionFinished):
        await relay_qwen_events(socket, Stream())
    confirmations = [e for e in socket.sent if e["type"] == "assistant.turn.completed"]
    assert len(confirmations) == expected
    if expected:
        assert confirmations[0]["text"] == "Hello"
        assert confirmations[0]["response_id"] == "r1"
