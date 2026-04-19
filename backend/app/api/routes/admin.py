from fastapi import APIRouter, Depends, Request, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_roles
from app.db.session import get_db
from app.models.audit_log import AuditLog
from app.models.user import User, UserRole
from app.schemas.auth import AuditLogRead, CreateUserRequest, UserRead
from app.core.security import hash_password
from app.services.audit import write_audit_log

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get(
    "/users",
    response_model=list[UserRead],
)
async def list_users(
    _: User = Depends(
        require_roles(UserRole.head_of_school, UserRole.academic_master),
    ),
    db: AsyncSession = Depends(get_db),
) -> list[UserRead]:
    users = (await db.scalars(select(User).order_by(desc(User.created_at)))).all()
    return [UserRead.model_validate(user) for user in users]


@router.post(
    "/users",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_user(
    payload: CreateUserRequest,
    request: Request,
    current_user: User = Depends(require_roles(UserRole.head_of_school)),
    db: AsyncSession = Depends(get_db),
) -> UserRead:
    user = User(
        email=payload.email.lower(),
        full_name=payload.full_name,
        password_hash=hash_password(payload.password),
        role=payload.role,
        must_change_password=payload.must_change_password,
        is_active=True,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="admin.user.created",
        status="success",
        target_resource="user",
        detail={"created_user_id": user.id, "role": user.role.value},
        request=request,
    )
    return UserRead.model_validate(user)


@router.get(
    "/audit-logs",
    response_model=list[AuditLogRead],
)
async def list_audit_logs(
    _: User = Depends(
        require_roles(UserRole.head_of_school, UserRole.academic_master),
    ),
    db: AsyncSession = Depends(get_db),
) -> list[AuditLogRead]:
    logs = (await db.scalars(select(AuditLog).order_by(desc(AuditLog.created_at)))).all()
    return [AuditLogRead.model_validate(log) for log in logs]

