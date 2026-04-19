from __future__ import annotations

import asyncio
import json
import logging
import smtplib
from dataclasses import dataclass
from datetime import UTC, datetime
from email.message import EmailMessage
from typing import Any

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.auth_security import OutboundMessage

logger = logging.getLogger(__name__)


@dataclass
class DeliveryResult:
    ok: bool
    error: str | None = None


class EmailDeliveryService:
    def __init__(self) -> None:
        self.settings = get_settings()

    async def send(self, *, recipient: str, subject: str, body: str) -> DeliveryResult:
        provider = self.settings.email_provider.lower()
        if provider == "smtp":
            return await asyncio.to_thread(
                self._send_smtp,
                recipient,
                subject,
                body,
            )
        logger.info(
            "email queued for log delivery",
            extra={"recipient": recipient, "subject": subject},
        )
        return DeliveryResult(ok=True)

    def _send_smtp(self, recipient: str, subject: str, body: str) -> DeliveryResult:
        if not self.settings.smtp_host:
            return DeliveryResult(ok=False, error="SMTP host not configured")
        message = EmailMessage()
        message["From"] = self.settings.email_from_address
        message["To"] = recipient
        message["Subject"] = subject
        message.set_content(body)
        try:
            with smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port) as server:
                if self.settings.smtp_use_tls:
                    server.starttls()
                if self.settings.smtp_username and self.settings.smtp_password:
                    server.login(
                        self.settings.smtp_username,
                        self.settings.smtp_password.get_secret_value(),
                    )
                server.send_message(message)
            return DeliveryResult(ok=True)
        except Exception as exc:
            return DeliveryResult(ok=False, error=str(exc))


class SmsDeliveryService:
    def __init__(self) -> None:
        self.settings = get_settings()

    async def send(self, *, recipient: str, body: str) -> DeliveryResult:
        provider = self.settings.sms_provider.lower()
        if provider == "twilio":
            return await self._send_twilio(recipient=recipient, body=body)
        logger.info(
            "sms queued for log delivery",
            extra={"recipient": recipient},
        )
        return DeliveryResult(ok=True)

    async def _send_twilio(self, *, recipient: str, body: str) -> DeliveryResult:
        if (
            not self.settings.twilio_account_sid
            or not self.settings.twilio_auth_token
            or not self.settings.twilio_from_number
        ):
            return DeliveryResult(ok=False, error="Twilio settings are incomplete")

        url = (
            f"https://api.twilio.com/2010-04-01/Accounts/"
            f"{self.settings.twilio_account_sid}/Messages.json"
        )
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    url,
                    data={
                        "From": self.settings.twilio_from_number,
                        "To": recipient,
                        "Body": body,
                    },
                    auth=(
                        self.settings.twilio_account_sid,
                        self.settings.twilio_auth_token.get_secret_value(),
                    ),
                )
            response.raise_for_status()
            return DeliveryResult(ok=True)
        except Exception as exc:
            return DeliveryResult(ok=False, error=str(exc))


async def enqueue_email(
    db: AsyncSession,
    *,
    recipient: str,
    subject: str,
    template_key: str,
    payload: dict[str, Any],
) -> OutboundMessage:
    message = OutboundMessage(
        channel="email",
        provider=get_settings().email_provider.lower(),
        recipient=recipient,
        subject=subject,
        template_key=template_key,
        payload_json=payload,
        scheduled_for=datetime.now(UTC),
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


async def enqueue_sms(
    db: AsyncSession,
    *,
    recipient: str,
    template_key: str,
    payload: dict[str, Any],
) -> OutboundMessage:
    message = OutboundMessage(
        channel="sms",
        provider=get_settings().sms_provider.lower(),
        recipient=recipient,
        template_key=template_key,
        payload_json=payload,
        scheduled_for=datetime.now(UTC),
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


def render_template(template_key: str, payload: dict[str, Any]) -> tuple[str | None, str]:
    if template_key == "password_reset":
        token = payload["token"]
        subject = "Reset your Student System password"
        body = (
            "A password reset was requested for your account.\n\n"
            f"Reset token: {token}\n"
            "If you did not request this, ignore this message."
        )
        return subject, body
    if template_key == "email_verification":
        token = payload["token"]
        subject = "Verify your Student System email"
        body = (
            "Use the following token to verify your email address.\n\n"
            f"Verification token: {token}"
        )
        return subject, body
    if template_key == "security_alert":
        subject = payload.get("subject", "Student System security alert")
        body = payload.get("body", json.dumps(payload, default=str))
        return subject, body
    subject = payload.get("subject")
    body = payload.get("body", json.dumps(payload, default=str))
    return subject, body


async def process_outbox_batch(db: AsyncSession) -> dict[str, int]:
    settings = get_settings()
    now = datetime.now(UTC)
    messages = (
        await db.scalars(
            select(OutboundMessage)
            .where(
                OutboundMessage.status == "pending",
                OutboundMessage.scheduled_for <= now,
            )
            .order_by(OutboundMessage.created_at.asc())
            .limit(settings.outbox_batch_size)
        )
    ).all()
    email_service = EmailDeliveryService()
    sms_service = SmsDeliveryService()
    sent = 0
    failed = 0
    for message in messages:
        subject, body = render_template(message.template_key, message.payload_json)
        if message.channel == "email":
            result = await email_service.send(
                recipient=message.recipient,
                subject=subject or "Student System notification",
                body=body,
            )
        else:
            result = await sms_service.send(
                recipient=message.recipient,
                body=body,
            )
        message.attempts += 1
        if result.ok:
            message.status = "sent"
            message.sent_at = datetime.now(UTC)
            message.last_error = None
            sent += 1
        else:
            message.status = "failed"
            message.last_error = result.error
            failed += 1
    await db.commit()
    return {"sent": sent, "failed": failed}
