# AGENTS.md — HabitTracker

Guidelines for AI agents working in this repository.

---

## Project Overview

HabitTracker is a microservices backend + iOS frontend for tracking daily habits. The backend consists of two independent FastAPI services sharing a single PostgreSQL database (schema-isolated). The frontend is a SwiftUI iOS app targeting iOS 17+.

```
habit-tracker/
├── auth-service/       # FastAPI — user registration, login, JWT issuance
├── habits-service/     # FastAPI — habits CRUD, logs, streak statistics
├── HabitTrackerApp/    # SwiftUI iOS app (Xcode project)
├── db/
│   └── init.sql        # PostgreSQL schema bootstrap
├── postman/            # REST Client / Postman / curl test files
├── docker-compose.yml  # Local orchestration (Postgres + both services)
└── .env.example        # Required environment variable template
```

---

## Architecture

### Communication flow

```
iOS App
  ├── http://localhost:8001  →  auth-service   (register, login, /me)
  └── http://localhost:8002  →  habits-service (habits CRUD, logs, stats)

auth-service    →  PostgreSQL (auth_schema)
habits-service  →  PostgreSQL (habits_schema)
habits-service  →  auth-service /auth/verify  (fallback JWT check only)
```

### Key architectural decisions

- **Stateless JWT (HS256)**: Habits-service verifies tokens locally using the shared `JWT_SECRET`. It only calls `auth-service /auth/verify` as a fallback. Do not introduce database-backed sessions.
- **Schema isolation**: Both services connect to the same PostgreSQL instance but each sets `search_path` to its own schema at connection time (`auth_schema` / `habits_schema`). There are no cross-schema foreign keys. Habits-service knows a user only by the `user_id` (`sub`) claim in the JWT.
- **Ownership enforcement**: Every habits-service endpoint that touches a specific habit must verify `habit.user_id == claims["sub"]` and return 403 if they differ.
- **Unified error envelope**: Both services return errors in the same structure (see Error Format below). Do not break this contract.

---

## Backend Services

### Common patterns (both services)

#### Running locally
```bash
docker compose up --build          # starts postgres + both services
docker compose up --build auth-service habits-service  # skip if DB already running
```

#### Environment variables
Copy `.env.example` to `.env` and fill in values. Critical variables:
- `JWT_SECRET` — required, no default, must match in both services
- `POSTGRES_*` — database connection
- `AUTH_DB_SCHEMA` / `HABITS_DB_SCHEMA` — schema names (default: `auth_schema` / `habits_schema`)
- `AUTH_SERVICE_URL` — used by habits-service fallback (default: `http://auth-service:8001`)

Never hardcode secrets. Never commit `.env`.

#### Dependency injection
Both services use FastAPI `Depends()` for the database session (`get_db`) and the authenticated user (`get_current_user` / `get_current_claims`). Always thread new route dependencies through this pattern.

#### Error format
All error responses use this envelope — maintain it in any new route or service:
```json
{
  "error": {
    "code": "VALIDATION_ERROR | UNAUTHORIZED | FORBIDDEN | NOT_FOUND | CONFLICT | INTERNAL_ERROR",
    "message": "Human-readable description",
    "details": {},
    "request_id": "uuid"
  }
}
```
The `request_id` comes from the `X-Request-ID` header (middleware auto-generates one if absent). 500 responses must not leak stack traces; log them server-side only.

#### Database models
- Use SQLAlchemy 2.x ORM style (declarative base, `mapped_column`).
- UUIDs for all primary keys (server-generated).
- Add new migrations manually in `db/init.sql` for now — there is no Alembic setup. If you add Alembic, note it here.

#### Python version and packages
- Python 3.12, FastAPI 0.115.0, SQLAlchemy 2.0.35, Pydantic v2.
- Install with `pip install -r requirements.txt` inside the service directory.
- Use `pydantic-settings` for configuration; never read `os.environ` directly in application code.

---

### auth-service (port 8001)

**Responsibilities**: Registration, login, JWT issuance, token verification.

