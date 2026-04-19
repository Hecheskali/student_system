from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_session, get_current_user
from app.core.config import get_settings
from app.core.encryption import encryption_manager
from app.core.password_policy import password_validator
from app.core.refresh_tokens import refresh_token_manager
from app.core.two_factor_auth import backup_codes_manager, totp_manager
from app.core.security import hash_password, hash_opaque_token
from app.core.rate_limit import RateLimit
from app.db.session import get_db
from app.models.auth_security import RefreshToken, SecurityToken, UserSession
from app.models.user import User
from app.schemas.auth import (
    EmailVerificationConfirmRequest,
    LoginRequest,
    LogoutResponse,
    PasswordChangeRequest,
    PasswordResetConfirmRequest,
    PasswordResetRequest,
    RefreshTokenRequest,
    SecurityActionResponse,
    SessionRead,
    TokenResponse,
    TwoFactorConfirmRequest,
    TwoFactorDisableRequest,
    TwoFactorSetupResponse,
    UserRead,
)
from app.services.audit import write_audit_log
from app.services.alerts import send_alert
from app.services.auth_lifecycle import (
    consume_security_token,
    create_security_token,
    issue_session_tokens,
    revoke_all_user_sessions,
    revoke_session,
    rotate_refresh_token,
)
from app.services.outbox import enqueue_email
from app.core.security import verify_password

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

    if user.two_factor_enabled:
        if not _verify_login_second_factor(user, payload):
            await write_audit_log(
                db,
                actor_user_id=user.id,
                event_type="auth.login.2fa_failed",
                status="failure",
                target_resource="user",
                detail={"email": user.email},
                request=request,
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Valid two-factor code required.",
            )

    user.failed_login_attempts = 0
    user.lockout_until = None
    user.last_login_at = now
    if password_validator.is_password_expired(user.last_password_changed_at):
        user.must_change_password = True
    access_token, refresh_token, expires_in, session = await issue_session_tokens(
        db,
        user=user,
        request=request,
    )
    await db.commit()
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
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
        session_id=session.id,
        user=UserRead.model_validate(user),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_access_token(
    payload: RefreshTokenRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    token_payload = refresh_token_manager.validate_refresh_token(payload.refresh_token)
    user_id = token_payload.get("sub")
    session_id = token_payload.get("sid")
    jti = token_payload.get("jti")
    if not user_id or not session_id or not jti:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token payload.",
        )

    user = await db.scalar(select(User).where(User.id == user_id))
    token_record = await db.scalar(select(RefreshToken).where(RefreshToken.jti == jti))
    if user is None or token_record is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token is invalid.",
        )
    if token_record.token_hash != hash_opaque_token(payload.refresh_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token is invalid.",
        )
    if token_record.revoked_at is not None:
        session = await db.scalar(select(UserSession).where(UserSession.id == session_id))
        if session is not None:
            await revoke_session(db, session=session, compromised=True)
        await revoke_all_user_sessions(db, user_id=user_id, compromised=True)
        await send_alert(
            title="Refresh token reuse detected",
            body=f"User {user_id} triggered refresh token reuse detection.",
            severity="critical",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token reuse detected. All sessions revoked.",
        )
    if token_record.expires_at < datetime.now(UTC):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired.",
        )

    access_token, refresh_token, expires_in, session = await rotate_refresh_token(
        db,
        token_record=token_record,
        user=user,
        request=request,
    )
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
        session_id=session.id,
        user=UserRead.model_validate(user),
    )


@router.get("/me", response_model=UserRead)
async def me(current_user: User = Depends(get_current_user)) -> UserRead:
    return UserRead.model_validate(current_user)


@router.post("/logout", response_model=LogoutResponse)
async def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    current_session: UserSession | None = Depends(get_current_session),
    db: AsyncSession = Depends(get_db),
) -> LogoutResponse:
    if current_session is not None:
        await revoke_session(db, session=current_session)
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


@router.post("/logout-all", response_model=LogoutResponse)
async def logout_all(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LogoutResponse:
    await revoke_all_user_sessions(db, user_id=current_user.id)
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.logout_all",
        status="success",
        target_resource="user",
        detail={"email": current_user.email},
        request=request,
    )
    return LogoutResponse(detail="All sessions have been revoked.")


