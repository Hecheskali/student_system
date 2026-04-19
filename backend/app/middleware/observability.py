import logging
import time

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

REQUEST_COUNT = Counter(
    "student_system_http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status_code"],
)
REQUEST_LATENCY = Histogram(
    "student_system_http_request_duration_seconds",
    "Request latency in seconds",
    ["method", "path"],
)

logger = logging.getLogger(__name__)


class ObservabilityMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if request.url.path == "/metrics":
            return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

        started_at = time.perf_counter()
        response = await call_next(request)
        duration = time.perf_counter() - started_at

        path = request.url.path
        method = request.method
        status_code = str(response.status_code)

        REQUEST_COUNT.labels(method=method, path=path, status_code=status_code).inc()
        REQUEST_LATENCY.labels(method=method, path=path).observe(duration)

        logger.info(
            "request completed",
            extra={
                "request_id": getattr(request.state, "request_id", None),
                "path": path,
                "method": method,
                "status_code": response.status_code,
                "duration_ms": round(duration * 1000, 2),
            },
        )
        response.headers["X-Response-Time-Ms"] = str(round(duration * 1000, 2))
        return response
