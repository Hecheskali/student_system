from pathlib import Path
import sys

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool


BACKEND_ROOT = Path(__file__).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def db():
    from app.core import rate_limit
    from app.db.base import Base
    from app.db.session import get_db
    from app.main import app
    from app.models import audit_log, auth_security, user  # noqa: F401

    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        future=True,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    session_factory = async_sessionmaker(
        bind=engine,
        expire_on_commit=False,
        autoflush=False,
    )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with session_factory() as session:
        async def override_get_db():
            yield session

        app.dependency_overrides[get_db] = override_get_db
        rate_limit.limiter = rate_limit.InMemoryRateLimiter()
        try:
            yield session
        finally:
            app.dependency_overrides.pop(get_db, None)
            await session.rollback()

    await engine.dispose()
