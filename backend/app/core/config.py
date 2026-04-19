from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = Field(default="Student System API", alias="APP_NAME")
    app_env: Literal["development", "staging", "production"] = Field(
        default="development",
        alias="APP_ENV",
    )
    debug: bool = Field(default=False, alias="APP_DEBUG")
    host: str = Field(default="0.0.0.0", alias="APP_HOST")
    port: int = Field(default=8000, alias="APP_PORT")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")

    database_url: str = Field(
        default="sqlite+aiosqlite:///./student_system.db",
        alias="DATABASE_URL",
    )

    jwt_secret_key: SecretStr = Field(
        default=SecretStr("change-this-to-a-random-64-character-secret-value"),
        alias="JWT_SECRET_KEY",
    )
    jwt_algorithm: str = "HS512"
    access_token_expire_minutes: int = Field(
        default=15,
        alias="ACCESS_TOKEN_EXPIRE_MINUTES",
    )

    login_rate_limit_attempts: int = Field(
        default=5,
        alias="LOGIN_RATE_LIMIT_ATTEMPTS",
    )
    login_rate_limit_window_seconds: int = Field(
        default=300,
        alias="LOGIN_RATE_LIMIT_WINDOW_SECONDS",
    )
    account_lockout_minutes: int = Field(
        default=15,
        alias="ACCOUNT_LOCKOUT_MINUTES",
    )

    trusted_hosts: list[str] = Field(
        default_factory=lambda: ["localhost", "127.0.0.1"],
        alias="TRUSTED_HOSTS",
    )
    allowed_origins: list[str] = Field(
        default_factory=lambda: ["http://localhost:3000"],
        alias="ALLOWED_ORIGINS",
    )
    enable_https_redirect: bool = Field(
        default=False,
        alias="ENABLE_HTTPS_REDIRECT",
    )
    enable_hsts: bool = Field(default=False, alias="ENABLE_HSTS")
    enable_docs: bool = Field(default=True, alias="ENABLE_DOCS")

    bootstrap_admin_email: str | None = Field(
        default=None,
        alias="BOOTSTRAP_ADMIN_EMAIL",
    )
    bootstrap_admin_password: str | None = Field(
        default=None,
        alias="BOOTSTRAP_ADMIN_PASSWORD",
    )
    bootstrap_admin_name: str = Field(
        default="System Administrator",
        alias="BOOTSTRAP_ADMIN_NAME",
    )

    @field_validator("trusted_hosts", "allowed_origins", mode="before")
    @classmethod
    def _parse_csv_list(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, list):
            return value
        return [item.strip() for item in value.split(",") if item.strip()]

    @field_validator("jwt_secret_key")
    @classmethod
    def _validate_secret_length(cls, value: SecretStr) -> SecretStr:
        if len(value.get_secret_value()) < 32:
            raise ValueError("JWT_SECRET_KEY must be at least 32 characters long.")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()

