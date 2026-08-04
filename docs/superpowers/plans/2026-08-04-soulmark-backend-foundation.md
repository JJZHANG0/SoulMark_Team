# SoulMark Backend Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable FastAPI and PostgreSQL backend foundation with authentication, profile management, relationship-contact CRUD, and a server-enforced five-contact free limit.

**Architecture:** Create a modular monolith under `SoulMark_backend/app`. API routers translate HTTP requests into service calls, services own business rules, and SQLAlchemy repositories persist data through injected asynchronous sessions. Alembic owns schema changes and Docker Compose provides a reproducible local PostgreSQL environment.

**Tech Stack:** Python 3.12+, FastAPI, Pydantic Settings, SQLAlchemy 2 async ORM, Psycopg 3, Alembic, PyJWT, pwdlib with Argon2, pytest, HTTPX, Ruff, mypy, Docker Compose, PostgreSQL 16.

## Global Constraints

- All business endpoints use the `/api/v1` prefix.
- The iOS app communicates only with the HTTP API and never connects directly to PostgreSQL.
- Secrets and database URLs come from environment variables; `.env` is ignored and `.env.example` is committed.
- The free plan allows five contacts and the service layer rejects the sixth.
- Existing iOS changes remain intact and local Xcode signing changes are excluded from backend commits.
- AI, chat, payments, Redis, workers, uploads, and production cloud selection remain deferred.

## Planned File Structure

- `SoulMark_backend/pyproject.toml`: dependencies and tool configuration.
- `SoulMark_backend/app/main.py`: FastAPI application factory and router composition.
- `SoulMark_backend/app/core/config.py`: typed environment settings.
- `SoulMark_backend/app/core/errors.py`: stable application errors and HTTP mapping.
- `SoulMark_backend/app/core/security.py`: password hashing and JWT operations.
- `SoulMark_backend/app/db/base.py`: SQLAlchemy declarative base and model registration.
- `SoulMark_backend/app/db/session.py`: async engine and session dependency.
- `SoulMark_backend/app/models/user.py`: user persistence model.
- `SoulMark_backend/app/models/contact.py`: owned contact persistence model.
- `SoulMark_backend/app/schemas/`: request and response contracts.
- `SoulMark_backend/app/services/`: authentication, profile, and contact business rules.
- `SoulMark_backend/app/api/v1/`: versioned routers and authentication dependency.
- `SoulMark_backend/alembic/`: migration environment and initial schema migration.
- `SoulMark_backend/tests/`: isolated behavior tests.
- `SoulMark_backend/docker-compose.yml`: local API and PostgreSQL services.
- `SoulMark_backend/Dockerfile`: API container image.
- `SoulMark_backend/README.md`: setup and operating instructions.

---

### Task 1: Runnable Application Foundation

**Files:**
- Create: `SoulMark_backend/pyproject.toml`
- Create: `SoulMark_backend/app/__init__.py`
- Create: `SoulMark_backend/app/main.py`
- Create: `SoulMark_backend/app/core/config.py`
- Create: `SoulMark_backend/app/db/base.py`
- Create: `SoulMark_backend/app/db/session.py`
- Create: `SoulMark_backend/tests/conftest.py`
- Create: `SoulMark_backend/tests/test_health.py`

**Interfaces:**
- Produces: `create_app() -> FastAPI`, `Settings`, `get_settings() -> Settings`, `get_db() -> AsyncIterator[AsyncSession]`.
- Consumes: `DATABASE_URL`, `JWT_SECRET`, and application environment variables.

- [ ] **Step 1: Write the failing health test**

```python
def test_health_reports_service_name(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "soulmark-backend"}
```

- [ ] **Step 2: Run it and verify the application package is missing**

Run: `cd SoulMark_backend && uv run pytest tests/test_health.py -q`

Expected: FAIL because `app.main` or `create_app` does not exist.

- [ ] **Step 3: Implement settings, sessions, and application factory**

```python
def create_app() -> FastAPI:
    app = FastAPI(title="SoulMark API", version="0.1.0")

    @app.get("/health", tags=["health"])
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "soulmark-backend"}

    return app
```

