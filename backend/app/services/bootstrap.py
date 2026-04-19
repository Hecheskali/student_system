from sqlalchemy import select

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.user import User, UserRole


async def bootstrap_admin() -> None:
    settings = get_settings()
    if not settings.bootstrap_admin_email or not settings.bootstrap_admin_password:
        return

    async with SessionLocal() as db:
        existing = await db.scalar(
            select(User).where(User.email == settings.bootstrap_admin_email.lower()),
        )
        if existing is not None:
            return

        admin = User(
            email=settings.bootstrap_admin_email.lower(),
            full_name=settings.bootstrap_admin_name,
            password_hash=hash_password(settings.bootstrap_admin_password),
            role=UserRole.head_of_school,
            is_active=True,
            must_change_password=True,
        )
        db.add(admin)
        await db.commit()

