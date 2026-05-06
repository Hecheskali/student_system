import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.api.deps import (
    require_roles,
    require_supabase_headmaster,
    supabase_admin_service,
)
from app.core.security import hash_password
from app.db.session import get_db
from app.models.audit_log import AuditLog
from app.models.user import User, UserRole
from app.schemas.auth import AuditLogRead, CreateUserRequest, UserRead
from app.schemas.teachers import (
    TeacherAccountCreate,
    TeacherAccountRead,
    TeacherAccountUpdate,
)
from app.services.audit import write_audit_log
from app.services.governance import anonymize_user, export_user_governance_snapshot
from app.services.supabase_admin import SupabasePrincipal

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
    users = (
        await db.scalars(select(User).order_by(desc(User.created_at)))
    ).all()
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
        detail={"created_user_id": str(user.id), "role": user.role.value},
        request=request,
    )
    return UserRead.model_validate(user)


@router.post(
    "/teachers",
    response_model=TeacherAccountRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_teacher_account(
    payload: TeacherAccountCreate,
    request: Request,
    current_user: SupabasePrincipal = Depends(require_supabase_headmaster),
    db: AsyncSession = Depends(get_db),
) -> TeacherAccountRead:
    teacher = await run_in_threadpool(
        supabase_admin_service.create_teacher_account,
        payload,
        current_user,
    )
    await write_audit_log(
        db,
        event_type="admin.teacher.created",
        status="success",
        target_resource="teacher",
        detail={
            "headmaster_user_id": current_user.id,
            "teacher_id": str(teacher.id),
            "teacher_user_id": str(teacher.user_id),
        },
        request=request,
    )
    return teacher


@router.patch(
    "/teachers/{teacher_id}",
    response_model=TeacherAccountRead,
)
async def update_teacher_account(
    teacher_id: uuid.UUID,
    payload: TeacherAccountUpdate,
    current_user: SupabasePrincipal = Depends(require_supabase_headmaster),
) -> TeacherAccountRead:
    return await run_in_threadpool(
        supabase_admin_service.update_teacher_account,
        teacher_id,
        payload,
        current_user,
    )


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
    logs = (
        await db.scalars(select(AuditLog).order_by(desc(AuditLog.created_at)))
    ).all()
    return [AuditLogRead.model_validate(log) for log in logs]


@router.get("/users/{user_id}/export")
async def export_user_data(
    user_id: uuid.UUID,
    _: User = Depends(require_roles(UserRole.head_of_school)),
    db: AsyncSession = Depends(get_db),
) -> dict[str, object]:
    return await export_user_governance_snapshot(db, user_id=user_id)


@router.delete("/users/{user_id}")
async def delete_user_data(
    user_id: uuid.UUID,
    request: Request,
    current_user: User = Depends(require_roles(UserRole.head_of_school)),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    deleted = await anonymize_user(db, user_id=user_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )
    await write_audit_log(
        db,
        actor_user_id=current_user.id,
        event_type="admin.user.anonymized",
        status="success",
        target_resource="user",
        detail={"user_id": str(user_id)},
        request=request,
    )
    return {"detail": "User anonymized."}
