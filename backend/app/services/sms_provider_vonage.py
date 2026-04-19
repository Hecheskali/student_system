"""
Concrete SMS provider implementation using Vonage API.
Vonage (formerly Nexmo) provides reliable SMS delivery globally.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class SmsDeliveryResult:
    ok: bool
    error: str | None = None
    message_id: str | None = None


class VonageSmsProvider:
    """Concrete SMS provider using Vonage API."""

    BASE_URL = "https://rest.nexmo.com"
    
    def __init__(self, api_key: str | None = None, api_secret: str | None = None):
        self.settings = get_settings()
        self.api_key = api_key or self.settings.vonage_api_key
        
        # Handle SecretStr properly
        if api_secret:
            self.api_secret = api_secret
        elif self.settings.vonage_api_secret:
            self.api_secret = self.settings.vonage_api_secret.get_secret_value()
        else:
            self.api_secret = None
            
        self.from_number = self.settings.vonage_from_number
        
        if not self.api_key or not self.api_secret or not self.from_number:
            raise ValueError("Vonage SMS configuration is incomplete")

    async def send(
        self,
        *,
        recipient: str,
        message: str,
    ) -> SmsDeliveryResult:
        """Send SMS via Vonage API.
        
        Args:
            recipient: Phone number in E.164 format (e.g., +1234567890)
            message: SMS message body (max 160 characters)
        
        Returns:
            SmsDeliveryResult with ok status and message_id or error
        """
        
        # Validate message length
        if len(message) > 160:
            logger.warning(
                "SMS message truncated to 160 characters",
                extra={"recipient": recipient, "original_length": len(message)},
            )
            message = message[:160]

        payload: dict[str, Any] = {
            "api_key": self.api_key,
            "api_secret": self.api_secret,
            "to": recipient,
            "from": self.from_number,
            "text": message,
            "type": "unicode",  # Support special characters
        }

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    f"{self.BASE_URL}/sms/json",
                    json=payload,
                )

            if response.status_code == 200:
                data = response.json()
                
                # Check message status
                if "messages" in data and len(data["messages"]) > 0:
                    message_data = data["messages"][0]
                    status = message_data.get("status")
                    message_id = message_data.get("message-id")
                    
                    if status == "0":  # Success
                        logger.info(
                            "SMS sent successfully via Vonage",
                            extra={
                                "recipient": recipient,
                                "message_id": message_id,
                            },
                        )
                        return SmsDeliveryResult(ok=True, message_id=message_id)
                    else:
                        error_msg = message_data.get("error-text", f"Error code {status}")
                        logger.error(
                            f"Vonage SMS error: {error_msg}",
                            extra={
                                "recipient": recipient,
                                "status": status,
                                "error": error_msg,
                            },
                        )
                        return SmsDeliveryResult(ok=False, error=error_msg)

            logger.error(
                f"Vonage API error: {response.status_code}",
                extra={
                    "recipient": recipient,
                    "status_code": response.status_code,
                    "response": response.text,
                },
            )

            return SmsDeliveryResult(
                ok=False,
                error=f"Vonage API returned {response.status_code}",
            )

        except httpx.TimeoutException:
            logger.error(
                "Vonage API timeout",
                extra={"recipient": recipient},
            )
            return SmsDeliveryResult(
                ok=False,
                error="Request timeout - try again later",
            )
        except Exception as exc:
            logger.error(
                f"Unexpected error sending SMS: {exc}",
                extra={"recipient": recipient, "error": str(exc)},
            )
            return SmsDeliveryResult(
                ok=False,
                error=f"Unexpected error: {str(exc)}",
            )


class VonageSmsTemplate:
    """Helper for common SMS templates."""

    @staticmethod
    def verification_code_sms(code: str, app_name: str = "Student System") -> str:
        """Generate SMS for verification code."""
        return f"{app_name}: Your verification code is {code}. Valid for 10 minutes. Never share this code."

    @staticmethod
    def password_reset_sms(code: str, app_name: str = "Student System") -> str:
        """Generate SMS for password reset code."""
        return f"{app_name}: Your password reset code is {code}. Valid for 30 minutes. Do not share."

    @staticmethod
    def login_alert_sms(
        location: str,
        device: str,
        app_name: str = "Student System",
    ) -> str:
        """Generate SMS for suspicious login alert."""
        return f"{app_name}: Your account was accessed from {location} on {device}. If not you, secure your account immediately."

    @staticmethod
    def account_locked_sms(app_name: str = "Student System") -> str:
        """Generate SMS for account lockout notification."""
        return f"{app_name}: Your account was locked due to multiple failed login attempts. Contact support to unlock."


# Instantiate the provider (will be used by outbox service)
vonage_provider = VonageSmsProvider()
