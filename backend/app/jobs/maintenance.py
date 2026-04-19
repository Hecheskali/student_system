import asyncio
import json
import logging

from app.db.session import SessionLocal, close_db, init_db
from app.services.governance import purge_expired_security_data

logger = logging.getLogger(__name__)


async def main() -> None:
    await init_db()
    async with SessionLocal() as db:
        result = await purge_expired_security_data(db)
    logger.info("maintenance completed", extra={"result": json.dumps(result)})
    await close_db()


if __name__ == "__main__":
    asyncio.run(main())
