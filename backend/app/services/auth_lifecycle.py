from datetime import UTC, datetime, timedelta
from typing import Literal

from fastapi import Request
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.device_fingerprint import DeviceFingerprint
from app.core.refresh_tokens import refresh_token_manager
from app.core.security import (
    create_access_token,
    generate_opaque_token,
    hash_opaque_token,
)
from app.models.auth_security import RefreshToken, SecurityToken, UserSession
from app.models.user import User

SecurityTokenPurpose = Literal["password_reset", "email_verification"]


def build_device_fingerprint(request: Request) -> str:
    return DeviceFingerprint.generate_fingerprint(
        user_agent=request.headers.get("user-agent", ""),
        accept_language=request.headers.get("accept-language", ""),
        accept_encoding=request.headers.get("accept-encoding", ""),
        client_ip=request.client.host if request.client else "unknown",
    )


async def create_session(
    db: AsyncSession,
    *,
    user: User,
    request: Request,
) -> UserSession:
    settings = get_settings()
    now = datetime.now(UTC)
    session = UserSession(
        user_id=user.id,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
        device_fingerprint=build_device_fingerprint(request),
        last_seen_at=now,
        expires_at=now + timedelta(days=settings.session_retention_days),
    )
    db.add(session)
    await db.flush()
    return session


async def issue_session_tokens(
    db: AsyncSession,
    *,
    user: User,
    request: Request,
    session: UserSession | None = None,
) -> tuple[str, str, int, UserSession]:
    now = datetime.now(UTC)
    target_session = session or await create_session(db, user=user, request=request)
    target_session.last_seen_at = now
    target_session.revoked_at = None
    target_session.compromised_at = None

    access_token, expires_in = create_access_token(
        subject=user.id,
        role=user.role.value,
        session_id=target_session.id,
    )
    refresh_token, jti, _ = refresh_token_manager.create_refresh_token(
        subject=user.id,
        role=user.role.value,
        session_id=target_session.id,
    )
    refresh_record = RefreshToken(
        user_id=user.id,
        session_id=target_session.id,
        jti=jti,
        token_hash=hash_opaque_token(refresh_token),
        expires_at=now + timedelta(days=get_settings().refresh_token_expire_days),
    )
    db.add(refresh_record)
    await _prune_excess_sessions(db, user.id)
    await db.commit()
    await db.refresh(target_session)
    return access_token, refresh_token, expires_in, target_session


async def rotate_refresh_token(
    db: AsyncSession,
    *,
    token_record: RefreshToken,
    user: User,
    request: Request,
) -> tuple[str, str, int, UserSession]:
    now = datetime.now(UTC)
    token_record.revoked_at = now
    session = await db.scalar(
        select(UserSession).where(UserSession.id == token_record.session_id),
    )
    if session is None:
        raise ValueError("Session not found for refresh token")
    session.last_seen_at = now
    return await issue_session_tokens(db, user=user, request=request, session=session)


async def revoke_session(
    db: AsyncSession,
    *,
    session: UserSession,
    compromised: bool = False,
) -> None:
    now = datetime.now(UTC)
    session.revoked_at = now
    if compromised:
        session.compromised_at = now
    await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.session_id == session.id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(
            revoked_at=now,
            reused_detected_at=now if compromised else RefreshToken.reused_detected_at,
        ),
    )
    await db.commit()


async def revoke_all_user_sessions(
    db: AsyncSession,
    *,
    user_id: str,
    compromised: bool = False,
) -> None:
    active_sessions = (
        await db.scalars(
            select(UserSession).where(
                UserSession.user_id == user_id,
                UserSession.revoked_at.is_(None),
            )
        )
    ).all()
    for session in active_sessions:
        session.revoked_at = datetime.now(UTC)
        if compromised:
            session.compromised_at = datetime.now(UTC)
    await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(
            revoked_at=datetime.now(UTC),
            reused_detected_at=datetime.now(UTC) if compromised else RefreshToken.reused_detected_at,
        ),
    )
    await db.commit()


async def create_security_token(
    db: AsyncSession,
    *,
    user: User,
    purpose: SecurityTokenPurpose,
    expires_at: datetime,
    meta_json: dict | None = None,
) -> str:
    raw_token = generate_opaque_token()
    token = SecurityToken(
        user_id=user.id,
        purpose=purpose,
        token_hash=hash_opaque_token(raw_token),
        expires_at=expires_at,
        meta_json=meta_json or {},
    )
    db.add(token)
    await db.commit()
    return raw_token


async def consume_security_token(
    db: AsyncSession,
    *,
    raw_token: str,
    purpose: SecurityTokenPurpose,
) -> SecurityToken | None:
    token_hash = hash_opaque_token(raw_token)
    token = await db.scalar(
        select(SecurityToken).where(
            SecurityToken.token_hash == token_hash,
            SecurityToken.purpose == purpose,
        )
    )
    if token is None or token.consumed_at is not None:
        return None
    if token.expires_at < datetime.now(UTC):
        return None
    token.consumed_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(token)
    return token


async def _prune_excess_sessions(db: AsyncSession, user_id: str) -> None:
    settings = get_settings()
    sessions = (
        await db.scalars(
            select(UserSession)
            .where(UserSession.user_id == user_id)
            .order_by(UserSession.last_seen_at.desc())
        )
    ).all()
    for session in sessions[settings.max_sessions_per_user :]:
        if session.revoked_at is None:
            session.revoked_at = datetime.now(UTC)
