from pydantic import SecretStr

from app.core.config import Settings
from app.core.refresh_tokens import refresh_token_manager
from app.core.security import create_access_token, decode_token


def test_database_url_is_normalized_for_async_postgres() -> None:
    settings = Settings(
        DATABASE_URL="postgresql://user:pass@localhost:5432/student_system",
        JWT_SECRET_KEY=SecretStr("x" * 64),
    )
    assert settings.database_url == (
        "postgresql+asyncpg://user:pass@localhost:5432/student_system"
    )


def test_csv_env_lists_are_parsed_without_json(monkeypatch) -> None:
    monkeypatch.setenv(
        "ALLOWED_ORIGINS",
        "https://app.example.com, https://admin.example.com",
    )
    monkeypatch.setenv(
        "TRUSTED_HOSTS",
        "localhost,127.0.0.1,student-system.onrender.com",
    )
    monkeypatch.setenv(
        "JWT_PREVIOUS_SECRET_KEYS",
        ",".join(["a" * 64, "b" * 64]),
    )

    settings = Settings(JWT_SECRET_KEY=SecretStr("x" * 64))

    assert settings.allowed_origins == [
        "https://app.example.com",
        "https://admin.example.com",
    ]
    assert settings.trusted_hosts == [
        "localhost",
        "127.0.0.1",
        "student-system.onrender.com",
    ]
    assert [secret.get_secret_value() for secret in settings.jwt_previous_secret_keys] == [
        "a" * 64,
        "b" * 64,
    ]


def test_access_token_carries_session_id() -> None:
    token, _ = create_access_token(
        subject="user-123",
        role="teacher",
        session_id="session-456",
    )
    payload = decode_token(token)
    assert payload["sub"] == "user-123"
    assert payload["sid"] == "session-456"
    assert payload["type"] == "access"


def test_refresh_token_round_trip() -> None:
    token, jti, _ = refresh_token_manager.create_refresh_token(
        subject="user-123",
        role="teacher",
        session_id="session-456",
    )
    payload = refresh_token_manager.validate_refresh_token(token)
    assert payload["sub"] == "user-123"
    assert payload["sid"] == "session-456"
    assert payload["jti"] == jti
    assert payload["type"] == "refresh"