**Key files**:
| File | Purpose |
|------|---------|
| `app/main.py` | FastAPI app, middleware, router inclusion |
| `app/models.py` | `User` ORM (UUID PK, email unique, password_hash) |
| `app/schemas.py` | `RegisterRequest`, `LoginRequest`, `TokenResponse`, `UserResponse`, `VerifyResponse` |
| `app/security.py` | `hash_password()`, `verify_password()`, `create_access_token()`, `decode_access_token()` |
| `app/deps.py` | `get_current_user` dependency |
| `app/routers/auth.py` | All `/auth/*` routes |

**Endpoints**:
- `POST /auth/register` → 201 + user data
- `POST /auth/login` → 200 + `TokenResponse`
- `GET /auth/me` → 200 + `UserResponse` (requires Bearer token)
- `GET /auth/verify` → 200 + `VerifyResponse` (used by habits-service)
- `GET /health` → 200

**Security rules**:
- Passwords hashed with bcrypt (passlib). Never store or return plaintext passwords.
- Login errors must say "Invalid email or password" regardless of which field is wrong (anti-enumeration).
- JWT payload: `sub` (user UUID as string), `email`, `iat`, `exp`, `iss`.

---

### habits-service (port 8002)

**Responsibilities**: Habit CRUD, daily execution logs, streak/completion statistics.

**Key files**:
| File | Purpose |
|------|---------|
| `app/models.py` | `Habit`, `HabitLog` ORM; cascade delete on Habit→HabitLog |
| `app/schemas.py` | `HabitCreate/Update/Response`, `HabitLogResponse`, `HabitStats` |
| `app/security.py` | Local JWT decode + optional fallback to auth-service |
| `app/deps.py` | `get_current_claims` dependency |
| `app/services/stats.py` | Streak and completion-rate computation |
| `app/routers/habits.py` | All `/habits/*` routes |

