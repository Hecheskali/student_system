import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
    OAuth2PasswordBearer,
)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.security import decode_token
from app.core.time import is_before_now
from app.db.session import get_db
from app.models.auth_security import UserSession
from app.models.user import User, UserRole
from app.services.supabase_admin import SupabaseAdminService, SupabasePrincipal

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")
supabase_bearer_scheme = HTTPBearer(auto_error=True)
supabase_admin_service = SupabaseAdminService()


def get_token_payload(token: str = Depends(oauth2_scheme)) -> dict[str, Any]:
    return decode_token(token)


def _parse_uuid(value: Any, field_name: str) -> uuid.UUID:
    try:
        return uuid.UUID(str(value))
    except (TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication {field_name}.",
        ) from exc


async def get_current_user(
    payload: dict[str, Any] = Depends(get_token_payload),
    db: AsyncSession = Depends(get_db),
) -> User:
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication payload.",
        )
    user = await db.scalar(
        select(User).where(User.id == _parse_uuid(user_id, "subject")),
    )
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User is inactive or missing.",
        )
    session_id = payload.get("sid")
    if session_id:
        parsed_session_id = _parse_uuid(session_id, "session")
        session = await db.scalar(
            select(UserSession).where(UserSession.id == parsed_session_id),
        )
        if (
            session is None
            or session.user_id != user.id
            or session.revoked_at is not None
            or session.compromised_at is not None
            or is_before_now(session.expires_at)
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session is no longer valid.",
            )
    return user


async def get_current_session(
    payload: dict[str, Any] = Depends(get_token_payload),
    db: AsyncSession = Depends(get_db),
) -> UserSession | None:
    session_id = payload.get("sid")
    if not session_id:
        return None
    parsed_session_id = _parse_uuid(session_id, "session")
    return await db.scalar(
        select(UserSession).where(UserSession.id == parsed_session_id),
    )


def require_roles(*roles: UserRole) -> Callable[[User], Awaitable[User]]:
    async def dependency(
        current_user: User = Depends(get_current_user),
    ) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions.",
            )
        return current_user

    return dependency


async def require_supabase_headmaster(
    credentials: HTTPAuthorizationCredentials = Depends(supabase_bearer_scheme),
) -> SupabasePrincipal:
    principal = await run_in_threadpool(
        supabase_admin_service.get_principal_from_access_token,
        credentials.credentials,
    )
    if principal.role != UserRole.head_of_school.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the headmaster can manage teacher accounts.",
        )
    return principal


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"
