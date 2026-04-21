"""Refresh token management for secure token rotation."""

from datetime import UTC, datetime, timedelta
from typing import Any
import uuid

import jwt
from fastapi import HTTPException, status

from app.core.config import get_settings
from app.core.security import _decode_with_known_secrets


class RefreshTokenManager:
    """Manages refresh token creation, validation, and rotation."""

    @staticmethod
    def create_refresh_token(
        *,
        subject: uuid.UUID | str,
        role: str,
        session_id: uuid.UUID | str,
    ) -> tuple[str, str, int]:
        """Create a refresh token (longer expiration than access token)."""
        settings = get_settings()
        expires_delta = timedelta(days=settings.refresh_token_expire_days)
        expires_at = datetime.now(UTC) + expires_delta
        jti = str(uuid.uuid4())

        payload: dict[str, Any] = {
            "sub": str(subject),
            "role": role,
            "type": "refresh",
            "sid": str(session_id),
            "iat": int(datetime.now(UTC).timestamp()),
            "exp": int(expires_at.timestamp()),
            "jti": jti,
        }

        token = jwt.encode(
            payload,
            settings.jwt_secret_key.get_secret_value(),
            algorithm=settings.jwt_algorithm,
        )
        return token, jti, int(expires_delta.total_seconds())

    @staticmethod
    def validate_refresh_token(token: str) -> dict[str, Any]:
        """Validate and decode refresh token."""
        payload = _decode_with_known_secrets(token)

        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return payload


refresh_token_manager = RefreshTokenManager()