**Endpoints**:
- `POST /habits` → 201
- `GET /habits` → list (current user's habits only)
- `GET /habits/{id}` → detail
- `PATCH /habits/{id}` → partial update (`exclude_unset=True`)
- `DELETE /habits/{id}` → 204, cascades to logs
- `POST /habits/{id}/logs` → log execution (default: today, unique per day per habit)
- `GET /habits/{id}/logs` → history
- `GET /habits/{id}/stats` → `HabitStats`
- `GET /health` → 200

**Business rules**:
- `target_per_week`: integer 1–7; validate in schema.
- `HabitLog` has a `UniqueConstraint(habit_id, logged_on)` — duplicate log for same day must return 409 CONFLICT.
- Stats fields: `total_logs`, `current_streak_days`, `longest_streak_days`, `completion_rate_7d` (days logged in last 7 / 7), `last_logged_on`.
- Ownership check is mandatory on every route that accepts a habit `{id}`. Return 403 (not 404) on ownership mismatch to avoid leaking existence.

---

## iOS App (HabitTrackerApp)

**Language**: Swift 5.9+  
**Framework**: SwiftUI  
**Minimum deployment target**: iOS 17  
**State management**: `@Observable` (iOS 17 Observation framework) — do NOT use `@Published` or `ObservableObject`.

### Architecture overview

```
Views/          — SwiftUI views (no business logic)
Stores/         — @Observable state containers (AuthStore, HabitsStore)
Core/
  APIClient     — Generic URLSession wrapper; two instances (auth, habits)
  AppConfig     — Base URLs (hardcoded to localhost for dev)
  KeychainStore — SecItem wrapper for JWT persistence
  APIError      — Typed error enum mapping server errors
  Theme         — 5-color palette + semantic aliases
Models/         — Codable DTOs mirroring backend schemas
```

### Key conventions

- **JWT storage**: Always via `KeychainStore` with `kSecAttrAccessibleAfterFirstUnlock`. Never `UserDefaults` for tokens.
- **Auto-logout on 401**: Both `AuthStore` and `HabitsStore` must call `authStore.logout()` when `APIError.unauthorized` is received.
- **Date decoding**: `APIClient` handles four ISO 8601 variants to cope with Postgres `TIMESTAMP` vs `TIMESTAMPTZ`. Do not add `JSONDecoder.dateDecodingStrategy = .iso8601` directly — it will break the custom strategy.
- **snake_case ↔ camelCase**: Models use explicit `CodingKeys` instead of `JSONDecoder.keyDecodingStrategy`. Keep this consistent when adding new models.
- **PATCH encoding**: `HabitUpdateRequest` uses `encodeIfPresent` for optional fields so only changed fields are sent.
- **Theme**: Use `Theme.*` color constants. Do not introduce raw `Color(hex:)` or hard-coded colors in views.
- **Local dev networking**: `NSAllowsLocalNetworking = YES` in `Info.plist` allows HTTP to localhost. Production builds require HTTPS — do not disable ATS globally.

### Adding a new feature

1. Add/update backend models and schemas in the relevant service.
2. Add/update `Models/` DTOs in the iOS app (mirror the backend JSON shape, use explicit CodingKeys).
3. Add API call methods to `APIClient` or the relevant Store.
4. Build the SwiftUI View, reading state from the Store, not from the API directly.

---

## Database

### Schema bootstrap
`db/init.sql` is executed by the PostgreSQL Docker container on first startup. It:
- Creates `auth_schema` and `habits_schema`
- Grants usage + all privileges to `$POSTGRES_USER`

To reset the database during development:
```bash
docker compose down -v   # removes the postgres-data volume
docker compose up --build
```

### Schema ownership
- `auth_schema.users` — owned by auth-service only
- `habits_schema.habits`, `habits_schema.habit_logs` — owned by habits-service only
- No cross-schema queries. No cross-schema foreign keys. This is intentional.

### Migrations
There is no migration framework. Schema changes must be applied manually to `db/init.sql` and to the relevant service's `models.py`. If you add Alembic to a service, update this document and add a `migrations/` directory inside that service.

---

## Testing

There are currently no automated tests. When adding tests:

### Backend
- Use `pytest` + `httpx.AsyncClient` for route-level integration tests.
- Spin up a separate test PostgreSQL database (or use `pytest-postgresql`); do not mock the database layer.
- Place tests in `auth-service/tests/` and `habits-service/tests/`.
- Test the ownership-check on every mutating habit endpoint.

### iOS
- Use `XCTest` for unit tests of Store logic and model decoding.
- Use `XCUITest` for UI flows.
- Stub `APIClient` with a protocol or closure injection pattern — do not make real HTTP calls in unit tests.

### Manual testing
- `postman/requests.http` — VS Code REST Client, covers happy path + error cases.
- `postman/curl.sh` — end-to-end bash smoke test against a running stack.
- `postman/HabitTracker.postman_collection.json` — Postman import.

---

## Development Workflow

### Starting the full stack
```bash
cp .env.example .env          # fill in JWT_SECRET and Postgres credentials
docker compose up --build     # builds images and starts all three containers
```

Services are ready when health checks pass:
- auth-service: `curl http://localhost:8001/health`
- habits-service: `curl http://localhost:8002/health`

### Making backend changes
1. Edit code inside `auth-service/app/` or `habits-service/app/`.
2. Rebuild the affected service: `docker compose up --build auth-service` (or `habits-service`).
3. Verify with the REST Client or curl scripts.

### Making iOS changes
1. Open `HabitTrackerApp/HabitTrackerApp.xcodeproj` in Xcode.
2. Ensure the backend stack is running locally.
3. Build and run on the iOS Simulator (⌘R).
4. The app hits `http://localhost:8001` and `http://localhost:8002` by default (`AppConfig.swift`).

---

## Things to Avoid

- **Do not** store any secret or token in `UserDefaults` (JWT goes to Keychain only).
- **Do not** return 404 when a habit exists but belongs to a different user — return 403 to avoid existence leakage.
- **Do not** cross-query between `auth_schema` and `habits_schema` in any service.
- **Do not** add `@Published` / `ObservableObject` to the iOS app — use `@Observable` throughout.
- **Do not** break the unified error envelope structure — the iOS client has one error-parsing path.
- **Do not** commit `.env` or any file containing `JWT_SECRET` or database credentials.
- **Do not** log full stack traces in 500 responses — log server-side and return a generic message.
- **Do not** use `JSONDecoder.dateDecodingStrategy = .iso8601` globally in `APIClient` — it conflicts with the multi-format custom strategy.
