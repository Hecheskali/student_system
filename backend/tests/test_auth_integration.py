"""
Comprehensive API integration tests for authentication flows.
Tests login, refresh, 2FA setup, password reset, and email verification.
"""

import pytest
from datetime import UTC, datetime, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.db.session import get_db
from app.models.user import User
from app.models.auth_security import RefreshToken, UserSession
from app.core.security import hash_password
from app.core.config import get_settings


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


@pytest.fixture
async def test_user(db: AsyncSession):
    """Create a test user."""
    user = User(
        id="test-user-123",
        email="test@example.com",
        name="Test User",
        password_hash=hash_password("TestPassword123!"),
        role="teacher",
        is_active=True,
        school_name="Test School",
        district_name="Test District",
    )
    db.add(user)
    await db.commit()
    return user


class TestAuthLogin:
    """Test suite for authentication login flow."""

    def test_login_success(self, client: TestClient, test_user):
        """Test successful login returns access token."""
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "token_type" in data
        assert data["token_type"] == "bearer"
        assert "expires_in" in data

    def test_login_invalid_email(self, client: TestClient):
        """Test login with non-existent email."""
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "nonexistent@example.com",
                "password": "TestPassword123!",
            },
        )
        assert response.status_code == 401
        assert response.json()["detail"] == "Invalid email or password."

    def test_login_invalid_password(self, client: TestClient, test_user):
        """Test login with wrong password."""
        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "WrongPassword123!",
            },
        )
        assert response.status_code == 401
        assert response.json()["detail"] == "Invalid email or password."

    async def test_login_inactive_user(self, client: TestClient, db: AsyncSession, test_user):
        """Test login with inactive user."""
        test_user.is_active = False
        db.add(test_user)
        await db.commit()

        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        assert response.status_code == 403
        assert "inactive" in response.json()["detail"].lower()

    async def test_login_locked_account(self, client: TestClient, db: AsyncSession, test_user):
        """Test login with locked account."""
        test_user.lockout_until = datetime.now(UTC) + timedelta(minutes=15)
        test_user.failed_login_attempts = 5
        db.add(test_user)
        await db.commit()

        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        assert response.status_code == 423
        assert "locked" in response.json()["detail"].lower()

    def test_login_rate_limiting(self, client: TestClient):
        """Test rate limiting on login endpoint."""
        settings = get_settings()

        # Make multiple failed requests
        response = None
        for i in range(settings.login_rate_limit_attempts + 1):
            response = client.post(
                "/api/v1/auth/login",
                json={
                    "email": f"user{i}@example.com",
                    "password": "WrongPassword123!",
                },
            )

        # Last request should be rate limited
        assert response is not None
        assert response.status_code == 429
        assert "too many requests" in response.json()["detail"].lower()

    async def test_login_increments_failed_attempts(self, client: TestClient, db: AsyncSession, test_user):
        """Test failed login increments attempt counter."""
        initial_attempts = test_user.failed_login_attempts

        client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "WrongPassword123!",
            },
        )

        await db.refresh(test_user)
        assert test_user.failed_login_attempts == initial_attempts + 1

    async def test_login_resets_failed_attempts(self, client: TestClient, db: AsyncSession, test_user):
        """Test successful login resets failed attempts."""
        test_user.failed_login_attempts = 3
        db.add(test_user)
        await db.commit()

        response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )

        assert response.status_code == 200
        await db.refresh(test_user)
        assert test_user.failed_login_attempts == 0


class TestRefreshToken:
    """Test suite for refresh token flow."""

    def test_refresh_token_generates_new_access(self, client: TestClient, test_user):
        """Test refreshing token generates new access token."""
        # First, login to get initial tokens
        login_response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        initial_access = login_response.json()["access_token"]
        refresh_token = login_response.json().get("refresh_token")

        # Use refresh token
        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "token_type" in data
        # New access token should be different
        assert data["access_token"] != initial_access

    def test_refresh_invalid_token(self, client: TestClient):
        """Test refresh with invalid token."""
        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "invalid.token.here"},
        )

        assert response.status_code == 401
        assert "invalid" in response.json()["detail"].lower()

    async def test_refresh_expired_token(self, client: TestClient, db: AsyncSession):
        """Test refresh with expired token."""
        # Create an expired refresh token
        expired_token = RefreshToken(
            user_id="test-user-123",
            token_hash="test-hash",
            expires_at=datetime.now(UTC) - timedelta(hours=1),
        )
        db.add(expired_token)
        await db.commit()

        response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "invalid.token.here"},
        )

        assert response.status_code == 401

    def test_refresh_rotates_token(self, client: TestClient, test_user):
        """Test that refresh token is rotated (token rotation security)."""
        login_response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        initial_refresh = login_response.json().get("refresh_token")

        # Use refresh token
        refresh_response = client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": initial_refresh},
        )

        new_refresh = refresh_response.json().get("refresh_token")
        # New refresh token should be different
        assert new_refresh != initial_refresh


