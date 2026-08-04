# SoulMark Backend

FastAPI and PostgreSQL backend foundation for SoulMark. The current API includes health checks, email authentication, authenticated profile management, and relationship-contact CRUD with a five-contact free limit.

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
uvicorn app.main:app --reload
```

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
- `SOULMARK_JWT_ACCESS_TOKEN_MINUTES`: access-token lifetime, default 30.

## Current API

- `GET /health`
- `GET /health/ready`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/users/me`
- `PATCH /api/v1/users/me`
- `GET /api/v1/contacts`
- `POST /api/v1/contacts`
- `GET /api/v1/contacts/{contact_id}`
- `PATCH /api/v1/contacts/{contact_id}`
- `DELETE /api/v1/contacts/{contact_id}`

## Next Modules

Conversation history, AI scenario simulation, reviews, achievements, subscriptions, uploads, and push notifications should be added as separate modules while keeping the same API/service/database boundaries.
