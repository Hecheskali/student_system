import uuid
from dataclasses import dataclass
from typing import Any

import httpx
from fastapi import HTTPException, status

from app.core.config import Settings, get_settings
from app.schemas.teachers import (
    TeacherAccountCreate,
    TeacherAccountRead,
    TeacherAccountUpdate,
)

from app.services.audit import write_audit_log
from app.services.governance import anonymize_user, export_user_governance_snapshot
from app.schemas.hydration import (
    DistrictHydrationRequest,
    SchoolHydrationRequest,
    ClassHydrationRequest,
    HydrationResponse,
)



@dataclass(frozen=True)
class SupabasePrincipal:
    id: str
    email: str
    name: str
    role: str
    school_name: str
    district_name: str


class SupabaseAdminService:
    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()
        self._client: Any | None = None

    @property
    def client(self) -> Any:
        if self._client is None:
            if (
                not self._settings.supabase_url
                or self._settings.supabase_service_role_key is None
            ):
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=(
                        "Supabase admin client is not configured. Set "
                        "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY."
                    ),
                )

            try:
                from supabase import create_client
            except ImportError as exc:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Supabase Python SDK is not installed on the backend.",
                ) from exc
            try:
                from supabase.lib.client_options import ClientOptions
            except ImportError:
                from supabase.client import ClientOptions

            self._client = create_client(
                self._settings.supabase_url,
                self._settings.supabase_service_role_key.get_secret_value(),
                options=ClientOptions(
                    auto_refresh_token=False,
                    persist_session=False,
                ),
            )
        return self._client

    def get_principal_from_access_token(self, access_token: str) -> SupabasePrincipal:
        if not access_token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing Supabase access token.",
            )

        try:
            auth_user = self._get_auth_user_from_access_token(access_token)
        except Exception as exc:
            status_code, detail = _auth_lookup_error_response(exc)
            raise HTTPException(
                status_code=status_code,
                detail=detail,
            ) from exc

        user_id = str(_get_attr(auth_user, "id", ""))
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Supabase access token did not resolve to a user.",
            )

        profile = self._fetch_single(
            "users",
            select="id,name,email,role,school_name,district_name",
            filters={"id": user_id},
        )
        if profile is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Signed-in user does not have an application profile.",
            )

        auth_role = _normalize_role(_auth_user_role(auth_user))
        profile_role = _normalize_role(profile.get("role"))
        if auth_role and profile_role and auth_role != profile_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Supabase auth role does not match the application profile.",
            )
        role = profile_role or auth_role
        if not role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Signed-in user does not have an application role.",
            )

        return SupabasePrincipal(
            id=user_id,
            email=str(profile.get("email") or _get_attr(auth_user, "email", "")),
            name=str(profile.get("name") or ""),
            role=role,
            school_name=str(profile.get("school_name") or ""),
            district_name=str(profile.get("district_name") or ""),
        )

    def create_teacher_account(
        self,
        payload: TeacherAccountCreate,
        principal: SupabasePrincipal,
    ) -> TeacherAccountRead:
        _ensure_headmaster(principal)
        school_name, district_name = _resolve_school_scope(
            principal=principal,
            requested_school=payload.school_name,
            requested_district=payload.district_name,
        )

        email = str(payload.email).strip().lower()
        subjects = _effective_values(payload.subject, payload.subjects, max_items=2)
        assigned_classes = _effective_values(
            payload.assigned_class,
            payload.assigned_classes,
        )
        created_auth_user_id: str | None = None

        try:
            self._ensure_reference_data(
                school_name=school_name,
                district_name=district_name,
                class_names=assigned_classes,
            )

            existing_teacher = self._fetch_single(
                "teachers",
                filters={"email": email, "school_name": school_name},
            )
            existing_teacher_id = (
                str(existing_teacher.get("id") or "") if existing_teacher else ""
            )
            existing_teacher_user_id = (
                str(existing_teacher.get("user_id") or "") if existing_teacher else ""
            )
            existing_email_profile = self._fetch_single(
                "users",
                filters={"email": email},
                select="id,email,role,school_name,district_name,profile",
            )

            metadata = _teacher_metadata(
                name=payload.name,
                email=email,
                school_name=school_name,
                district_name=district_name,
                subject=subjects[0],
                assigned_class=assigned_classes[0],
                subjects=subjects,
                assigned_classes=assigned_classes,
            )
            auth_user_was_created = False

            if existing_teacher_user_id:
                user_id = existing_teacher_user_id
            elif existing_email_profile is not None:
                if not _is_compatible_teacher_profile(
                    existing_email_profile,
                    email=email,
                    school_name=school_name,
                ):
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="This email belongs to another application user.",
                    )
                user_id = str(existing_email_profile.get("id") or "")
            else:
                try:
                    auth_response = self.client.auth.admin.create_user(
                        {
                            "email": email,
                            "password": payload.password,
                            "email_confirm": True,
                            "user_metadata": metadata,
                            "app_metadata": {"role": "teacher"},
                        },
                    )
                    auth_user = _response_user(auth_response)
                    auth_user_was_created = True
                    user_id = str(_get_attr(auth_user, "id", ""))
                except Exception as exc:
                    error_msg = str(exc).lower()
                    if "already exists" in error_msg or "user exists" in error_msg:
                        # User already exists in auth system, try to get their ID
                        try:
                            # First try to fetch from database users table
                            existing_auth_user = self._fetch_single(
                                "users",
                                filters={"email": email},
                                select="id",
                            )
                            if existing_auth_user:
                                user_id = str(existing_auth_user.get("id") or "")
                        except Exception:
                            user_id = ""
                        
                        # If not found in database, search Supabase auth directly
                        if not user_id:
                            try:
                                # List users and find by email - this is the user's existing auth account
                                response = self.client.auth.admin.list_users(per_page=1000)
                                users = _response_users(response)
                                for user in users:
                                    user_email = str(_get_attr(user, "email", "") or "").strip().lower()
                                    if user_email == email.strip().lower():
                                        user_id = str(_get_attr(user, "id", ""))
                                        break
                            except Exception:
                                pass
                        
                        if not user_id:
                            raise HTTPException(
                                status_code=status.HTTP_409_CONFLICT,
                                detail="This email is already registered.",
                            ) from exc
                    else:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"Could not create Supabase auth user: {exc}",
                        ) from exc
            if not user_id:
                raise RuntimeError("Supabase did not return the created user id.")
            if auth_user_was_created:
                created_auth_user_id = user_id

            existing_profile = self._fetch_single(
                "users",
                filters={"id": user_id},
                select="id,email,role,school_name,district_name,profile",
            )
            if existing_profile is not None and not _is_compatible_teacher_profile(
                existing_profile,
                email=email,
                school_name=school_name,
            ):
                if not _is_repairable_linked_teacher_profile(
                    existing_profile,
                    email=email,
                    school_name=school_name,
                    teacher_id=existing_teacher_id,
                    linked_user_id=existing_teacher_user_id,
                ):
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="This email belongs to another application user.",
                    )

            try:
                self.client.auth.admin.update_user_by_id(
                    user_id,
                    {
                        "email": email,
                        "password": payload.password,
                        "email_confirm": True,
                        "user_metadata": metadata,
                        "app_metadata": {"role": "teacher"},
                    },
                )
            except Exception:
                if existing_profile is not None:
                    raise

            self._upsert(
                "users",
                {
                    "id": user_id,
                    "name": payload.name,
                    "email": email,
                    "role": "teacher",
                    "school_name": school_name,
                    "district_name": district_name,
                    "subject": subjects[0],
                    "assigned_class": assigned_classes[0],
                    "subjects": subjects,
                    "assigned_classes": assigned_classes,
                    "profile": _merged_profile(existing_profile, {}),
                },
                on_conflict="id",
            )
            teacher_payload = {
                "user_id": user_id,
                "name": payload.name,
                "email": email,
                "subject": subjects[0],
                "assigned_class": assigned_classes[0],
                "can_upload_results": payload.can_upload_results,
                "can_edit_results": payload.can_edit_results,
                "can_register_students": payload.can_register_students,
                "can_download_results": payload.can_download_results,
                "subjects": subjects[1:],
                "assigned_classes": assigned_classes[1:],
                "school_name": school_name,
                "district_name": district_name,
                "profile": _merged_profile(
                    existing_teacher,
                    {"is_active": payload.is_active},
                ),
            }
            if existing_teacher_id:
                teacher_row = self._update(
                    "teachers",
                    teacher_payload,
                    filters={"id": existing_teacher_id},
                )
            else:
                teacher_row = self._insert("teachers", teacher_payload)
            
            # Fetch the fresh profile after upsert to avoid merging stale data
            current_profile = self._fetch_single(
                "users",
                filters={"id": user_id},
                select="profile",
            )
            self._update(
                "users",
                {
                    "profile": _merged_profile(
                        current_profile,
                        {"teacher_id": teacher_row["id"]},
                    ),
                },
                filters={"id": user_id},
            )
            return _teacher_read_from_row(teacher_row)
        except HTTPException:
            if created_auth_user_id is not None:
                self._delete_auth_user_safely(created_auth_user_id)
            raise
        except Exception as exc:
            if created_auth_user_id is not None:
                self._delete_auth_user_safely(created_auth_user_id)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Could not create teacher account in Supabase: {exc}",
            ) from exc

    def update_teacher_account(
        self,
        teacher_id: uuid.UUID,
        payload: TeacherAccountUpdate,
        principal: SupabasePrincipal,
    ) -> TeacherAccountRead:
        _ensure_headmaster(principal)
        existing = self._fetch_single("teachers", filters={"id": str(teacher_id)})
        if existing is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found.",
            )
        _ensure_same_school(principal, str(existing.get("school_name") or ""))

        current_subjects = _effective_values(
            str(existing.get("subject") or ""),
            _string_list(existing.get("subjects")),
            max_items=2,
        )
        current_classes = _effective_values(
            str(existing.get("assigned_class") or ""),
            _string_list(existing.get("assigned_classes")),
        )
        subjects = current_subjects
        assigned_classes = current_classes
        if payload.subject is not None or payload.subjects is not None:
            subjects = _effective_values(
                payload.subject or current_subjects[0],
                payload.subjects
                if payload.subjects is not None
                else current_subjects[1:],
                max_items=2,
            )
        if (
            payload.assigned_class is not None
            or payload.assigned_classes is not None
        ):
            assigned_classes = _effective_values(
                payload.assigned_class or current_classes[0],
                payload.assigned_classes
                if payload.assigned_classes is not None
                else current_classes[1:],
            )

        name = payload.name or str(existing.get("name") or "")
        email = str(payload.email or existing.get("email") or "").strip().lower()
        profile = dict(existing.get("profile") or {})
        if payload.is_active is not None:
            profile["is_active"] = payload.is_active

        updates = {
            "name": name,
            "email": email,
            "subject": subjects[0],
            "assigned_class": assigned_classes[0],
            "subjects": subjects[1:],
            "assigned_classes": assigned_classes[1:],
            "profile": profile,
        }
        for field_name in (
            "can_upload_results",
            "can_edit_results",
            "can_register_students",
            "can_download_results",
        ):
            value = getattr(payload, field_name)
            if value is not None:
                updates[field_name] = value

        teacher_row = self._update(
            "teachers",
            updates,
            filters={"id": str(teacher_id)},
        )
        user_id = str(teacher_row.get("user_id") or "")
        if user_id:
            current_profile = self._fetch_single(
                "users",
                filters={"id": user_id},
                select="profile",
            )
            metadata = _teacher_metadata(
                name=name,
                email=email,
                school_name=str(teacher_row.get("school_name") or ""),
                district_name=str(teacher_row.get("district_name") or ""),
                subject=subjects[0],
                assigned_class=assigned_classes[0],
                subjects=subjects,
                assigned_classes=assigned_classes,
            )
            self._upsert(
                "users",
                {
                    "id": user_id,
                    "name": name,
                    "email": email,
                    "role": "teacher",
                    "school_name": str(teacher_row.get("school_name") or ""),
                    "district_name": str(teacher_row.get("district_name") or ""),
                    "subject": subjects[0],
                    "assigned_class": assigned_classes[0],
                    "subjects": subjects,
                    "assigned_classes": assigned_classes,
                    "profile": _merged_profile(
                        current_profile,
                        {"teacher_id": str(teacher_id)},
                    ),
                },
                on_conflict="id",
            )
            try:
                self.client.auth.admin.update_user_by_id(
                    user_id,
                    {
                        "email": email,
                        "user_metadata": metadata,
                        "app_metadata": {"role": "teacher"},
                    },
                )
            except Exception:
                pass

        return _teacher_read_from_row(teacher_row)

    def delete_teacher_account(
        self,
        teacher_id: uuid.UUID,
        principal: SupabasePrincipal,
    ) -> None:
        _ensure_headmaster(principal)
        teacher = self._fetch_single("teachers", filters={"id": str(teacher_id)})
        if teacher is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found.",
            )
        _ensure_same_school(principal, str(teacher.get("school_name") or ""))

        user_id = str(teacher.get("user_id") or "")
        self._delete("teachers", filters={"id": str(teacher_id)})
        if user_id:
            try:
                self.client.auth.admin.delete_user(user_id)
            except Exception:
                pass

    def _ensure_reference_data(
        self,
        *,
        school_name: str,
        district_name: str,
        class_names: list[str],
    ) -> None:
        district = self._fetch_single("districts", filters={"name": district_name})
        if district is None:
            district = self._insert(
                "districts",
                {"name": district_name, "region_label": ""},
            )
        school = self._fetch_single(
            "schools",
            filters={"district_id": district["id"], "name": school_name},
        )
        if school is None:
            school = self._insert(
                "schools",
                {
                    "district_id": district["id"],
                    "name": school_name,
                    "principal": "",
                },
            )

        for class_name in class_names:
            existing_class = self._fetch_single(
                "classes",
                filters={"school_id": school["id"], "name": class_name},
            )
            if existing_class is None:
                self._insert(
                    "classes",
                    {
                        "school_id": school["id"],
                        "district_id": district["id"],
                        "name": class_name,
                        "teacher": "",
                    },
                )

    def _fetch_single(
        self,
        table: str,
        *,
        filters: dict[str, Any],
        select: str = "*",
    ) -> dict[str, Any] | None:
        query = self.client.table(table).select(select)
        for column, value in filters.items():
            query = query.eq(column, value)
        response = query.limit(1).execute()
        rows = _response_data(response)
        if not rows:
            return None
        return dict(rows[0])

    def _insert(self, table: str, payload: dict[str, Any]) -> dict[str, Any]:
        response = self.client.table(table).insert(payload).execute()
        rows = _response_data(response)
        if not rows:
            raise RuntimeError(f"Supabase insert into {table} returned no row.")
        return dict(rows[0])

    def _upsert(
        self,
        table: str,
        payload: dict[str, Any],
        *,
        on_conflict: str,
    ) -> dict[str, Any] | None:
        response = (
            self.client.table(table)
            .upsert(payload, on_conflict=on_conflict)
            .execute()
        )
        rows = _response_data(response)
        return dict(rows[0]) if rows else None

    def _update(
        self,
        table: str,
        payload: dict[str, Any],
        *,
        filters: dict[str, Any],
    ) -> dict[str, Any]:
        query = self.client.table(table).update(payload)
        for column, value in filters.items():
            query = query.eq(column, value)
        response = query.execute()
        rows = _response_data(response)
        if not rows:
            raise RuntimeError(f"Supabase update on {table} returned no row.")
        return dict(rows[0])

    def _delete(
        self,
        table: str,
        *,
        filters: dict[str, Any],
    ) -> None:
        query = self.client.table(table).delete()
        for column, value in filters.items():
            query = query.eq(column, value)
        query.execute()

    def _delete_auth_user_safely(self, user_id: str) -> None:
        try:
            self.client.auth.admin.delete_user(user_id)
        except Exception:
            pass

    def _get_auth_user_from_access_token(self, access_token: str) -> dict[str, Any]:
        if (
            not self._settings.supabase_url
            or self._settings.supabase_service_role_key is None
        ):
            raise RuntimeError(
                "Supabase admin client is not configured. Set SUPABASE_URL and "
                "SUPABASE_SERVICE_ROLE_KEY.",
            )

        response = httpx.get(
            f"{self._settings.supabase_url.rstrip('/')}/auth/v1/user",
            headers={
                "apikey": self._settings.supabase_service_role_key.get_secret_value(),
                "Authorization": f"Bearer {access_token}",
            },
            timeout=10,
        )
        if response.status_code in (
            status.HTTP_401_UNAUTHORIZED,
            status.HTTP_403_FORBIDDEN,
        ):
            detail = _supabase_error_detail(response)
            raise RuntimeError(detail or "Invalid Supabase access token.")
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, dict):
            raise RuntimeError("Supabase user lookup returned an invalid response.")
        return data


