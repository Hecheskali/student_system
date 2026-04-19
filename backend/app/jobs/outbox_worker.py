import asyncio
import logging

from app.core.config import get_settings
from app.db.session import SessionLocal, close_db, init_db
from app.services.outbox import process_outbox_batch

logger = logging.getLogger(__name__)


async def run_forever() -> None:
    settings = get_settings()
    await init_db()
    try:
        while True:
            async with SessionLocal() as db:
                result = await process_outbox_batch(db)
            logger.info("outbox batch processed", extra=result)
            await asyncio.sleep(settings.worker_poll_interval_seconds)
    finally:
        await close_db()


if __name__ == "__main__":
    asyncio.run(run_forever())
