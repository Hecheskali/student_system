"""Advanced security middleware for request validation and attack prevention."""

import json
import re
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from fastapi import HTTPException, status
import logging

logger = logging.getLogger(__name__)


class InputSanitizationMiddleware(BaseHTTPMiddleware):
    """Sanitize and validate input to prevent injection attacks."""

    # Patterns for common injection attacks
    SQL_INJECTION_PATTERNS = [
        r"(\b(UNION|SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|SCRIPT)\b)",
        r"(--|;|\/\*|\*\/|xp_|sp_)",  # SQL comments and stored procedures
        r"(\bOR\b.*?=.*?|1\s*=\s*1)",  # OR-based injections
    ]

    XSS_PATTERNS = [
        r"(<script|</script|javascript:|onerror=|onload=|onclick=)",
        r"(eval\(|expression\(|vbscript:)",
    ]

    COMMAND_INJECTION_PATTERNS = [
        r"([;&|`$\(\)])",
    ]

    async def dispatch(self, request: Request, call_next) -> Response:
        """Validate request before processing."""
        
        # Check method
        if request.method not in ["GET", "HEAD", "POST", "PUT", "DELETE", "PATCH"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid HTTP method",
            )

        # Check path for injection
        if self._contains_injection_pattern(request.url.path):
            logger.warning(f"Potential injection in path: {request.url.path}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid request path",
            )

        # Check query parameters
        if request.url.query:
            if self._contains_injection_pattern(request.url.query):
                logger.warning(f"Potential injection in query: {request.url.query}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid query parameters",
                )

        # Check request body if present
        if request.method in ["POST", "PUT", "PATCH"]:
            try:
                body = await request.body()
                if body:
                    content_type = request.headers.get("content-type", "")
                    if "application/json" in content_type:
                        body_str = body.decode()
                        if self._contains_injection_pattern(body_str):
                            logger.warning(f"Potential injection in body")
                            raise HTTPException(
                                status_code=status.HTTP_400_BAD_REQUEST,
                                detail="Invalid request body",
                            )
            except Exception as e:
                logger.error(f"Error validating request body: {e}")

        response = await call_next(request)
        return response

    @staticmethod
    def _contains_injection_pattern(text: str) -> bool:
        """Check if text contains suspicious patterns."""
        text_upper = text.upper()
        
        # SQL injection check
        for pattern in InputSanitizationMiddleware.SQL_INJECTION_PATTERNS:
            if re.search(pattern, text_upper, re.IGNORECASE):
                return True

        # XSS check
        for pattern in InputSanitizationMiddleware.XSS_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                return True

        # Command injection check (lenient - only in suspicious contexts)
        if any(char in text for char in ["$(", "`", "${"]):
            return True

        return False


class RequestSignatureMiddleware(BaseHTTPMiddleware):
    """Validate request signatures for API integrity."""

    async def dispatch(self, request: Request, call_next) -> Response:
        """Check request signature header if present."""
        
        # Skip signature check for health checks and documentation
        if request.url.path in ["/health", "/docs", "/openapi.json", "/redoc"]:
            return await call_next(request)

        # Signature validation would be implemented here
        # This is optional - uncomment when needed
        # if "X-Signature" in request.headers:
        #     signature = request.headers["X-Signature"]
        #     # Verify request was signed correctly

        response = await call_next(request)
        return response