def _ensure_headmaster(principal: SupabasePrincipal) -> None:
    if principal.role != "head_of_school":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the headmaster can manage teacher accounts.",
        )


def _ensure_same_school(principal: SupabasePrincipal, school_name: str) -> None:
    if principal.school_name and school_name != principal.school_name:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Teacher profile is outside this headmaster's school.",
        )


def _resolve_school_scope(
    *,
    principal: SupabasePrincipal,
    requested_school: str,
    requested_district: str,
) -> tuple[str, str]:
    if principal.school_name and requested_school != principal.school_name:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot create teacher accounts outside your school.",
        )
    if principal.district_name and requested_district != principal.district_name:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot create teacher accounts outside your district.",
        )
    return (
        principal.school_name or requested_school,
        principal.district_name or requested_district,
    )


def _teacher_metadata(
    *,
    name: str,
    email: str,
    school_name: str,
    district_name: str,
    subject: str,
    assigned_class: str,
    subjects: list[str],
    assigned_classes: list[str],
) -> dict[str, Any]:
    return {
        "full_name": name,
        "name": name,
        "email": email,
        "role": "teacher",
        "school_name": school_name,
        "district_name": district_name,
        "subject": subject,
        "assigned_class": assigned_class,
        "subjects": subjects,
        "assigned_classes": assigned_classes,
    }


