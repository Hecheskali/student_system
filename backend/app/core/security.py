import hashlib
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from fastapi import HTTPException, status
from pwdlib import PasswordHash

from app.core.config import get_settings

password_hasher = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return password_hasher.verify(password, password_hash)


def hash_opaque_token(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def generate_opaque_token() -> str:
    return secrets.token_urlsafe(32)


def create_access_token(
    *,
    subject: uuid.UUID | str,
    role: str,
    session_id: uuid.UUID | str | None = None,
) -> tuple[str, int]:
    settings = get_settings()
    expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
    expires_at = datetime.now(UTC) + expires_delta
    payload: dict[str, Any] = {
        "sub": str(subject),
        "role": role,
        "type": "access",
        "jti": str(uuid.uuid4()),
        "iat": int(datetime.now(UTC).timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    if session_id:
        payload["sid"] = str(session_id)
    token = jwt.encode(
        payload,
        settings.jwt_secret_key.get_secret_value(),
        algorithm=settings.jwt_algorithm,
    )
    return token, int(expires_delta.total_seconds())


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    payload = _decode_with_known_secrets(token)
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload


def _decode_with_known_secrets(token: str) -> dict[str, Any]:
    settings = get_settings()
    candidate_secrets = [
        settings.jwt_secret_key.get_secret_value(),
        *[secret.get_secret_value() for secret in settings.jwt_previous_secret_keys],
    ]
    last_error: Exception | None = None
    for secret in candidate_secrets:
        try:
            return jwt.decode(
                token,
                secret,
                algorithms=[settings.jwt_algorithm],
            )
        except jwt.InvalidTokenError as exc:
            last_error = exc
            continue
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token.",
        headers={"WWW-Authenticate": "Bearer"},
    ) from last_error