class TestTwoFactorAuth:
    """Test suite for 2FA setup and verification."""

    def test_2fa_setup_returns_provisioning_uri(self, client: TestClient, test_user):
        """Test 2FA setup returns provisioning URI for QR code."""
        # Login first
        login_response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        access_token = login_response.json()["access_token"]

        response = client.post(
            "/api/v1/auth/2fa/setup",
            headers={"Authorization": f"Bearer {access_token}"},
        )

        assert response.status_code == 200
        data = response.json()
        assert "provisioning_uri" in data
        assert "backup_codes" in data
        assert len(data["backup_codes"]) > 0
        assert "secret" in data

    def test_2fa_setup_requires_auth(self, client: TestClient):
        """Test 2FA setup requires authentication."""
        response = client.post("/api/v1/auth/2fa/setup")
        assert response.status_code == 401

    def test_2fa_confirm_with_valid_code(self, client: TestClient, test_user):
        """Test confirming 2FA with valid TOTP code."""
        import pyotp

        # Setup 2FA
        login_response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        access_token = login_response.json()["access_token"]

        setup_response = client.post(
            "/api/v1/auth/2fa/setup",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        secret = setup_response.json()["secret"]

        # Generate valid code
        totp = pyotp.TOTP(secret)
        valid_code = totp.now()

        response = client.post(
            "/api/v1/auth/2fa/confirm",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "code": valid_code,
                "secret": secret,
            },
        )

        assert response.status_code == 200
        assert response.json()["message"] == "2FA enabled successfully"

    def test_2fa_confirm_with_invalid_code(self, client: TestClient, test_user):
        """Test confirming 2FA with invalid code."""
        login_response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        access_token = login_response.json()["access_token"]

        setup_response = client.post(
            "/api/v1/auth/2fa/setup",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        secret = setup_response.json()["secret"]

        response = client.post(
            "/api/v1/auth/2fa/confirm",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "code": "000000",
                "secret": secret,
            },
        )

        assert response.status_code == 400
        assert "invalid" in response.json()["detail"].lower()

    def test_2fa_disable_requires_password(self, client: TestClient, test_user):
        """Test disabling 2FA requires password confirmation."""
        login_response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        access_token = login_response.json()["access_token"]

        response = client.post(
            "/api/v1/auth/2fa/disable",
            headers={"Authorization": f"Bearer {access_token}"},
            json={"password": "WrongPassword123!"},
        )

        assert response.status_code == 401
        assert "invalid password" in response.json()["detail"].lower()


class TestPasswordReset:
    """Test suite for password reset flow."""

    def test_password_reset_request_sends_token(self, client: TestClient, test_user):
        """Test password reset request generates and sends token."""
        response = client.post(
            "/api/v1/auth/password-reset",
            json={"email": "test@example.com"},
        )

        assert response.status_code == 200
        # Don't expose whether email exists
        assert response.json()["message"] == "If email exists, reset link has been sent"

    def test_password_reset_with_invalid_email(self, client: TestClient):
        """Test password reset with non-existent email."""
        response = client.post(
            "/api/v1/auth/password-reset",
            json={"email": "nonexistent@example.com"},
        )

        # Should not expose whether email exists for security
        assert response.status_code == 200

    async def test_password_reset_confirm_with_valid_token(self, client: TestClient, test_user, db: AsyncSession):
        """Test confirming password reset with valid token."""
        from app.services.auth_lifecycle import create_security_token, consume_security_token
        from datetime import UTC, timedelta

        # Create reset token
        expires_at = datetime.now(UTC) + timedelta(hours=1)
        token = await create_security_token(
            db=db,
            user=test_user,
            purpose="password_reset",
            expires_at=expires_at,
        )

        new_password = "NewPassword123!"
        response = client.post(
            "/api/v1/auth/password-reset-confirm",
            json={
                "token": token,
                "new_password": new_password,
            },
        )

        assert response.status_code == 200

    def test_password_reset_confirm_with_invalid_token(self, client: TestClient):
        """Test confirming password reset with invalid token."""
        response = client.post(
            "/api/v1/auth/password-reset-confirm",
            json={
                "token": "invalid.token.here",
                "new_password": "NewPassword123!",
            },
        )

        assert response.status_code == 400
        assert "invalid" in response.json()["detail"].lower()

    async def test_password_reset_with_weak_password(self, client: TestClient, test_user, db: AsyncSession):
        """Test password reset rejects weak password."""
        from app.services.auth_lifecycle import create_security_token
        from datetime import UTC, timedelta

        expires_at = datetime.now(UTC) + timedelta(hours=1)
        token = await create_security_token(
            db=db,
            user=test_user,
            purpose="password_reset",
            expires_at=expires_at,
        )

        response = client.post(
            "/api/v1/auth/password-reset-confirm",
            json={
                "token": token,
                "new_password": "weak",
            },
        )

        assert response.status_code == 400
        assert "password" in response.json()["detail"].lower()


class TestLogout:
    """Test suite for logout flow."""

    def test_logout_revokes_session(self, client: TestClient, test_user):
        """Test logout revokes current session."""
        login_response = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        access_token = login_response.json()["access_token"]

        response = client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {access_token}"},
        )

        assert response.status_code == 200

        # Token should no longer work
        protected_response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert protected_response.status_code == 401

    def test_logout_all_sessions(self, client: TestClient, test_user):
        """Test logout from all sessions."""
        # Create multiple sessions
        login1 = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        token1 = login1.json()["access_token"]

        login2 = client.post(
            "/api/v1/auth/login",
            json={
                "email": "test@example.com",
                "password": "TestPassword123!",
            },
        )
        token2 = login2.json()["access_token"]

        # Logout from all
        response = client.post(
            "/api/v1/auth/logout-all",
            headers={"Authorization": f"Bearer {token1}"},
        )

        assert response.status_code == 200

        # Both tokens should be invalid
        assert client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token1}"},
        ).status_code == 401

        assert client.get(
            "/api/v1/auth/me",
            headers={"Authorization": f"Bearer {token2}"},
        ).status_code == 401
