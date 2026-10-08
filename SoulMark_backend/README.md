# SoulMark Backend

FastAPI and PostgreSQL backend for SoulMark. It includes health checks, 30-day email, phone-code,
and WeChat sessions, onboarding and profile settings, relationship contacts, practices, reviews,
dashboard statistics, and a secure realtime voice relay for scenario practice.

## Requirements

- Python 3.12 or newer
- PostgreSQL 16, or Docker with Docker Compose

## Quick Start With Docker

```bash
docker compose up --build
```

Open the interactive API documentation at [http://localhost:8000/docs](http://localhost:8000/docs). Stop the environment with `docker compose down`. Add `-v` only when you intentionally want to delete the local database volume.

## Local Python Development

Dependencies are frozen in `uv.lock` and `requirements.txt`. The recommended setup uses
[uv](https://docs.astral.sh/uv/) so every teammate gets the same Python and package versions:

```bash
uv sync --all-extras --locked
cp .env.example .env
source .venv/bin/activate
```

Alternatively, with Python 3.12 already installed, create an isolated environment and install
the hash-verified frozen requirements:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install --require-hashes -r requirements.txt
python -m pip install --no-deps -e .
cp .env.example .env
```

When dependencies in `pyproject.toml` change, regenerate both frozen files and commit them:

```bash
uv lock
uv export --locked --all-extras --no-emit-project --no-header --output-file requirements.txt
```

Start PostgreSQL, then apply migrations and run the API:

```bash
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The `0.0.0.0` bind makes the development server reachable from an iPhone on the same Wi-Fi.
Set the app's Voice Service address to the Mac's local address, such as
`http://192.168.1.10:8000`. Use HTTPS/WSS for deployed environments.

## Verification

```bash
pytest -q
ruff format --check app tests
ruff check app tests
mypy app
alembic heads
```

Tests use an isolated in-memory database for fast behavior checks. PostgreSQL remains the production database and should also be used in deployment integration tests.

## Environment Variables

All variables use the `SOULMARK_` prefix. The required production values are:

- `SOULMARK_DATABASE_URL`: PostgreSQL SQLAlchemy URL using the Psycopg driver.
- `SOULMARK_JWT_SECRET`: long random signing secret that is never committed.
- `SOULMARK_ENVIRONMENT`: `development`, `test`, or `production`.
- `SOULMARK_JWT_ACCESS_TOKEN_MINUTES`: access-token lifetime, default 43200 (30 days).
- `SOULMARK_QWEN_API_KEY`: Model Studio API key. Keep this only in the backend `.env` or secret store.
- `SOULMARK_QWEN_REALTIME_MODEL`: realtime model, default `qwen3.5-omni-plus-realtime`.
- `SOULMARK_QWEN_REVIEW_MODEL`: conversation review model, default `qwen3.7-plus`.
- `SOULMARK_QWEN_REVIEW_AUDIO_MODEL`: review transcription model, default
  `qwen3-asr-flash`.
- `SOULMARK_QWEN_HTTP_API_URL`: DashScope HTTP endpoint, default
  `https://dashscope.aliyuncs.com/api/v1`.
- `SOULMARK_REVIEW_MEDIA_MAX_BYTES`: maximum review image/audio upload size, default 7 MB.
- `SOULMARK_QWEN_VOICE`: generated voice, default `Ethan`.
- `SOULMARK_AVATAR_UPLOAD_DIR`: local avatar directory, default `uploads/avatars`.
- `SOULMARK_AVATAR_MAX_BYTES`: maximum source image size, default 5 MB.
- `SOULMARK_EVENT_IMAGE_UPLOAD_DIR`: contact-event image directory, default `uploads/events`.
- `SOULMARK_EVENT_IMAGE_MAX_BYTES`: maximum event image size, default 7 MB.
- `SOULMARK_SMS_PROVIDER`: `development`, `aliyun`, or `pnvs`.
- `SOULMARK_ALIYUN_ACCESS_KEY_ID` / `SOULMARK_ALIYUN_ACCESS_KEY_SECRET`: credentials used by
  Aliyun SMS or PNVS.
- `SOULMARK_PNVS_SIGN_NAME` / `SOULMARK_PNVS_TEMPLATE_CODE`: Aliyun phone-number verification
  settings.
- `SOULMARK_WECHAT_APP_ID` / `SOULMARK_WECHAT_APP_SECRET`: WeChat Open Platform mobile-app
  credentials.

## Current API

- `GET /health`
- `GET /health/ready`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/phone/code`
- `POST /api/v1/auth/phone/login`
- `POST /api/v1/auth/wechat/login`
- `GET /api/v1/users/me`
- `PATCH /api/v1/users/me`
- `PATCH /api/v1/users/me/tutorial`
- `GET /api/v1/contacts`
- `POST /api/v1/contacts`
- `GET /api/v1/contacts/{contact_id}`
- `PATCH /api/v1/contacts/{contact_id}`
- `DELETE /api/v1/contacts/{contact_id}`
- `POST /api/v1/contacts/{contact_id}/avatar`
- `DELETE /api/v1/contacts/{contact_id}/avatar`
- `GET /api/v1/practices`
- `POST /api/v1/practices`
- `DELETE /api/v1/practices/{practice_id}`
- `GET /api/v1/reviews`
- `POST /api/v1/reviews`
- `POST /api/v1/reviews/analyze`
- `POST /api/v1/reviews/analyze-media`
- `DELETE /api/v1/reviews/{review_id}`
- `GET /api/v1/contacts/{contact_id}/events`
- `POST /api/v1/contacts/{contact_id}/events`
- `POST /api/v1/contacts/{contact_id}/events/{event_id}/image`
- `DELETE /api/v1/contacts/{contact_id}/events/{event_id}`
- `GET /api/v1/stats`
- `WS /api/v1/realtime/scenario`

## Phone and WeChat Authentication

`SOULMARK_SMS_PROVIDER=development` does not send a real text message and accepts the fixed code
from `SOULMARK_SMS_DEVELOPMENT_CODE` (default `123456`). It is intended only for automated/local
testing, and the backend rejects this provider when `SOULMARK_ENVIRONMENT=production`.
Production can use standard Aliyun SMS (`aliyun`) or Aliyun Phone Number Verification Service
(`pnvs`). Code expiry, resend throttling, and maximum verification attempts are configurable in
`.env.example`.

The WeChat API endpoint is complete, but the iOS client still requires a registered WeChat Open
Platform mobile app and its SDK to obtain the authorization code. Secrets stay on the backend.

## Realtime Voice

The iOS app connects to `/api/v1/realtime/scenario`, sends a `session.start` JSON event, then
streams signed 16-bit mono PCM as binary WebSocket messages. Input is 16 kHz and server audio is
24 kHz. Server JSON events carry final user transcripts, streaming/final assistant transcripts,
call state, and safe error information.

During development the WebSocket is available without a login token so a phone on the same local
network can reach the Mac. Production requires a valid SoulMark Bearer token. The Qwen API key is
never sent to the app. Raw audio is relayed transiently and is not retained by this endpoint.

Scenario replies are simulations for communication practice and must not be treated as statements
or predictions from the real person being represented.

## Contact Avatars

The iOS client crops selected photos to a square, resizes them to at most 1024 pixels, and uploads
normalized JPEG data. The backend also accepts PNG uploads, validates image contents, enforces the
configured size limit, and stores normalized JPEG files. Development files are served under
`/media/avatars/`, while Docker Compose keeps them in the persistent `soulmark_avatar_uploads`
volume. Use durable object storage behind the storage service for a production deployment with
more than one backend instance.

## Next Modules

Subscriptions, push notifications, password recovery, email verification, and account
deletion should be added as separate modules while keeping the same API/service/database boundaries.

## Experience, Levels, and Inactivity (20261008_0013)

The profile growth card requires this backend release and migration `20261008_0013`.
Publishing the iOS code to GitHub does not deploy the API or migrate a production database.
Deploy in this order:

1. Back up the production database using the team's normal backup process.
2. Apply `alembic upgrade head` using the production database configuration.
3. Deploy/restart the matching API version, then verify authenticated `GET /api/v1/growth`.
4. Release the updated iOS client. Older servers make the new growth card show a retry state.

A saved review awards 30 EXP. Complete user/assistant chat turns award 5 EXP each when
saved, capped at 50 chat EXP per Asia/Singapore calendar day. Upgrade costs increase by
50 per level, starting at 100. New clients send stable `event_id` UUIDs and ordered
`messages`; retry the same content with the same ID. A changed or deleted event returns 409.
An event cannot be rewarded twice, and deleting its source activity does not remove earned EXP.
Old clients remain compatible but cannot guarantee deduplication across separate save requests.

`POST /api/v1/growth/active` settles inactivity first and records a foreground visit.
`GET /api/v1/growth` settles without marking activity. Seven inactive days are free;
from day eight, 10 EXP is deducted per day, never below zero. Levels and current titles
can drop, but highest-level badges remain unlocked. Settlement is lazy and database-locked;
no scheduled job is needed. Failed saves do not earn rewards.

The migration backfills 30 EXP per existing review and 5 per existing practice with both
transcripts, capped at 50 per original calendar day (legacy transcripts lack reliable turn
boundaries). Existing accounts start their grace period on migration day; prior inactivity
is not penalized. Completed historical backfill is tracked by the Alembic revision.

Verification: run `pytest -q`, `ruff check app tests`, and `mypy app` from this directory.
The growth suite includes file-backed SQLite concurrency tests with independent connections.
Run deployment integration checks on PostgreSQL before release; SQLite tests do not prove
PostgreSQL migration/locking behavior. Pending mobile practice saves are retained for retries
within the current signed-in app session; they are cleared on sign-out or app termination.

## New User Guide (20261008_0014)

The four-step new-user guide requires migration `20261008_0014` and the matching API release.
Deploy the backend before releasing the updated iOS client:

1. Back up the production database.
2. Run `alembic upgrade head` so existing accounts are marked complete at step 4.
3. Deploy/restart the matching API and verify authenticated `GET /api/v1/users/me` returns
   `tutorial_step` and `tutorial_completed_at`.
4. Verify `PATCH /api/v1/users/me/tutorial` accepts only the current step or the next step.
5. Release the updated iOS client.

Accounts created after the migration start at step 0. Existing accounts are completed during the
migration and are not interrupted. The server records each ordered advance through step 4 so a new
user can resume on another device. Reopening the guide from iOS Settings is local-only and does not
change the saved tutorial step or completion time.
