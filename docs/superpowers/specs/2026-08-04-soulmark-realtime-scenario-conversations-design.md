# SoulMark Realtime Scenario Conversations Design

## Goal

Add a backend-only first release of saved scenario conversations with real-time AI voice
responses. In a scenario simulation, the AI acts as a selected contact. The iOS client
connects only to the SoulMark backend, and the backend proxies the live session to Alibaba
Cloud Model Studio.

This release uses `qwen3.5-omni-plus-realtime` for real-time audio conversation. It reserves a
provider boundary for `qwen3.7-plus`, which will be used in a later release for image
understanding and relationship reviews.

## Scope

The release provides:

- owned scenario-conversation creation, listing, detail, completion, and deletion;
- real-time user audio input and streamed AI audio output over a SoulMark WebSocket;
- final text transcripts for both the user and AI;
- contact role-play based on a long-lived contact profile plus a per-session scenario and goal;
- interruption, disconnect, and upstream-failure handling; and
- deterministic automated tests through a fake AI provider.

The release does not provide relationship reviews, image upload or analysis, raw audio
retention, subscriptions, background jobs, or iOS implementation.

## Architecture

The feature follows the existing modular-monolith boundaries:

- `models` owns conversation and message persistence models.
- `schemas` owns HTTP request and response contracts.
- `services` owns conversation lifecycle, ownership, prompt construction, and message state
  transitions.
- `api/v1` owns HTTP and WebSocket transport.
- `ai` owns a provider-neutral real-time conversation interface and the Qwen adapter.

The iOS client never receives the Alibaba Cloud API key and never connects directly to Qwen.
It sends authenticated HTTP and WebSocket traffic to SoulMark. The backend validates ownership,
constructs role instructions, connects to Qwen, translates streaming events, and persists final
transcripts.

```text
iOS client <-> SoulMark FastAPI WebSocket <-> Qwen3.5-Omni-Plus-Realtime
                    |
                    +-> PostgreSQL transcript records
```

`qwen3.7-plus` is represented in configuration and the provider abstraction, but is not invoked
by this release. Keeping it out of the real-time path avoids extra latency and preserves the
speech model's emotional and prosodic information.

## Contact Persona

Contacts gain optional long-lived role-play fields for personality, speaking style, and relevant
relationship background. Each conversation supplies a scenario description and the user's
practice goal.

The service builds the model instructions from:

1. backend-owned safety and simulation rules;
2. a snapshot of the contact's name and role-play profile;
3. the current scenario; and
4. the user's practice goal.

User-authored values are delimited as background data and cannot replace backend-owned
instructions. The experience must state that the result is an AI simulation and does not predict
how the real contact will respond.

The conversation stores a persona snapshot. Deleting a contact sets the live foreign key to null
but keeps the historical conversation and its snapshot.

## Data Model

### `conversations`

- UUID primary key
- owner user foreign key with cascade delete
- nullable contact foreign key with `SET NULL` on delete
- contact name snapshot
- contact persona snapshot
- scenario description
- practice goal
- optional title
- status: `active`, `completed`, or `failed`
- nullable live connection ID and lease expiry timestamp
- created, updated, and optional completed timestamps

Every ownership query filters by both conversation ID and owner ID. A user cannot infer whether
another user's conversation exists. A live connection acquires its lease with one conditional
database update. A second process can acquire it only after the previous lease expires, so the
single-connection rule remains valid when the API runs with multiple workers and does not require
Redis.

### `messages`

- UUID primary key
- conversation foreign key with cascade delete
- role: `user` or `assistant`
- final transcript text
- status: `streaming`, `completed`, `interrupted`, or `failed`
- provider model identifier
- nullable provider response ID, unique within the conversation when present
- created and optional completed timestamps

Raw input and output audio are transient and are never stored in the database or filesystem.
Only final transcript text and operational metadata are retained. Interrupted assistant messages
may retain their confirmed partial transcript and are explicitly marked `interrupted`.

## HTTP API

All routes use the existing `/api/v1` prefix and bearer authentication.

- `POST /api/v1/conversations` creates an active scenario conversation for an owned contact.
- `GET /api/v1/conversations` lists the authenticated user's conversations, newest first.
- `GET /api/v1/conversations/{conversation_id}` returns metadata and ordered messages.
- `POST /api/v1/conversations/{conversation_id}/complete` completes an active conversation.
- `DELETE /api/v1/conversations/{conversation_id}` deletes the conversation and its messages.

Creating a conversation accepts `contact_id`, `scenario`, `practice_goal`, and an optional title.
The contact must belong to the current user. Completing an already completed conversation is
idempotent. A deleted or unowned resource produces the same not-found response.

## Realtime WebSocket Protocol

The endpoint is:

`WS /api/v1/conversations/{conversation_id}/realtime`

The upgrade request authenticates with the same bearer JWT used by HTTP endpoints. The backend
rejects unauthenticated, unowned, missing, completed, or already-connected conversations before
opening an upstream model session. A conversation permits one live connection at a time.

