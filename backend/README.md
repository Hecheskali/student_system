# FastAPI Backend

Security-focused backend scaffold for the student management system.

## Included security baseline

- Argon2 password hashing
- JWT bearer authentication
- Role-based access control
- Login rate limiting
- Account lockout after repeated failures
- Request ID tracing
- Audit logging
- Security headers middleware
- Trusted host filtering
- Strict CORS allowlist
- Environment-based secrets
- Docs can be disabled outside development
- Non-root Docker image

## Quick start

1. Create a virtual environment.
2. Install dependencies:

```bash
pip install -e .
```

3. Copy the environment file:

```bash
cp .env.example .env
```

4. Set a strong `JWT_SECRET_KEY`.
5. Optionally set `BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD`.
6. Run the API:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## First admin account

If `BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD` are present, the app
creates the first head-of-school admin on startup if it does not already exist.

## Main endpoints

- `GET /health/live`
- `GET /health/ready`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `POST /api/v1/auth/logout`
- `POST /api/v1/admin/users`
- `GET /api/v1/admin/users`
- `GET /api/v1/admin/audit-logs`

## Important note

This is a hardened foundation, not a literal guarantee of "10/10 security".
Before production, you should still:

- move to PostgreSQL
- put the API behind TLS and a reverse proxy
- replace in-memory rate limiting with Redis
- add database migrations
- add email verification and password reset
- run security testing and dependency scanning

## Render deployment

This repo includes a root-level `render.yaml` Blueprint for deploying the
backend to Render as a Python web service backed by Render Postgres.

From the repo root:

```bash
cd /home/harris/Desktop/jabu/student_system/backend
.venv/bin/python -m pip install -e .
```

Deployment notes:

- Render terminates TLS at the edge, so the start command enables proxy headers.
- The app automatically normalizes Render Postgres URLs like
  `postgresql://...` to SQLAlchemy async URLs `postgresql+asyncpg://...`.
- The health check path is `/health/ready`.
- Set `ALLOWED_ORIGINS` to your actual frontend URL before going live.
- Run schema upgrades with `alembic upgrade head`.
- Use the included maintenance cron job for retention cleanup.

## Production hardening included

- Alembic migration scaffolding
- Structured JSON logging and `/metrics` support
- Refresh-token rotation with session tracking and revocation
- Password reset and email verification token flows
- Redis-ready distributed rate limiting
- Data retention cleanup job
- DB-backed outbox worker for email/SMS delivery
- Render Blueprint deployment config
- Supabase RLS hardening migration scaffolding

## Async delivery and workers

The backend now includes:

- `app.jobs.outbox_worker` for queued email/SMS delivery
- SMTP and Twilio-compatible provider settings
- alert webhook integration for security-critical events

Local worker run:

```bash
cd /home/harris/Desktop/jabu/student_system/backend
.venv/bin/python -m app.jobs.outbox_worker
```
