import logging
import os
import subprocess
import sys


logger = logging.getLogger(__name__)


def _should_run_migrations() -> bool:
    return os.getenv("RUN_DB_MIGRATIONS_ON_STARTUP", "true").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    if _should_run_migrations():
        logger.info("running database migrations before starting web server")
        subprocess.run(["alembic", "upgrade", "head"], check=True)
        logger.info("database migrations completed")

    port = os.getenv("PORT", "8000")
    logger.info("starting uvicorn on port %s", port)
    os.execvp(
        "uvicorn",
        [
            "uvicorn",
            "app.main:app",
            "--host",
            "0.0.0.0",
            "--port",
            port,
            "--proxy-headers",
            "--forwarded-allow-ips=*",
        ],
    )


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        logger.exception("database migration command failed with exit code %s", exc.returncode)
        sys.exit(exc.returncode)
    except Exception:
        logger.exception("web service bootstrap failed")
        sys.exit(1)
