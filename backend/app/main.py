from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.gzip import GZipMiddleware
from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware

from app.api.routes.admin import router as admin_router
from app.api.routes.auth import router as auth_router
from app.api.routes.health import router as health_router
from app.api.routes.reports import router as reports_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.db.session import close_db, init_db
from app.middleware.input_validation import InputSanitizationMiddleware, RequestSignatureMiddleware
from app.middleware.observability import ObservabilityMiddleware
from app.middleware.request_context import RequestContextMiddleware
from app.middleware.security_headers import SecurityHeadersMiddleware
from app.services.bootstrap import bootstrap_admin

settings = get_settings()
configure_logging(settings.log_level)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        logger.info("application startup beginning")
        await init_db()
        logger.info("database initialization step completed")
        await bootstrap_admin()
        logger.info("bootstrap admin step completed")
        yield
    except Exception:
        logger.exception("application startup failed")
        raise
    finally:
        await close_db()
        logger.info("application shutdown complete")


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    debug=settings.debug,
    docs_url="/docs" if settings.enable_docs else None,
    redoc_url="/redoc" if settings.enable_docs else None,
    openapi_url="/openapi.json" if settings.enable_docs else None,
    lifespan=lifespan,
)

app.add_middleware(RequestContextMiddleware)
if settings.observability_enabled:
    app.add_middleware(ObservabilityMiddleware)
app.add_middleware(
    SecurityHeadersMiddleware,
    enable_hsts=settings.enable_hsts,
)
app.add_middleware(InputSanitizationMiddleware)
app.add_middleware(RequestSignatureMiddleware)
app.add_middleware(GZipMiddleware, minimum_size=1024)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    expose_headers=["X-Request-ID"],
)
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.trusted_hosts,
)

if settings.enable_https_redirect:
    app.add_middleware(HTTPSRedirectMiddleware)

app.include_router(health_router)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(admin_router, prefix="/api/v1")
app.include_router(reports_router, prefix="/api/v1")
