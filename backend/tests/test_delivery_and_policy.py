from datetime import UTC, datetime, timedelta

from app.core.password_policy import password_validator
from app.core.two_factor_auth import backup_codes_manager, totp_manager
from app.services.outbox import render_template


def test_password_expiry_is_detected() -> None:
    expired_at = datetime.now(UTC) - timedelta(days=365)
    assert password_validator.is_password_expired(expired_at) is True


def test_password_expiry_allows_recent_passwords() -> None:
    changed_recently = datetime.now(UTC) - timedelta(days=1)
    assert password_validator.is_password_expired(changed_recently) is False


def test_totp_round_trip() -> None:
    secret = totp_manager.generate_secret()
    import pyotp

    token = pyotp.TOTP(secret).now()
    assert totp_manager.verify_totp(secret, token) is True


def test_backup_code_hash_and_verify() -> None:
    code = backup_codes_manager.generate_backup_codes(count=1)[0]
    hashed = backup_codes_manager.hash_backup_code(code)
    assert backup_codes_manager.verify_backup_code(code, hashed) is True


def test_render_password_reset_template() -> None:
    subject, body = render_template("password_reset", {"token": "abc123"})
    assert subject == "Reset your Student System password"
    assert "abc123" in body


def test_render_email_verification_template() -> None:
    subject, body = render_template("email_verification", {"token": "verify456"})
    assert subject == "Verify your Student System email"
    assert "verify456" in body
