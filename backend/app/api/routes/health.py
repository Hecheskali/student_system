from fastapi import APIRouter

from app.core.config import get_settings
from app.core.rate_limit import check_rate_limit_backend_health
from app.db.session import check_db_health

router = APIRouter(tags=["health"])
settings = get_settings()


@router.get("/health/live")
async def live() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/ready")
async def ready() -> dict[str, object]:
    database_ok = await check_db_health()
    redis_ok = await check_rate_limit_backend_health()
    overall_ok = database_ok and redis_ok
    return {
        "status": "ready" if overall_ok else "degraded",
        "checks": {
            "database": "ok" if database_ok else "error",
            "redis": "ok"
            if redis_ok and settings.redis_url
            else "not_configured"
            if not settings.redis_url
            else "error",
        },
    }
