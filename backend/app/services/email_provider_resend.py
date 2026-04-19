"""
Concrete email provider implementation using Resend API.
Resend is a modern email API with better deliverability than generic SMTP.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class DeliveryResult:
    ok: bool
    error: str | None = None
    message_id: str | None = None


class ResendEmailProvider:
    """Concrete email provider using Resend API."""

    BASE_URL = "https://api.resend.com"
    
    def __init__(self, api_key: str | None = None):
        self.settings = get_settings()
        self.api_key = api_key or self.settings.resend_api_key
        if not self.api_key:
            raise ValueError("RESEND_API_KEY is not configured")

    async def send(
        self,
        *,
        recipient: str,
        subject: str,
        body: str,
        html: str | None = None,
    ) -> DeliveryResult:
        """Send email via Resend API.
        
        Args:
            recipient: Email address to send to
            subject: Email subject line
            body: Plain text email body
            html: Optional HTML version of email
        
        Returns:
            DeliveryResult with ok status and message_id or error
        """
        
        payload: dict[str, Any] = {
            "from": self.settings.email_from_address,
            "to": recipient,
            "subject": subject,
        }

        # Send either HTML or plain text
        if html:
            payload["html"] = html
        else:
            payload["text"] = body

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{self.BASE_URL}/emails",
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                )

            if response.status_code == 200:
                data = response.json()
                message_id = data.get("id")
                logger.info(
                    f"Email sent successfully via Resend",
                    extra={
                        "recipient": recipient,
                        "message_id": message_id,
                        "subject": subject,
                    },
                )
                return DeliveryResult(ok=True, message_id=message_id)

            error_detail = response.text
            try:
                error_data = response.json()
                error_detail = error_data.get("message", error_detail)
            except Exception:
                pass

            logger.error(
                f"Resend API error: {response.status_code}",
                extra={
                    "recipient": recipient,
                    "status_code": response.status_code,
                    "error": error_detail,
                },
            )
            
            return DeliveryResult(
                ok=False,
                error=f"Resend API returned {response.status_code}: {error_detail}",
            )

        except httpx.TimeoutException:
            logger.error(
                "Resend API timeout",
                extra={"recipient": recipient},
            )
            return DeliveryResult(
                ok=False,
                error="Request timeout - try again later",
            )
        except Exception as exc:
            logger.error(
                f"Unexpected error sending email: {exc}",
                extra={"recipient": recipient, "error": str(exc)},
            )
            return DeliveryResult(
                ok=False,
                error=f"Unexpected error: {str(exc)}",
            )


class ResendEmailTemplate:
    """Helper for common email templates with Resend API."""

    @staticmethod
    def login_verification_email(verification_code: str, user_name: str) -> dict[str, str]:
        """Generate login verification email with HTML template."""
        
        html = f"""
        <html>
            <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                <div style="max-width: 600px; margin: 0 auto; background-color: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    <h2 style="color: #1450B3; margin-top: 0;">Verify Your Login</h2>
                    
                    <p>Hi {user_name},</p>
                    
                    <p>We received a login attempt to your Student System account. To proceed, please enter or click the verification code below:</p>
                    
                    <div style="background-color: #f0f0f0; border-left: 4px solid #1450B3; padding: 15px; margin: 20px 0; border-radius: 4px;">
                        <p style="margin: 0; font-size: 24px; font-weight: bold; font-family: monospace; letter-spacing: 2px; color: #1450B3;">
                            {verification_code}
                        </p>
                    </div>
                    
                    <p style="color: #666; font-size: 12px;">This code expires in 10 minutes.</p>
                    
                    <p>If you didn't attempt to log in, ignore this email. For security, never share this code.</p>
                    
                    <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
                    
                    <p style="color: #999; font-size: 12px; margin: 0;">
                        Student System | Education Management Platform<br>
                        <a href="https://yourdomain.com" style="color: #1450B3; text-decoration: none;">Visit Platform</a> | 
                        <a href="https://yourdomain.com/help" style="color: #1450B3; text-decoration: none;">Get Help</a>
                    </p>
                </div>
            </body>
        </html>
        """
        
        text = f"""
Verify Your Login

Hi {user_name},

We received a login attempt to your Student System account. To proceed, please use this verification code:

{verification_code}

This code expires in 10 minutes.

