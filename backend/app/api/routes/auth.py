from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.rate_limit import RateLimit
from app.core.security import create_access_token, verify_password
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import LoginRequest, LogoutResponse, TokenResponse, UserRead
from app.services.audit import write_audit_log

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


@router.post(
    "/login",
    response_model=TokenResponse,
    dependencies=[
        Depends(
            RateLimit(
                limit=settings.login_rate_limit_attempts,
                window_seconds=settings.login_rate_limit_window_seconds,
                scope="login",
            ),
        ),
    ],
)
async def login(
    payload: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    user = await db.scalar(select(User).where(User.email == payload.email.lower()))
    generic_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid email or password.",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if user is None:
        await write_audit_log(
            db,
            event_type="auth.login.failed",
            status="failure",
            target_resource="user",
            detail={"email": payload.email.lower(), "reason": "user_not_found"},
            request=request,
        )
        raise generic_error

    now = datetime.now(UTC)
    if user.lockout_until and user.lockout_until > now:
        await write_audit_log(
            db,
            actor_user_id=user.id,
            event_type="auth.login.locked",
            status="blocked",
            target_resource="user",
            detail={"email": user.email},
            request=request,
        )
        raise HTTPException(
            status_code=status.HTTP_423_LOCKED,
            detail="Account temporarily locked due to repeated failed logins.",
        )

    if not verify_password(payload.password, user.password_hash):
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= settings.login_rate_limit_attempts:
            user.lockout_until = now + timedelta(
                minutes=settings.account_lockout_minutes,
            )
            user.failed_login_attempts = 0
        await db.commit()
        await write_audit_log(
            db,
            actor_user_id=user.id,
            event_type="auth.login.failed",
            status="failure",
            target_resource="user",
            detail={"email": user.email, "reason": "bad_password"},
            request=request,
        )
        raise generic_error

    if not user.is_active:
        await write_audit_log(
            db,
            actor_user_id=user.id,
            event_type="auth.login.inactive",
            status="blocked",
            target_resource="user",
            detail={"email": user.email},
            request=request,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled.",
        )

    user.failed_login_attempts = 0
    user.lockout_until = None
    user.last_login_at = now
    await db.commit()

    token, expires_in = create_access_token(subject=user.id, role=user.role.value)
    await write_audit_log(
        db,
        actor_user_id=user.id,
        event_type="auth.login.success",
        status="success",
        target_resource="user",
        detail={"email": user.email, "role": user.role.value},
        request=request,
    )
    return TokenResponse(
        access_token=token,
        expires_in=expires_in,
        user=UserRead.model_validate(user),
    )


@router.get("/me", response_model=UserRead)
async def me(current_user: User = Depends(get_current_user)) -> UserRead:
    return UserRead.model_validate(current_user)


@router.post("/logout", response_model=LogoutResponse)
async def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LogoutResponse:
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.logout",
        status="success",
        target_resource="user",
        detail={"email": current_user.email},
        request=request,
    )
    return LogoutResponse(detail="Logged out. Discard the bearer token client-side.")