def _auth_user_role(auth_user: Any) -> str:
    app_metadata = _get_attr(auth_user, "app_metadata", None)
    if isinstance(app_metadata, dict):
        role = app_metadata.get("role")
        if role is not None:
            return str(role)

    return ""


def _normalize_role(value: Any) -> str:
    normalized = str(value or "").strip().lower().replace("-", "_").replace(" ", "_")
    if normalized in {"headmaster", "headofschool", "head_of_school"}:
        return "head_of_school"
    if normalized in {"academicmaster", "academic_master"}:
        return "academic_master"
    return normalized


def _teacher_read_from_row(row: dict[str, Any]) -> TeacherAccountRead:
    profile = row.get("profile") or {}
    return TeacherAccountRead(
        id=uuid.UUID(str(row["id"])),
        user_id=uuid.UUID(str(row["user_id"])),
        name=str(row.get("name") or ""),
        email=str(row.get("email") or ""),
        subject=str(row.get("subject") or ""),
        assigned_class=str(row.get("assigned_class") or ""),
        subjects=_string_list(row.get("subjects")),
        assigned_classes=_string_list(row.get("assigned_classes")),
        can_upload_results=bool(row.get("can_upload_results", True)),
        can_edit_results=bool(row.get("can_edit_results", True)),
        can_register_students=bool(row.get("can_register_students", True)),
        can_download_results=bool(row.get("can_download_results", True)),
        is_active=bool(profile.get("is_active", True)),
        school_name=str(row.get("school_name") or ""),
        district_name=str(row.get("district_name") or ""),
    )


