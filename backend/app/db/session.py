from collections.abc import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings
from app.db.base import Base

settings = get_settings()


def _build_connect_args(database_url: str) -> dict[str, int]:
    if database_url.startswith("postgresql+asyncpg://"):
        return {"timeout": 10, "command_timeout": 10}
    return {}


engine = create_async_engine(
    settings.database_url,
    future=True,
    pool_pre_ping=True,
    max_overflow=10,
    pool_size=5,
    pool_timeout=30,
    pool_recycle=3600,
    connect_args=_build_connect_args(settings.database_url),
)
SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        yield session


async def init_db() -> None:
    from app.models import auth_security, audit_log, user  # noqa: F401

    if settings.auto_create_schema:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)


async def close_db() -> None:
    await engine.dispose()


async def check_db_health() -> bool:
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
