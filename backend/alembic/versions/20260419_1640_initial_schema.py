"""initial schema

Revision ID: 20260419_1640
Revises:
Create Date: 2026-04-19 16:40:00
"""

from alembic import op

from app.db.base import Base
from app.models import auth_security, audit_log, user  # noqa: F401

# revision identifiers, used by Alembic.
revision = "20260419_1640"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)


def downgrade() -> None:
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