- [ ] **Step 4: Run health test, Ruff, and mypy**

Run: `cd SoulMark_backend && uv run pytest tests/test_health.py -q && uv run ruff check app tests && uv run mypy app`

Expected: one passing test and zero static-analysis errors.

- [ ] **Step 5: Commit the foundation**

```bash
git add SoulMark_backend/pyproject.toml SoulMark_backend/app SoulMark_backend/tests
git commit -m "feat: add FastAPI backend foundation"
```

### Task 2: Authentication And Stable Errors

**Files:**
- Create: `SoulMark_backend/app/core/errors.py`
- Create: `SoulMark_backend/app/core/security.py`
- Create: `SoulMark_backend/app/models/user.py`
- Create: `SoulMark_backend/app/schemas/auth.py`
- Create: `SoulMark_backend/app/schemas/user.py`
- Create: `SoulMark_backend/app/services/auth.py`
- Create: `SoulMark_backend/app/api/dependencies.py`
- Create: `SoulMark_backend/app/api/v1/auth.py`
- Create: `SoulMark_backend/tests/test_auth.py`
- Modify: `SoulMark_backend/app/main.py`
- Modify: `SoulMark_backend/app/db/base.py`

**Interfaces:**
- Produces: `hash_password(password: str) -> str`, `verify_password(password: str, password_hash: str) -> bool`, `create_access_token(subject: UUID) -> str`, `get_current_user(...) -> User`, `AuthService.register(...)`, and `AuthService.authenticate(...)`.
- Consumes: `AsyncSession`, JWT settings, user schemas, and `AppError(code, message, status_code)`.

- [ ] **Step 1: Write failing registration and authentication tests**

```python
def test_register_login_and_access_private_endpoint(client):
    payload = {"email": "owner@example.com", "password": "StrongPass123!", "display_name": "Owner"}
    registered = client.post("/api/v1/auth/register", json=payload)
    assert registered.status_code == 201
    login = client.post("/api/v1/auth/login", json={"email": payload["email"], "password": payload["password"]})
    assert login.status_code == 200
    assert login.json()["access_token"]


def test_duplicate_email_returns_stable_conflict(client):
    payload = {"email": "same@example.com", "password": "StrongPass123!", "display_name": "Same"}
    assert client.post("/api/v1/auth/register", json=payload).status_code == 201
    response = client.post("/api/v1/auth/register", json=payload)
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_already_registered"
```

- [ ] **Step 2: Run tests and verify missing auth routes fail**

Run: `cd SoulMark_backend && uv run pytest tests/test_auth.py -q`

Expected: FAIL with 404 responses for auth routes.

- [ ] **Step 3: Implement password hashing, JWT, user model, service, routes, and error mapping**

```python
class AppError(Exception):
    def __init__(self, code: str, message: str, status_code: int) -> None:
        self.code = code
        self.message = message
        self.status_code = status_code


def create_access_token(subject: UUID) -> str:
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_access_token_minutes)
    return jwt.encode({"sub": str(subject), "exp": expires_at}, settings.jwt_secret, algorithm="HS256")
```

- [ ] **Step 4: Run authentication tests and all existing checks**

Run: `cd SoulMark_backend && uv run pytest -q && uv run ruff check app tests && uv run mypy app`

Expected: all tests pass and static analysis is clean.

- [ ] **Step 5: Commit authentication**

```bash
git add SoulMark_backend/app SoulMark_backend/tests
git commit -m "feat: add API authentication"
```

### Task 3: Authenticated User Profile

**Files:**
- Create: `SoulMark_backend/app/services/users.py`
- Create: `SoulMark_backend/app/api/v1/users.py`
- Create: `SoulMark_backend/tests/test_users.py`
- Modify: `SoulMark_backend/app/schemas/user.py`
- Modify: `SoulMark_backend/app/main.py`

**Interfaces:**
- Produces: `GET /api/v1/users/me`, `PATCH /api/v1/users/me`, `UserService.update_profile(user, payload) -> User`.
- Consumes: authenticated `User`, `AsyncSession`, and `UserUpdate` with optional profile fields.

