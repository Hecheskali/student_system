from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models.user import UserRole


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    otp_code: str | None = Field(default=None, min_length=6, max_length=8)
    backup_code: str | None = Field(default=None, min_length=8, max_length=16)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    full_name: str
    role: UserRole
    is_active: bool
    must_change_password: bool
    last_login_at: datetime | None
    email_verified_at: datetime | None
    two_factor_enabled: bool


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    session_id: str
    user: UserRead


class LogoutResponse(BaseModel):
    detail: str


class CreateUserRequest(BaseModel):
    email: EmailStr
    full_name: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=12, max_length=128)
    role: UserRole
    must_change_password: bool = True

    @field_validator("password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        has_upper = any(char.isupper() for char in value)
        has_lower = any(char.islower() for char in value)
        has_digit = any(char.isdigit() for char in value)
        has_symbol = any(not char.isalnum() for char in value)
        if not (has_upper and has_lower and has_digit and has_symbol):
            raise ValueError(
                "Password must include upper, lower, digit, and symbol characters.",
            )
        return value


class AuditLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    actor_user_id: str | None
    event_type: str
    status: str
    target_resource: str | None
    ip_address: str | None
    request_id: str | None
    detail_json: dict
    created_at: datetime


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=32, max_length=4096)


class SecurityActionResponse(BaseModel):
    detail: str
    token_preview: str | None = None


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirmRequest(BaseModel):
    token: str = Field(min_length=16, max_length=512)
    new_password: str = Field(min_length=12, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_new_password_strength(cls, value: str) -> str:
        has_upper = any(char.isupper() for char in value)
        has_lower = any(char.islower() for char in value)
        has_digit = any(char.isdigit() for char in value)
        has_symbol = any(not char.isalnum() for char in value)
        if not (has_upper and has_lower and has_digit and has_symbol):
            raise ValueError(
                "Password must include upper, lower, digit, and symbol characters.",
            )
        return value


class EmailVerificationConfirmRequest(BaseModel):
    token: str = Field(min_length=16, max_length=512)


class SessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    ip_address: str | None
    user_agent: str | None
    device_fingerprint: str | None
    expires_at: datetime
    last_seen_at: datetime
    revoked_at: datetime | None
    compromised_at: datetime | None


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=12, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_new_password_strength(cls, value: str) -> str:
        has_upper = any(char.isupper() for char in value)
        has_lower = any(char.islower() for char in value)
        has_digit = any(char.isdigit() for char in value)
        has_symbol = any(not char.isalnum() for char in value)
        if not (has_upper and has_lower and has_digit and has_symbol):
            raise ValueError(
                "Password must include upper, lower, digit, and symbol characters.",
            )
        return value


class TwoFactorSetupResponse(BaseModel):
    detail: str
    secret: str
    provisioning_uri: str
    backup_codes: list[str]


class TwoFactorConfirmRequest(BaseModel):
    otp_code: str = Field(min_length=6, max_length=8)


class TwoFactorDisableRequest(BaseModel):
    password: str = Field(min_length=8, max_length=128)
    otp_code: str | None = Field(default=None, min_length=6, max_length=8)
    backup_code: str | None = Field(default=None, min_length=8, max_length=16)
