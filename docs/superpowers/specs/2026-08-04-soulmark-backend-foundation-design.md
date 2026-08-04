# SoulMark Backend Foundation Design

## Goal

Create a production-oriented backend foundation inside `SoulMark_backend` that can grow with SoulMark without introducing services the current product does not need. The first release proves the architecture through authentication, user profile, and relationship-contact APIs.

## Architecture

The backend is a modular monolith built with Python, FastAPI, SQLAlchemy 2, Alembic, and PostgreSQL. The iOS app communicates only with versioned HTTPS JSON APIs. Business modules remain separate inside one deployable service so chat, AI simulation, reviews, achievements, and membership can be added later without starting with microservices.

The initial package boundaries are:

- `api`: versioned routers and HTTP request handling.
- `core`: settings, security helpers, application errors, and logging.
- `db`: SQLAlchemy base, sessions, models, and migration integration.
- `schemas`: validated request and response models.
- `services`: business rules independent of HTTP details.
- `tests`: API and service behavior tests.

## Initial Features

### Health

- `GET /health` reports application availability.
- `GET /health/ready` verifies that PostgreSQL is reachable.

### Authentication

- Register with email and password.
- Login with email and password.
- Store only a password hash.
- Return a signed, expiring JWT access token.
- Protect private endpoints with bearer authentication.
- Keep authentication internals replaceable so Sign in with Apple can be added later.

### User Profile

- Read the authenticated user's profile.
- Update display name, preferred language, gender/theme preference fields, and appearance preference fields.
- Never expose password hashes or internal security fields.

### Relationship Contacts

- List, create, update, and delete contacts owned by the authenticated user.
- Store the contact name, relationship label, optional notes, strength, and optional avatar URL.
- Enforce ownership on every operation.
- Enforce the free plan limit of five contacts in the service layer and return a stable application error when exceeded.
- Do not implement payment processing in this phase.

## Data Model

### `users`

- UUID primary key
- unique normalized email
- password hash
- display name
- preferred language
- optional gender
- appearance preference
- active flag
- created and updated timestamps

### `contacts`

- UUID primary key
- owner user foreign key with cascade delete
- name
- relationship label
- optional notes
- strength value constrained to the accepted range
- optional avatar URL
- created and updated timestamps

Database constraints protect uniqueness and required fields. Business constraints such as the five-contact free limit are enforced in services so they remain testable and reusable.

## API Contract

All business endpoints use the `/api/v1` prefix:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/users/me`
- `PATCH /api/v1/users/me`
- `GET /api/v1/contacts`
- `POST /api/v1/contacts`
- `GET /api/v1/contacts/{contact_id}`
- `PATCH /api/v1/contacts/{contact_id}`
- `DELETE /api/v1/contacts/{contact_id}`

Responses use Pydantic models. Errors use a consistent JSON shape containing a stable code and human-readable message. Expected failures use appropriate HTTP status codes: 400 for invalid business operations, 401 for authentication failures, 404 for missing or unowned resources, and 409 for duplicate email registration.

## Configuration And Local Development

- Secrets and connection strings come from environment variables.
- `.env.example` documents required local values and `.env` stays ignored.
- Docker Compose starts PostgreSQL and the API for local development.
- Alembic is the only supported mechanism for changing production database schemas.
- The project exposes interactive OpenAPI documentation at `/docs` in development.
- A concise README documents installation, migration, startup, testing, and API exploration.

## Testing

Development follows test-first behavior for business features. The initial suite covers:

- health response
- registration and duplicate-email handling
- login success and invalid credentials
- authenticated profile access and update
- contact ownership and CRUD
- acceptance of the first five contacts
- rejection of the sixth contact

Tests isolate application behavior from the developer's personal PostgreSQL installation. Service tests use controlled sessions, while integration configuration supports a dedicated PostgreSQL test database for migration and dialect verification.

## Delivery

The design document is committed separately. Implementation changes are verified with formatting, linting, type checking, tests, migration checks, and a container configuration validation before being committed and pushed to `origin`. Existing iOS source changes are preserved; local Xcode signing changes are excluded from backend commits.

## Deferred Scope

The following are intentionally deferred: AI provider integration, streaming chat, conversation history, review analysis, achievements, subscriptions and payment processing, Redis, distributed workers, file uploads, push notifications, and production cloud selection.
