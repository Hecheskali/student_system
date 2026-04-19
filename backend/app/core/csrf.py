"""CSRF/XSRF token generation and validation."""

import secrets
import hmac
import hashlib
from datetime import UTC, datetime, timedelta

from app.core.config import get_settings


class CSRFTokenManager:
    """Manages CSRF token creation and validation."""

    CSRF_TOKEN_EXPIRES_MINUTES = 60

    @staticmethod
    def generate_csrf_token() -> str:
        """Generate a secure CSRF token."""
        return secrets.token_urlsafe(32)

    @staticmethod
    def generate_double_submit_cookie_token(session_id: str) -> tuple[str, str]:
        """Generate double-submit cookie tokens for enhanced CSRF protection.
        
        Returns: (token, cookie_value)
        """
        settings = get_settings()
        
        # Generate random token
        token = secrets.token_urlsafe(32)
        
        # Hash for cookie that includes session binding
        token_hash = hmac.new(
            settings.jwt_secret_key.get_secret_value().encode(),
            f"{session_id}:{token}".encode(),
            hashlib.sha256,
        ).hexdigest()
        
        return token, token_hash

    @staticmethod
    def validate_csrf_token(
        token: str,
        cookie_value: str,
        session_id: str,
    ) -> bool:
        """Validate CSRF double-submit cookie token."""
        settings = get_settings()
        
        expected_hash = hmac.new(
            settings.jwt_secret_key.get_secret_value().encode(),
            f"{session_id}:{token}".encode(),
            hashlib.sha256,
        ).hexdigest()
        
        # Use constant-time comparison to prevent timing attacks
        return hmac.compare_digest(expected_hash, cookie_value)


csrf_manager = CSRFTokenManager()
