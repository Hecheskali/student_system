from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.core.config import Settings
from app.middleware.input_validation import InputSanitizationMiddleware


def _build_cors_app() -> FastAPI:
    settings = Settings(JWT_SECRET_KEY=SecretStr("x" * 64))
    app = FastAPI()
    app.add_middleware(InputSanitizationMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_origin_regex=settings.allowed_origin_regex,
        allow_credentials=False,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
        expose_headers=["X-Request-ID"],
    )

    @app.post("/api/v1/admin/teachers")
    async def create_teacher() -> dict[str, str]:
        return {"status": "ok"}

    return app


def test_admin_teacher_create_preflight_allows_vercel_origin_and_auth_headers() -> None:
    client = TestClient(_build_cors_app())

    response = client.options(
        "/api/v1/admin/teachers",
        headers={
            "host": "localhost",
            "origin": "https://student-flax-psi.vercel.app",
            "access-control-request-method": "POST",
            "access-control-request-headers": "authorization,content-type",
        },
    )

    assert response.status_code == 200
    assert (
        response.headers["access-control-allow-origin"]
        == "https://student-flax-psi.vercel.app"
    )
    allowed_headers = response.headers["access-control-allow-headers"].lower()
    assert "authorization" in allowed_headers
    assert "content-type" in allowed_headers


def test_input_sanitizer_allows_options_preflight_method() -> None:
    app = FastAPI()
    app.add_middleware(InputSanitizationMiddleware)

    @app.options("/preflight")
    async def preflight() -> dict[str, str]:
        return {"status": "ok"}

    response = TestClient(app).options("/preflight")

    assert response.status_code == 200
