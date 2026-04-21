"""Compatibility ASGI entrypoint for platform start commands.

Render may still be configured with ``uvicorn main:app`` from an older service
definition. Re-export the canonical FastAPI application so both
``main:app`` and ``app.main:app`` work.
"""

from app.main import app

