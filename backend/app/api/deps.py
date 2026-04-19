from datetime import UTC, datetime
from collections.abc import Awaitable, Callable
from typing import Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.models.auth_security import UserSession
from app.db.session import get_db
from app.models.user import User, UserRole

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_token_payload(token: str = Depends(oauth2_scheme)) -> dict[str, Any]:
    return decode_token(token)


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
    user = await db.scalar(select(User).where(User.id == user_id))
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User is inactive or missing.",
        )
    session_id = payload.get("sid")
    if session_id:
        session = await db.scalar(
            select(UserSession).where(UserSession.id == session_id),
        )
        if (
            session is None
            or session.user_id != user.id
            or session.revoked_at is not None
            or session.compromised_at is not None
            or session.expires_at < datetime.now(UTC)
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
    return await db.scalar(select(UserSession).where(UserSession.id == session_id))


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


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"
