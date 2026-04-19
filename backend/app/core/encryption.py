"""Encryption utilities for sensitive data at rest."""

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
import base64
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

from app.core.config import get_settings


class EncryptionManager:
    """Handles encryption/decryption of sensitive data."""

    def __init__(self, master_key: str | None = None):
        settings = get_settings()
        self.master_key = master_key or settings.jwt_secret_key.get_secret_value()[:32]
        self.cipher = self._create_cipher()

    def _create_cipher(self) -> Fernet:
        """Create Fernet cipher from master key."""
        key = base64.urlsafe_b64encode(
            PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=b"student_system_v1",
                iterations=100000,
            ).derive(self.master_key.encode())
        )
        return Fernet(key)

    def encrypt(self, data: str) -> str:
        """Encrypt string data."""
        return self.cipher.encrypt(data.encode()).decode()

    def decrypt(self, encrypted_data: str) -> str:
        """Decrypt string data."""
        return self.cipher.decrypt(encrypted_data.encode()).decode()


encryption_manager = EncryptionManager()