def _merged_profile(
    row: dict[str, Any] | None,
    updates: dict[str, Any],
) -> dict[str, Any]:
    raw_profile = row.get("profile") if row else None
    profile = dict(raw_profile) if isinstance(raw_profile, dict) else {}
    profile.update(updates)
    return profile


def _is_compatible_teacher_profile(
    profile: dict[str, Any],
    *,
    email: str,
    school_name: str,
) -> bool:
    role = str(profile.get("role") or "").strip()
    if role and role != "teacher":
        return False

    profile_email = str(profile.get("email") or "").strip().lower()
    if profile_email and profile_email != email:
        return False

    profile_school = str(profile.get("school_name") or "").strip()
    if profile_school and profile_school != school_name:
        return False

    return True


def _is_repairable_linked_teacher_profile(
    profile: dict[str, Any],
    *,
    email: str,
    school_name: str,
    teacher_id: str,
    linked_user_id: str,
) -> bool:
    if not teacher_id or not linked_user_id:
        return False

    profile_id = str(profile.get("id") or "")
    if profile_id and profile_id != linked_user_id:
        return False

    profile_email = str(profile.get("email") or "").strip().lower()
    if profile_email and profile_email != email:
        return False

    profile_school = str(profile.get("school_name") or "").strip()
    if profile_school and profile_school != school_name:
        return False

    return True