@router.post("/password/change", response_model=SecurityActionResponse)
async def change_password(
    payload: PasswordChangeRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    if not verify_password(payload.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect.",
        )
    valid, message = password_validator.validate(payload.new_password)
    if not valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)
    current_user.password_hash = hash_password(payload.new_password)
    current_user.must_change_password = False
    current_user.last_password_changed_at = datetime.now(UTC)
    await db.commit()
    await revoke_all_user_sessions(db, user_id=current_user.id)
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.password.changed",
        status="success",
        target_resource="user",
        detail={"email": current_user.email},
        request=request,
    )
    return SecurityActionResponse(detail="Password updated. Please log in again.")


@router.get("/sessions", response_model=list[SessionRead])
async def list_sessions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[SessionRead]:
    sessions = (
        await db.scalars(
            select(UserSession)
            .where(UserSession.user_id == current_user.id)
            .order_by(UserSession.last_seen_at.desc())
        )
    ).all()
    return [SessionRead.model_validate(session) for session in sessions]


@router.post("/2fa/setup", response_model=TwoFactorSetupResponse)
async def setup_two_factor(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> TwoFactorSetupResponse:
    secret = totp_manager.generate_secret()
    backup_codes = backup_codes_manager.generate_backup_codes()
    current_user.two_factor_secret = encryption_manager.encrypt(secret)
    current_user.two_factor_enabled = False
    current_user.two_factor_verified_at = None
    current_user.backup_code_hashes = [
        backup_codes_manager.hash_backup_code(code) for code in backup_codes
    ]
    await db.commit()
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.2fa.setup_started",
        status="success",
        target_resource="user",
        detail={"email": current_user.email},
        request=request,
    )
    return TwoFactorSetupResponse(
        detail="Two-factor secret generated. Confirm with a valid OTP to enable it.",
        secret=secret,
        provisioning_uri=totp_manager.get_provisioning_uri(secret, current_user.email),
        backup_codes=backup_codes,
    )


@router.post("/2fa/confirm", response_model=SecurityActionResponse)
async def confirm_two_factor(
    payload: TwoFactorConfirmRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    if not current_user.two_factor_secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Two-factor setup has not been started.",
        )
    secret = encryption_manager.decrypt(current_user.two_factor_secret)
    if not totp_manager.verify_totp(secret, payload.otp_code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP code.",
        )
    current_user.two_factor_enabled = True
    current_user.two_factor_verified_at = datetime.now(UTC)
    await db.commit()
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.2fa.enabled",
        status="success",
        target_resource="user",
        detail={"email": current_user.email},
        request=request,
    )
    return SecurityActionResponse(detail="Two-factor authentication enabled.")


@router.post("/2fa/disable", response_model=SecurityActionResponse)
async def disable_two_factor(
    payload: TwoFactorDisableRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    if not current_user.two_factor_enabled:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Two-factor authentication is not enabled.",
        )
    if not verify_password(payload.password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password is incorrect.",
        )
    if not _verify_user_second_factor(
        current_user,
        otp_code=payload.otp_code,
        backup_code=payload.backup_code,
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Valid second factor required to disable 2FA.",
        )
    current_user.two_factor_enabled = False
    current_user.two_factor_secret = None
    current_user.two_factor_verified_at = None
    current_user.backup_code_hashes = []
    await db.commit()
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.2fa.disabled",
        status="success",
        target_resource="user",
        detail={"email": current_user.email},
        request=request,
    )
    return SecurityActionResponse(detail="Two-factor authentication disabled.")


@router.post("/sessions/{session_id}/revoke", response_model=SecurityActionResponse)
async def revoke_one_session(
    session_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    session = await db.scalar(
        select(UserSession).where(
            UserSession.id == session_id,
            UserSession.user_id == current_user.id,
        )
    )
    if session is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found.",
        )
    await revoke_session(db, session=session)
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.session.revoked",
        status="success",
        target_resource="session",
        detail={"session_id": session_id},
        request=request,
    )
    return SecurityActionResponse(detail="Session revoked.")