If you didn't attempt to log in, ignore this email.
        """
        
        return {
            "html": html,
            "text": text,
        }

    @staticmethod
    def password_reset_email(reset_url: str, user_name: str) -> dict[str, str]:
        """Generate password reset email with HTML template."""
        
        html = f"""
        <html>
            <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                <div style="max-width: 600px; margin: 0 auto; background-color: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    <h2 style="color: #1450B3; margin-top: 0;">Reset Your Password</h2>
                    
                    <p>Hi {user_name},</p>
                    
                    <p>We received a request to reset your password. Click the button below to create a new password:</p>
                    
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{reset_url}" style="background-color: #1450B3; color: white; padding: 12px 30px; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">
                            Reset Password
                        </a>
                    </div>
                    
                    <p style="color: #666; font-size: 12px;">Or copy this link: <code style="background-color: #f0f0f0; padding: 2px 6px; border-radius: 3px;">{reset_url}</code></p>
                    
                    <p style="color: #666; font-size: 12px;">This link expires in 1 hour.</p>
                    
                    <p style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; border-radius: 4px; color: #856404;">
                        <strong>Security:</strong> If you didn't request this, please ignore this email. Your password will not change.
                    </p>
                    
                    <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
                    
                    <p style="color: #999; font-size: 12px; margin: 0;">
                        Student System | Education Management Platform<br>
                        <a href="https://yourdomain.com" style="color: #1450B3; text-decoration: none;">Visit Platform</a> | 
                        <a href="https://yourdomain.com/help" style="color: #1450B3; text-decoration: none;">Get Help</a>
                    </p>
                </div>
            </body>
        </html>
        """
        
        text = f"""
Reset Your Password

Hi {user_name},

We received a request to reset your password. Click the link below or copy it into your browser:

{reset_url}

This link expires in 1 hour.

If you didn't request this, please ignore this email. Your password will not change.
        """
        
        return {
            "html": html,
            "text": text,
        }

    @staticmethod
    def welcome_email(user_name: str, setup_url: str) -> dict[str, str]:
        """Generate welcome email with HTML template."""
        
        html = f"""
        <html>
            <body style="font-family: Arial, sans-serif; background-color: #f5f5f5; padding: 20px;">
                <div style="max-width: 600px; margin: 0 auto; background-color: white; border-radius: 8px; padding: 30px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    <h2 style="color: #1450B3; margin-top: 0;">Welcome to Student System!</h2>
                    
                    <p>Hi {user_name},</p>
                    
                    <p>Your account has been created. Let's get you started:</p>
                    
                    <div style="background-color: #e3f2fd; padding: 20px; border-radius: 4px; margin: 20px 0;">
                        <h3 style="color: #1450B3; margin-top: 0;">📋 Getting Started</h3>
                        <ul style="color: #333;">
                            <li>Complete your profile information</li>
                            <li>Set up two-factor authentication (recommended)</li>
                            <li>Explore the student management dashboard</li>
                            <li>Upload student results and grades</li>
                        </ul>
                    </div>
                    
                    <div style="text-align: center; margin: 30px 0;">
                        <a href="{setup_url}" style="background-color: #1450B3; color: white; padding: 12px 30px; text-decoration: none; border-radius: 4px; font-weight: bold; display: inline-block;">
                            Complete Setup
                        </a>
                    </div>
                    
                    <div style="background-color: #f0f7ff; padding: 15px; border-left: 4px solid #1450B3; border-radius: 4px; margin: 20px 0;">
                        <p style="margin: 0; color: #0c3c73;"><strong>💡 Tip:</strong> Enable two-factor authentication in your account settings for enhanced security.</p>
                    </div>
                    
                    <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
                    
                    <p style="color: #999; font-size: 12px; margin: 0;">
                        Student System | Education Management Platform<br>
                        Questions? <a href="https://yourdomain.com/help" style="color: #1450B3; text-decoration: none;">View Help Center</a> | 
                        <a href="https://yourdomain.com/contact" style="color: #1450B3; text-decoration: none;">Contact Support</a>
                    </p>
                </div>
            </body>
        </html>
        """
        
        text = f"""
Welcome to Student System!

Hi {user_name},

Your account has been created. Let's get started:

1. Complete your profile information
2. Set up two-factor authentication (recommended)
3. Explore the student management dashboard
4. Upload student results and grades

Click here to complete setup: {setup_url}

For security, we recommend enabling two-factor authentication in your account settings.

---
Student System | Education Management Platform
        """
        
        return {
            "html": html,
            "text": text,
        }


# Instantiate the provider (will be used by outbox service)
resend_provider = ResendEmailProvider()