- [ ] **Step 1: Write failing profile read and update tests**

```python
def test_user_can_read_and_update_own_profile(client, auth_headers):
    current = client.get("/api/v1/users/me", headers=auth_headers)
    assert current.status_code == 200
    updated = client.patch(
        "/api/v1/users/me",
        headers=auth_headers,
        json={"display_name": "New Name", "preferred_language": "en", "appearance": "dark"},
    )
    assert updated.status_code == 200
    assert updated.json()["display_name"] == "New Name"
    assert "password_hash" not in updated.json()
```

- [ ] **Step 2: Run the profile test and verify the missing route fails**

Run: `cd SoulMark_backend && uv run pytest tests/test_users.py -q`

Expected: FAIL with a 404 response.

- [ ] **Step 3: Implement profile schemas, service, and routes**

```python
class UserUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=100)
    preferred_language: Literal["zh", "en"] | None = None
    gender: Literal["male", "female", "unspecified"] | None = None
    appearance: Literal["auto", "light", "dark"] | None = None
```

- [ ] **Step 4: Run the full suite and static checks**

Run: `cd SoulMark_backend && uv run pytest -q && uv run ruff check app tests && uv run mypy app`

Expected: all tests and checks pass.

- [ ] **Step 5: Commit profile management**

```bash
git add SoulMark_backend/app SoulMark_backend/tests/test_users.py
git commit -m "feat: add user profile API"
```

### Task 4: Owned Contacts And Free Limit

**Files:**
- Create: `SoulMark_backend/app/models/contact.py`
- Create: `SoulMark_backend/app/schemas/contact.py`
- Create: `SoulMark_backend/app/services/contacts.py`
- Create: `SoulMark_backend/app/api/v1/contacts.py`
- Create: `SoulMark_backend/tests/test_contacts.py`
- Modify: `SoulMark_backend/app/db/base.py`
- Modify: `SoulMark_backend/app/models/user.py`
- Modify: `SoulMark_backend/app/main.py`

**Interfaces:**
- Produces: `ContactService.create/list/get/update/delete`, owned contact CRUD routes, and `contact_limit_reached` business error.
- Consumes: authenticated owner UUID, `AsyncSession`, `ContactCreate`, and `ContactUpdate`.

- [ ] **Step 1: Write failing ownership, CRUD, and sixth-contact tests**

```python
def test_user_can_create_update_and_delete_owned_contact(client, auth_headers):
    created = client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={"name": "Wren", "relationship_label": "Friend", "strength": 80},
    )
    assert created.status_code == 201
    contact_id = created.json()["id"]
    updated = client.patch(f"/api/v1/contacts/{contact_id}", headers=auth_headers, json={"strength": 95})
    assert updated.json()["strength"] == 95
    assert client.delete(f"/api/v1/contacts/{contact_id}", headers=auth_headers).status_code == 204


def test_sixth_contact_is_rejected(client, auth_headers):
    for index in range(5):
        assert client.post(
            "/api/v1/contacts",
            headers=auth_headers,
            json={"name": f"Person {index}", "relationship_label": "Friend", "strength": 50},
        ).status_code == 201
    response = client.post(
        "/api/v1/contacts",
        headers=auth_headers,
        json={"name": "Sixth", "relationship_label": "Friend", "strength": 50},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "contact_limit_reached"
```

- [ ] **Step 2: Run contact tests and verify missing routes fail**

Run: `cd SoulMark_backend && uv run pytest tests/test_contacts.py -q`

Expected: FAIL with 404 responses.

- [ ] **Step 3: Implement contact model, schemas, ownership queries, routes, and limit rule**

```python
FREE_CONTACT_LIMIT = 5


async def create(self, owner_id: UUID, payload: ContactCreate) -> Contact:
    count = await self.session.scalar(select(func.count(Contact.id)).where(Contact.owner_id == owner_id))
    if count is not None and count >= FREE_CONTACT_LIMIT:
        raise AppError("contact_limit_reached", "The free plan supports up to five contacts.", 400)
    contact = Contact(owner_id=owner_id, **payload.model_dump())
    self.session.add(contact)
    await self.session.commit()
    await self.session.refresh(contact)
    return contact
```