Control events use JSON text frames. Audio uses binary WebSocket frames so the iOS-to-backend
link does not incur Base64 expansion. The Qwen adapter performs the Base64 transformation
required by the upstream protocol.

Client control events have these payloads:

- `{"type":"audio.commit"}` when client-controlled turn detection is used;
- `{"type":"response.cancel"}` when the user interrupts the AI; and
- `{"type":"session.complete"}` when the user ends the simulation.

Every server JSON event includes a unique `event_id`. Server event payloads are:

- `session.ready`: conversation ID plus input and output PCM format and sample rates;
- `user.transcript.completed`: persisted message ID and final text;
- `assistant.transcript.delta`: response ID and incremental text;
- an assistant PCM audio chunk as each binary server frame;
- `assistant.message.completed`: persisted message ID, response ID, final text, and status;
- `assistant.message.interrupted`: persisted message ID, response ID, confirmed partial text, and
  status; and
- `error`: stable code, safe message, and a boolean indicating whether the connection can continue.

Unknown JSON event types and unexpected text payloads produce `invalid_realtime_event`. Binary
client frames are always interpreted as user PCM audio. Binary server frames are always
interpreted as assistant PCM audio. This directional rule avoids a second framing protocol.

## Realtime Data Flow

1. The user creates a conversation through HTTP.
2. The client opens the authenticated conversation WebSocket.
3. The backend validates ownership and active status, atomically acquires and periodically renews
   the database-backed single-connection lease, and creates a Qwen real-time session with
   semantic voice activity detection.
4. The client sends audio as binary frames. The backend converts and forwards it without
   persisting it.
5. Qwen emits user transcription events, assistant transcript deltas, and assistant audio
   deltas. The backend forwards live output to the client.
6. When a transcript is final, the service commits the corresponding message and then emits its
   completed event. A client is never told that a message persisted until the transaction
   succeeds.
7. On normal completion, the backend closes the upstream session, clears the lease, and marks the
   conversation completed.

On reconnect, the backend rebuilds the session instructions from the stored persona snapshot and
replays a bounded number of recent completed or interrupted text messages. It does not depend on
the lifetime of the previous Qwen connection.

## Error Handling And Recovery

Stable HTTP and WebSocket error codes include:

- `conversation_not_found` for missing or unowned conversations;
- `conversation_not_active` for a completed or failed conversation;
- `conversation_already_connected` for a second simultaneous live connection;
- `invalid_realtime_event` for an unknown or malformed control event;
- `invalid_audio_format` for an unsupported audio frame;
- `ai_service_unavailable` when the upstream model cannot be reached; and
- `message_persistence_failed` when a final transcript cannot be committed.

An upstream failure does not erase already completed messages. A streaming message becomes
`failed` if the provider disconnects before a usable final transcript. A user interruption keeps
the confirmed partial assistant transcript as `interrupted`. Unexpected client disconnects close
the upstream connection and finalize any known incomplete state; raw audio buffers are discarded.

Conversation state changes and final message writes use explicit database transactions. Error
events expose stable codes and safe messages, while provider details remain in structured server
logs.

## Configuration

New environment settings cover:

- the Alibaba Cloud Model Studio API key;
- the regional Model Studio WebSocket base URL and workspace ID;
- real-time model ID, defaulting to `qwen3.5-omni-plus-realtime`;
- analysis model ID, defaulting to `qwen3.7-plus` for later modules;
- default output voice;
- fixed mono signed 16-bit PCM input at 16 kHz, output at 24 kHz, and maximum frame size;
- live-connection lease duration and renewal interval; and
- reconnection history limits.

Secrets remain environment-only. `.env.example` documents variable names without real values.

## Testing

HTTP behavior tests cover conversation creation, list ordering, detail, idempotent completion,
deletion, contact ownership, conversation ownership, and contact deletion with retained persona
snapshots.

WebSocket tests inject a fake real-time AI provider and cover:

- JWT rejection and ownership isolation;
- binary audio forwarding without persistence;
- user transcript persistence;
- streamed assistant transcript and audio forwarding;
- final assistant transcript persistence;
- interruption and partial transcript state;
- invalid audio frames;
- duplicate live connections;
- upstream disconnects and reconnect context restoration; and
- database write failure before completion notification.

Tests never call Alibaba Cloud or consume model quota. Adapter contract tests use recorded,
sanitized provider event shapes. A new Alembic migration adds the contact persona fields,
conversation table, message table, foreign keys, indexes, and enums or check constraints. The
full pytest, Ruff, mypy, migration-head, and PostgreSQL migration checks remain required.

## Delivery Boundary

This backend release is complete when authenticated users can manage owned scenario
conversations, a fake-provider integration proves the real-time protocol and persistence rules,
and the production Qwen adapter can establish and proxy a configured
`qwen3.5-omni-plus-realtime` session. A separate implementation cycle will connect the iOS client
and add `qwen3.7-plus` image understanding and relationship-review workflows.
