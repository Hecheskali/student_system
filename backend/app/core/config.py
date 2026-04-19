import os
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
        default=SecretStr(
            "replace-this-default-secret-with-a-64-plus-character-production-value-now",
        ),
        alias="JWT_SECRET_KEY",
    )
    jwt_algorithm: str = "HS512"
    access_token_expire_minutes: int = Field(
        default=15,
        alias="ACCESS_TOKEN_EXPIRE_MINUTES",
    )
    refresh_token_expire_days: int = Field(
        default=7,
        alias="REFRESH_TOKEN_EXPIRE_DAYS",
    )
    password_reset_expire_minutes: int = Field(
        default=30,
        alias="PASSWORD_RESET_EXPIRE_MINUTES",
    )
    email_verification_expire_hours: int = Field(
        default=24,
        alias="EMAIL_VERIFICATION_EXPIRE_HOURS",
    )
    session_idle_timeout_minutes: int = Field(
        default=30,
        alias="SESSION_IDLE_TIMEOUT_MINUTES",
    )
    max_sessions_per_user: int = Field(
        default=5,
        alias="MAX_SESSIONS_PER_USER",
    )
    jwt_previous_secret_keys: list[SecretStr] = Field(
        default_factory=list,
        alias="JWT_PREVIOUS_SECRET_KEYS",
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
    auto_create_schema: bool = Field(default=True, alias="AUTO_CREATE_SCHEMA")
    observability_enabled: bool = Field(
        default=True,
        alias="OBSERVABILITY_ENABLED",
    )
    metrics_enabled: bool = Field(default=True, alias="METRICS_ENABLED")
    audit_retention_days: int = Field(default=365, alias="AUDIT_RETENTION_DAYS")
    session_retention_days: int = Field(
        default=30,
        alias="SESSION_RETENTION_DAYS",
    )
    security_token_retention_days: int = Field(
        default=14,
        alias="SECURITY_TOKEN_RETENTION_DAYS",
    )
    trusted_proxy_depth: int = Field(default=1, alias="TRUSTED_PROXY_DEPTH")

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

    # Advanced security settings
    enable_2fa: bool = Field(default=True, alias="ENABLE_2FA")
    require_2fa_for_admins: bool = Field(default=True, alias="REQUIRE_2FA_FOR_ADMINS")
    enable_audit_logging: bool = Field(default=True, alias="ENABLE_AUDIT_LOGGING")
    enable_anomaly_detection: bool = Field(
        default=True,
        alias="ENABLE_ANOMALY_DETECTION",
    )
    enable_device_fingerprinting: bool = Field(
        default=True,
        alias="ENABLE_DEVICE_FINGERPRINTING",
    )
    password_min_length: int = Field(default=12, alias="PASSWORD_MIN_LENGTH")
    password_require_special: bool = Field(
        default=True,
        alias="PASSWORD_REQUIRE_SPECIAL",
    )
    password_require_numbers: bool = Field(
        default=True,
        alias="PASSWORD_REQUIRE_NUMBERS",
    )
    password_require_uppercase: bool = Field(
        default=True,
        alias="PASSWORD_REQUIRE_UPPERCASE",
    )
    password_expiry_days: int = Field(default=90, alias="PASSWORD_EXPIRY_DAYS")
    max_password_attempts: int = Field(default=5, alias="MAX_PASSWORD_ATTEMPTS")
    redis_url: str | None = Field(default=None, alias="REDIS_URL")
    redis_rate_limit_prefix: str = Field(
        default="student-system:ratelimit",
        alias="REDIS_RATE_LIMIT_PREFIX",
    )
    supabase_url: str | None = Field(default=None, alias="SUPABASE_URL")
    supabase_anon_key: SecretStr | None = Field(
        default=None,
        alias="SUPABASE_ANON_KEY",
    )
    supabase_service_role_key: SecretStr | None = Field(
        default=None,
        alias="SUPABASE_SERVICE_ROLE_KEY",
    )
    email_provider: str = Field(default="resend", alias="EMAIL_PROVIDER")
    email_from_address: str = Field(
        default="noreply@student-system.local",
        alias="EMAIL_FROM_ADDRESS",
    )
    # Resend API for email delivery (modern, reliable email service)
    resend_api_key: SecretStr | None = Field(
        default=None,
        alias="RESEND_API_KEY",
    )
    # Legacy SMTP settings (for backward compatibility)
    smtp_host: str | None = Field(default=None, alias="SMTP_HOST")
    smtp_port: int = Field(default=587, alias="SMTP_PORT")
    smtp_username: str | None = Field(default=None, alias="SMTP_USERNAME")
    smtp_password: SecretStr | None = Field(default=None, alias="SMTP_PASSWORD")
    smtp_use_tls: bool = Field(default=True, alias="SMTP_USE_TLS")
    # SMS provider settings
    sms_provider: str = Field(default="vonage", alias="SMS_PROVIDER")
    # Vonage SMS API (formerly Nexmo)
    vonage_api_key: str | None = Field(default=None, alias="VONAGE_API_KEY")
    vonage_api_secret: SecretStr | None = Field(
        default=None,
        alias="VONAGE_API_SECRET",
    )
    vonage_from_number: str | None = Field(default=None, alias="VONAGE_FROM_NUMBER")
    # Legacy Twilio settings (for backward compatibility)
    twilio_account_sid: str | None = Field(default=None, alias="TWILIO_ACCOUNT_SID")
    twilio_auth_token: SecretStr | None = Field(
        default=None,
        alias="TWILIO_AUTH_TOKEN",
    )
    twilio_from_number: str | None = Field(default=None, alias="TWILIO_FROM_NUMBER")
    alert_webhook_url: SecretStr | None = Field(
        default=None,
        alias="ALERT_WEBHOOK_URL",
    )
    outbox_batch_size: int = Field(default=25, alias="OUTBOX_BATCH_SIZE")
    worker_poll_interval_seconds: int = Field(
        default=10,
        alias="WORKER_POLL_INTERVAL_SECONDS",
    )

    @field_validator("trusted_hosts", "allowed_origins", mode="before")
    @classmethod
    def _parse_csv_list(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, list):
            return value
        return [item.strip() for item in value.split(",") if item.strip()]

    @field_validator("jwt_previous_secret_keys", mode="before")
    @classmethod
    def _parse_secret_list(
        cls,
        value: str | list[str] | list[SecretStr],
    ) -> list[SecretStr]:
        if isinstance(value, list):
            return [
                item if isinstance(item, SecretStr) else SecretStr(item)
                for item in value
                if str(item).strip()
            ]
        if not value:
            return []
        return [
            SecretStr(item.strip())
            for item in value.split(",")
            if item.strip()
        ]

    @field_validator("database_url", mode="before")
    @classmethod
    def _normalize_database_url(cls, value: str) -> str:
        if value.startswith("postgres://"):
            value = value.replace("postgres://", "postgresql://", 1)
        if value.startswith("postgresql://") and not value.startswith(
            "postgresql+asyncpg://",
        ):
            value = value.replace("postgresql://", "postgresql+asyncpg://", 1)
        return value

    @field_validator("trusted_hosts")
    @classmethod
    def _append_render_hostname(cls, value: list[str]) -> list[str]:
        render_hostname = os.getenv("RENDER_EXTERNAL_HOSTNAME")
        if render_hostname and render_hostname not in value:
            value.append(render_hostname)
        return value

    @field_validator("jwt_secret_key")
    @classmethod
    def _validate_secret_length(cls, value: SecretStr) -> SecretStr:
        if len(value.get_secret_value()) < 64:
            raise ValueError("JWT_SECRET_KEY must be at least 64 characters long for HS512.")
        return value

    @field_validator("jwt_previous_secret_keys")
    @classmethod
    def _validate_previous_secret_lengths(
        cls,
        value: list[SecretStr],
    ) -> list[SecretStr]:
        for secret in value:
            if len(secret.get_secret_value()) < 64:
                raise ValueError(
                    "Every JWT_PREVIOUS_SECRET_KEYS entry must be at least 64 characters long for HS512.",
                )
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
