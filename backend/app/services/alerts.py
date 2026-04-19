from __future__ import annotations

import logging

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def send_alert(*, title: str, body: str, severity: str = "warning") -> None:
    settings = get_settings()
    if not settings.alert_webhook_url:
        logger.warning(
            "alert webhook not configured",
            extra={"title": title, "severity": severity},
        )
        return
    payload = {"text": f"[{severity.upper()}] {title}\n{body}"}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                settings.alert_webhook_url.get_secret_value(),
                json=payload,
            )
        response.raise_for_status()
    except Exception:
        logger.exception("failed to send alert webhook")