@router.post("/password-reset/request", response_model=SecurityActionResponse)
async def request_password_reset(
    payload: PasswordResetRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    user = await db.scalar(select(User).where(User.email == payload.email.lower()))
    token_preview: str | None = None
    if user is not None:
        token_preview = await create_security_token(
            db,
            user=user,
            purpose="password_reset",
            expires_at=datetime.now(UTC)
            + timedelta(minutes=settings.password_reset_expire_minutes),
            meta_json={"reason": "self_service"},
        )
        await write_audit_log(
            db,
            actor_user_id=user.id,
            event_type="auth.password_reset.requested",
            status="success",
            target_resource="user",
            detail={"email": user.email},
            request=request,
        )
        await enqueue_email(
            db,
            recipient=user.email,
            subject="Reset your Student System password",
            template_key="password_reset",
            payload={"token": token_preview},
        )
    return SecurityActionResponse(
        detail="If the email exists, a password reset token has been issued.",
        token_preview=token_preview if settings.app_env != "production" else None,
    )


@router.post("/password-reset/confirm", response_model=SecurityActionResponse)
async def confirm_password_reset(
    payload: PasswordResetConfirmRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    valid, message = password_validator.validate(payload.new_password)
    if not valid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)
    token = await consume_security_token(
        db,
        raw_token=payload.token,
        purpose="password_reset",
    )
    if token is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password reset token is invalid or expired.",
        )
    user = await db.scalar(select(User).where(User.id == token.user_id))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    user.password_hash = hash_password(payload.new_password)
    user.must_change_password = False
    user.last_password_changed_at = datetime.now(UTC)
    await db.commit()
    await revoke_all_user_sessions(db, user_id=user.id)
    await write_audit_log(
        db,
        actor_user_id=user.id,
        event_type="auth.password_reset.completed",
        status="success",
        target_resource="user",
        detail={"email": user.email},
        request=request,
    )
    return SecurityActionResponse(detail="Password reset completed.")


@router.post("/email-verification/request", response_model=SecurityActionResponse)
async def request_email_verification(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    token_preview = await create_security_token(
        db,
        user=current_user,
        purpose="email_verification",
        expires_at=datetime.now(UTC)
        + timedelta(hours=settings.email_verification_expire_hours),
    )
    await enqueue_email(
        db,
        recipient=current_user.email,
        subject="Verify your Student System email",
        template_key="email_verification",
        payload={"token": token_preview},
    )
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="auth.email_verification.requested",
        status="success",
        target_resource="user",
        detail={"email": current_user.email},
        request=request,
    )
    return SecurityActionResponse(
        detail="Verification token issued.",
        token_preview=token_preview if settings.app_env != "production" else None,
    )


@router.post("/email-verification/confirm", response_model=SecurityActionResponse)
async def confirm_email_verification(
    payload: EmailVerificationConfirmRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> SecurityActionResponse:
    token = await consume_security_token(
        db,
        raw_token=payload.token,
        purpose="email_verification",
    )
    if token is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email verification token is invalid or expired.",
        )
    user = await db.scalar(select(User).where(User.id == token.user_id))
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    user.email_verified_at = datetime.now(UTC)
    await db.commit()
    await write_audit_log(
        db,
        actor_user_id=user.id,
        event_type="auth.email_verified",
        status="success",
        target_resource="user",
        detail={"email": user.email},
        request=request,
    )
    return SecurityActionResponse(detail="Email verified.")


def _verify_login_second_factor(user: User, payload: LoginRequest) -> bool:
    return _verify_user_second_factor(
        user,
        otp_code=payload.otp_code,
        backup_code=payload.backup_code,
    )


def _verify_user_second_factor(
    user: User,
    *,
    otp_code: str | None,
    backup_code: str | None,
) -> bool:
    if user.two_factor_secret and otp_code:
        secret = encryption_manager.decrypt(user.two_factor_secret)
        if totp_manager.verify_totp(secret, otp_code):
            return True
    if backup_code:
        normalized = backup_code.strip().upper()
        hashed = backup_codes_manager.hash_backup_code(normalized)
        if hashed in (user.backup_code_hashes or []):
            remaining = [code for code in user.backup_code_hashes if code != hashed]
            user.backup_code_hashes = remaining
            return True
    return False