def _effective_values(
    primary: str,
    extras: list[str],
    *,
    max_items: int | None = None,
) -> list[str]:
    values = [primary, *extras]
    normalized: list[str] = []
    for value in values:
        trimmed = value.strip()
        if trimmed and trimmed not in normalized:
            normalized.append(trimmed)
        if max_items is not None and len(normalized) >= max_items:
            break
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Teacher assignment must include at least one value.",
        )
    return normalized


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    normalized: list[str] = []
    for item in value:
        if not isinstance(item, str):
            continue
        trimmed = item.strip()
        if trimmed and trimmed not in normalized:
            normalized.append(trimmed)
    return normalized


def _response_user(response: Any) -> Any:
    user = _get_attr(response, "user", None)
    if user is not None:
        return user
    if isinstance(response, dict):
        return response.get("user") or response
    return response


def _response_data(response: Any) -> list[dict[str, Any]]:
    data = _get_attr(response, "data", None)
    if data is None and isinstance(response, dict):
        data = response.get("data")
    if data is None:
        return []
    if isinstance(data, list):
        return [dict(item) for item in data]
    if isinstance(data, dict):
        return [dict(data)]
    return []


def _response_users(response: Any) -> list[Any]:
    if isinstance(response, list):
        return response

    users = _get_attr(response, "users", None)
    if users is None:
        users = _get_attr(response, "data", None)
    if users is None and isinstance(response, dict):
        users = response.get("users") or response.get("data")
    if users is None:
        return []
    if isinstance(users, list):
        return users
    if isinstance(users, dict):
        return []
    try:
        return list(users)
    except TypeError:
        return []


def _auth_lookup_error_response(exc: Exception) -> tuple[int, str]:
    message = str(exc).lower()
    if (
        "api key" in message
        or "apikey" in message
        or "not configured" in message
        or "service_role_key" in message
    ):
        return (
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "Supabase backend credentials are invalid. Check SUPABASE_URL and "
            "SUPABASE_SERVICE_ROLE_KEY.",
        )
    if "expired" in message:
        return (
            status.HTTP_401_UNAUTHORIZED,
            "Supabase session expired. Please log in again.",
        )
    return status.HTTP_401_UNAUTHORIZED, "Invalid Supabase access token."


def _supabase_error_detail(response: httpx.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        return response.text.strip()
    if isinstance(payload, dict):
        for key in ("msg", "message", "error_description", "error"):
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return ""


def _get_attr(source: Any, name: str, default: Any) -> Any:
    if isinstance(source, dict):
        return source.get(name, default)
    return getattr(source, name, default)