- [ ] **Step 4: Run full tests, Ruff, and mypy**

Run: `cd SoulMark_backend && uv run pytest -q && uv run ruff check app tests && uv run mypy app`

Expected: CRUD, ownership, limit, auth, profile, and health behaviors pass.

- [ ] **Step 5: Commit contacts**

```bash
git add SoulMark_backend/app SoulMark_backend/tests/test_contacts.py
git commit -m "feat: add relationship contacts API"
```

### Task 5: PostgreSQL Migration, Containers, And Operator Documentation

**Files:**
- Create: `SoulMark_backend/alembic.ini`
- Create: `SoulMark_backend/alembic/env.py`
- Create: `SoulMark_backend/alembic/script.py.mako`
- Create: `SoulMark_backend/alembic/versions/20260804_0001_initial.py`
- Create: `SoulMark_backend/.env.example`
- Create: `SoulMark_backend/.gitignore`
- Create: `SoulMark_backend/Dockerfile`
- Create: `SoulMark_backend/docker-compose.yml`
- Create: `SoulMark_backend/README.md`
- Create: `SoulMark_backend/tests/test_migrations.py`

**Interfaces:**
- Produces: `alembic upgrade head`, API/PostgreSQL Docker services, documented local workflow, and readiness endpoint.
- Consumes: registered SQLAlchemy metadata, `DATABASE_URL`, and PostgreSQL health checks.

- [ ] **Step 1: Write a failing migration smoke test**

```python
def test_alembic_has_single_head():
    config = Config("alembic.ini")
    script = ScriptDirectory.from_config(config)
    assert len(script.get_heads()) == 1
```

- [ ] **Step 2: Run migration test and verify configuration is missing**

Run: `cd SoulMark_backend && uv run pytest tests/test_migrations.py -q`

Expected: FAIL because `alembic.ini` does not exist.

- [ ] **Step 3: Add migration environment, initial schema, containers, environment example, and README**

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: soulmark
      POSTGRES_USER: soulmark
      POSTGRES_PASSWORD: soulmark_local
  api:
    build: .
    command: sh -c "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"
    depends_on:
      db:
        condition: service_healthy
```

- [ ] **Step 4: Verify every deliverable**

Run: `cd SoulMark_backend && uv run pytest -q`

Run: `cd SoulMark_backend && uv run ruff format --check app tests && uv run ruff check app tests && uv run mypy app`

Run: `cd SoulMark_backend && uv run alembic heads && docker compose config -q`

Expected: all tests pass, one Alembic head is printed, static checks pass, and Compose validates.

- [ ] **Step 5: Commit backend delivery files**

```bash
git add SoulMark_backend
git commit -m "build: add PostgreSQL development environment"
```

### Task 6: Repository Integration And Push

**Files:**
- Review: all files under `SoulMark_backend/`
- Review: existing tracked iOS modifications
- Exclude: local-only changes in `SoulMark.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: verified commits pushed to `origin/main`.
- Consumes: a clean backend test result and current remote branch state.

- [ ] **Step 1: Fetch remote state and inspect divergence**

Run: `git fetch origin && git status --short && git log --oneline --decorate --graph -12 --all`

Expected: local commits are based on or safely reconcilable with `origin/main`; no user changes are overwritten.

- [ ] **Step 2: Re-run backend verification on the exact tree to push**

Run: `cd SoulMark_backend && uv run pytest -q && uv run ruff format --check app tests && uv run ruff check app tests && uv run mypy app && uv run alembic heads`

Expected: exit code 0 with no failures.

- [ ] **Step 3: Verify repository diff and commit only intended source changes**

Run: `git diff --check && git status --short`

Expected: no whitespace errors; Xcode signing changes remain unstaged.

- [ ] **Step 4: Push without force**

Run: `git push origin main`

Expected: `main -> main` succeeds. If rejected because the remote advanced, fetch and reconcile without force-pushing or discarding local work.
