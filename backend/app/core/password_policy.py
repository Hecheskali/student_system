"""Password validation and policy enforcement."""

from datetime import UTC, datetime, timedelta
import re
from fastapi import HTTPException, status

from app.core.config import get_settings


class PasswordValidator:
    """Validates passwords against security policy."""

    def __init__(self):
        self.settings = get_settings()

    def validate(self, password: str) -> tuple[bool, str]:
        """Validate password against security policy.
        
        Returns: (is_valid, error_message)
        """
        
        # Length check
        if len(password) < self.settings.password_min_length:
            return False, f"Password must be at least {self.settings.password_min_length} characters"

        # Uppercase check
        if self.settings.password_require_uppercase and not re.search(r"[A-Z]", password):
            return False, "Password must contain at least one uppercase letter"

        # Numbers check
        if self.settings.password_require_numbers and not re.search(r"\d", password):
            return False, "Password must contain at least one number"

        # Special characters check
        if self.settings.password_require_special and not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
            return False, "Password must contain at least one special character (!@#$%^&*...)"

        # Common patterns to avoid
        common_passwords = [
            "password",
            "123456",
            "qwerty",
            "admin",
            "letmein",
            "welcome",
            "monkey",
            "dragon",
        ]
        
        if password.lower() in common_passwords:
            return False, "Password contains commonly used password pattern"

        # Check for sequential patterns
        if self._has_sequential_pattern(password):
            return False, "Password contains sequential characters (e.g., abc123)"

        # Check for repeated characters
        if self._has_repeated_characters(password):
            return False, "Password contains too many repeated characters"

        return True, ""

    def is_password_expired(self, last_password_changed_at: datetime | None) -> bool:
        """Check whether a password is past the configured rotation window."""
        if last_password_changed_at is None:
            return True
        cutoff = datetime.now(UTC) - timedelta(days=self.settings.password_expiry_days)
        return last_password_changed_at <= cutoff

    @staticmethod
    def _has_sequential_pattern(password: str) -> bool:
        """Check for sequential character patterns."""
        for i in range(len(password) - 2):
            if ord(password[i]) + 1 == ord(password[i + 1]) and ord(password[i + 1]) + 1 == ord(password[i + 2]):
                return True
        return False

    @staticmethod
    def _has_repeated_characters(password: str) -> bool:
        """Check if password has too many repeated characters."""
        max_repetition = 0
        current_repetition = 1

        for i in range(len(password) - 1):
            if password[i].lower() == password[i + 1].lower():
                current_repetition += 1
                max_repetition = max(max_repetition, current_repetition)
            else:
                current_repetition = 1

        return max_repetition > 3  # More than 3 repetitions is suspicious


password_validator = PasswordValidator()
