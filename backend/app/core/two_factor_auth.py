"""Two-Factor Authentication (2FA) support."""

import secrets
import time
from datetime import UTC, datetime, timedelta
import hmac
import hashlib


class TOTPManager:
    """Time-based One-Time Password (TOTP) manager."""

    @staticmethod
    def generate_secret() -> str:
        """Generate a TOTP secret (base32 encoded)."""
        import pyotp
        return pyotp.random_base32()

    @staticmethod
    def verify_totp(secret: str, token: str) -> bool:
        """Verify a TOTP token."""
        import pyotp
        totp = pyotp.TOTP(secret)
        # Allow ±1 window for clock skew
        return totp.verify(token, valid_window=1)

    @staticmethod
    def get_provisioning_uri(secret: str, email: str, issuer: str = "StudentSystem") -> str:
        """Get provisioning URI for QR code generation."""
        import pyotp
        totp = pyotp.TOTP(secret)
        return totp.provisioning_uri(name=email, issuer_name=issuer)


class BackupCodesManager:
    """Generate and manage backup codes for 2FA recovery."""

    @staticmethod
    def generate_backup_codes(count: int = 10, length: int = 8) -> list[str]:
        """Generate backup codes for account recovery."""
        codes = []
        for _ in range(count):
            code = secrets.token_hex(length // 2).upper()
            # Format as XXXX-XXXX
            codes.append(f"{code[:4]}-{code[4:]}")
        return codes

    @staticmethod
    def hash_backup_code(code: str) -> str:
        """Hash backup code for secure storage."""
        return hashlib.sha256(code.encode()).hexdigest()

    @staticmethod
    def verify_backup_code(code: str, code_hash: str) -> bool:
        """Verify backup code matches hash."""
        return hmac.compare_digest(
            hashlib.sha256(code.encode()).hexdigest(),
            code_hash,
        )


class EmailOTPManager:
    """Email-based OTP for additional 2FA method."""

    @staticmethod
    def generate_email_otp() -> tuple[str, datetime]:
        """Generate a 6-digit OTP valid for 10 minutes."""
        otp = str(secrets.randbelow(999999)).zfill(6)
        expires_at = datetime.now(UTC) + timedelta(minutes=10)
        return otp, expires_at

    @staticmethod
    def verify_email_otp(provided_otp: str, stored_otp: str, expires_at: datetime) -> bool:
        """Verify email OTP is correct and not expired."""
        if datetime.now(UTC) > expires_at:
            return False
        return hmac.compare_digest(provided_otp, stored_otp)


class SMSOTPManager:
    """SMS-based OTP for 2FA (requires SMS provider integration)."""

    @staticmethod
    def generate_sms_otp() -> tuple[str, datetime]:
        """Generate a 6-digit OTP valid for 5 minutes."""
        otp = str(secrets.randbelow(999999)).zfill(6)
        expires_at = datetime.now(UTC) + timedelta(minutes=5)
        return otp, expires_at

    @staticmethod
    def verify_sms_otp(provided_otp: str, stored_otp: str, expires_at: datetime) -> bool:
        """Verify SMS OTP is correct and not expired."""
        if datetime.now(UTC) > expires_at:
            return False
        return hmac.compare_digest(provided_otp, stored_otp)


totp_manager = TOTPManager()
backup_codes_manager = BackupCodesManager()
email_otp_manager = EmailOTPManager()
sms_otp_manager = SMSOTPManager()
