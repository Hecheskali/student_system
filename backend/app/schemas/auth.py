from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models.user import UserRole


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    full_name: str
    role: UserRole
    is_active: bool
    must_change_password: bool
    last_login_at: datetime | None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
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

