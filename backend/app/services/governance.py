import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.auth_security import RefreshToken, SecurityToken, UserSession
from app.models.audit_log import AuditLog
from app.models.user import User


async def purge_expired_security_data(db: AsyncSession) -> dict[str, int]:
    settings = get_settings()
    now = datetime.now(UTC)

    audit_cutoff = now - timedelta(days=settings.audit_retention_days)
    session_cutoff = now - timedelta(days=settings.session_retention_days)
    token_cutoff = now - timedelta(days=settings.security_token_retention_days)

    audit_result = await db.execute(
        delete(AuditLog).where(AuditLog.created_at < audit_cutoff),
    )
    session_result = await db.execute(
        delete(UserSession).where(
            or_(
                UserSession.expires_at < now,
                UserSession.updated_at < session_cutoff,
                UserSession.revoked_at < token_cutoff,
            ),
        ),
    )
    refresh_result = await db.execute(
        delete(RefreshToken).where(
            or_(
                RefreshToken.expires_at < now,
                RefreshToken.revoked_at < token_cutoff,
            ),
        ),
    )
    security_result = await db.execute(
        delete(SecurityToken).where(
            or_(
                SecurityToken.expires_at < now,
                SecurityToken.consumed_at < token_cutoff,
            ),
        ),
    )
    await db.commit()
    return {
        "audit_logs_deleted": int(getattr(audit_result, "rowcount", 0) or 0),
        "sessions_deleted": int(getattr(session_result, "rowcount", 0) or 0),
        "refresh_tokens_deleted": int(getattr(refresh_result, "rowcount", 0) or 0),
        "security_tokens_deleted": int(getattr(security_result, "rowcount", 0) or 0),
    }


async def export_user_governance_snapshot(
    db: AsyncSession,
    *,
    user_id: uuid.UUID,
) -> dict[str, object]:
    user = await db.scalar(select(User).where(User.id == user_id))
    if user is None:
        raise ValueError("User not found")

    sessions = (
        await db.scalars(select(UserSession).where(UserSession.user_id == user_id))
    ).all()
    audit_logs = (
        await db.scalars(select(AuditLog).where(AuditLog.actor_user_id == user_id))
    ).all()

    return {
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": user.full_name,
            "role": user.role.value,
            "created_at": user.created_at.isoformat(),
            "last_login_at": user.last_login_at.isoformat()
            if user.last_login_at
            else None,
        },
        "sessions": [
            {
                "id": str(session.id),
                "ip_address": session.ip_address,
                "user_agent": session.user_agent,
                "created_at": session.created_at.isoformat(),
                "last_seen_at": session.last_seen_at.isoformat(),
                "revoked_at": session.revoked_at.isoformat()
                if session.revoked_at
                else None,
            }
            for session in sessions
        ],
        "audit_logs": [
            {
                "id": str(log.id),
                "event_type": log.event_type,
                "status": log.status,
                "created_at": log.created_at.isoformat(),
                "detail_json": log.detail_json,
            }
            for log in audit_logs
        ],
    }


async def anonymize_user(db: AsyncSession, *, user_id: uuid.UUID) -> bool:
    user = await db.scalar(select(User).where(User.id == user_id))
    if user is None:
        return False
    user.email = f"deleted-{user.id}@redacted.local"
    user.full_name = "Deleted User"
    user.is_active = False
    user.password_hash = "revoked"
    user.email_verified_at = None
    await db.commit()
    return True
