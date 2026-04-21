import uuid
from typing import Any

from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AuditLog


async def write_audit_log(
    db: AsyncSession,
    *,
    event_type: str,
    status: str = "success",
    actor_user_id: uuid.UUID | None = None,
    target_resource: str | None = None,
    detail: dict[str, Any] | None = None,
    request: Request | None = None,
) -> None:
    record = AuditLog(
        actor_user_id=actor_user_id,
        event_type=event_type,
        status=status,
        target_resource=target_resource,
        detail_json=detail or {},
        ip_address=request.client.host if request and request.client else None,
        user_agent=request.headers.get("user-agent") if request else None,
        request_id=getattr(request.state, "request_id", None) if request else None,
    )
    db.add(record)
    await db.commit()
