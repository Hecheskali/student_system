import uuid
from types import SimpleNamespace

import httpx
import pytest
from fastapi import HTTPException

from app.core.config import Settings
from app.schemas.teachers import TeacherAccountCreate
from app.services.supabase_admin import (
    SupabaseAdminService,
    SupabasePrincipal,
    _auth_lookup_error_response,
    _supabase_error_detail,
)


TEACHER_ID = "46e81f1b-340f-45eb-b5f0-fb88c3814aa2"
TEACHER_USER_ID = "11111111-1111-4111-8111-111111111111"
OTHER_USER_ID = "22222222-2222-4222-8222-222222222222"


class FakeAuthAdmin:
    def __init__(self, users=None):
        self.users = list(users or [])
        self.created_payloads = []
        self.updated_payloads = []

    def list_users(self, page=1, per_page=1000):
        return SimpleNamespace(users=self.users)

    def create_user(self, payload):
        self.created_payloads.append(payload)
        user = SimpleNamespace(id=TEACHER_USER_ID, email=payload["email"])
        self.users.append(user)
        return SimpleNamespace(user=user)

    def update_user_by_id(self, user_id, payload):
        self.updated_payloads.append((user_id, payload))
        return SimpleNamespace(user=SimpleNamespace(id=user_id))


class FakeClient:
    def __init__(self, auth_users=None):
        self.auth = SimpleNamespace(admin=FakeAuthAdmin(auth_users))


class StubSupabaseAdminService(SupabaseAdminService):
    def __init__(self, *, teachers, users=None, auth_users=None):
        self.tables = {
            "teachers": [dict(row) for row in teachers],
            "users": [dict(row) for row in (users or [])],
        }
        self.reference_classes = []
        self._client = FakeClient(auth_users)

    @property
    def client(self):
        return self._client

    def _ensure_reference_data(self, *, school_name, district_name, class_names):
        self.reference_classes = list(class_names)

    def _fetch_single(self, table, *, filters, select="*"):
        for row in self.tables.get(table, []):
            if all(row.get(column) == value for column, value in filters.items()):
                return dict(row)
        return None

    def _insert(self, table, payload):
        row = dict(payload)
        row.setdefault("id", str(uuid.uuid4()))
        self.tables.setdefault(table, []).append(row)
        return dict(row)

    def _upsert(self, table, payload, *, on_conflict):
        rows = self.tables.setdefault(table, [])
        for index, row in enumerate(rows):
            if row.get(on_conflict) == payload.get(on_conflict):
                rows[index] = {**row, **payload}
                return dict(rows[index])
        rows.append(dict(payload))
        return dict(payload)

    def _update(self, table, payload, *, filters):
        rows = self.tables.setdefault(table, [])
        for index, row in enumerate(rows):
            if all(row.get(column) == value for column, value in filters.items()):
                rows[index] = {**row, **payload}
                return dict(rows[index])
        raise RuntimeError(f"Supabase update on {table} returned no row.")


def _principal():
    return SupabasePrincipal(
        id="31a2448e-815c-432e-bc7f-1df6f7ef0c58",
        email="head@example.com",
        name="Headmaster",
        role="head_of_school",
        school_name="Summit View College",
        district_name="Jabu District",
    )


def _payload(email="legacy.teacher@example.com"):
    return TeacherAccountCreate(
        name="Legacy Teacher",
        email=email,
        password="home099",
        subject="Basic Mathematics",
        assigned_class="Form 1 A",
        subjects=["Physics"],
        assigned_classes=["Form 1 B"],
        school_name="Summit View College",
        district_name="Jabu District",
    )


def test_auth_lookup_error_response_distinguishes_backend_api_key_errors():
    status_code, detail = _auth_lookup_error_response(Exception("Invalid API key"))

    assert status_code == 503
    assert "backend credentials" in detail


def test_auth_lookup_error_response_distinguishes_expired_sessions():
    status_code, detail = _auth_lookup_error_response(Exception("JWT expired"))

    assert status_code == 401
    assert "session expired" in detail


def test_auth_lookup_error_response_distinguishes_missing_backend_config():
    status_code, detail = _auth_lookup_error_response(
        Exception("Supabase admin client is not configured"),
    )

    assert status_code == 503
    assert "backend credentials" in detail


def test_supabase_error_detail_reads_auth_error_payload():
    response = httpx.Response(
        401,
        json={"msg": "invalid JWT"},
        request=httpx.Request("GET", "https://example.test/auth/v1/user"),
    )

    assert _supabase_error_detail(response) == "invalid JWT"


def test_access_token_lookup_uses_supabase_auth_user_endpoint(monkeypatch):
    captured = {}

    def fake_get(url, *, headers, timeout):
        captured["url"] = url
        captured["headers"] = headers
        captured["timeout"] = timeout
        return httpx.Response(
            200,
            json={"id": TEACHER_USER_ID, "email": "head@example.com"},
            request=httpx.Request("GET", url),
        )

    monkeypatch.setattr(httpx, "get", fake_get)
    service = SupabaseAdminService(
        Settings(
            SUPABASE_URL="https://project.supabase.co",
            SUPABASE_SERVICE_ROLE_KEY="service-key",
        ),
    )

    user = service._get_auth_user_from_access_token("user-token")

    assert user["id"] == TEACHER_USER_ID
    assert captured["url"] == "https://project.supabase.co/auth/v1/user"
    assert captured["headers"]["apikey"] == "service-key"
    assert captured["headers"]["Authorization"] == "Bearer user-token"
    assert captured["timeout"] == 10


def test_principal_accepts_headmaster_app_metadata_alias(monkeypatch):
    service = StubSupabaseAdminService(
        teachers=[],
        users=[
            {
                "id": OTHER_USER_ID,
                "email": "head@example.com",
                "name": "Headmaster",
                "role": "head_of_school",
                "school_name": "Summit View College",
                "district_name": "Jabu District",
            },
        ],
    )
    monkeypatch.setattr(
        service,
        "_get_auth_user_from_access_token",
        lambda _: {
            "id": OTHER_USER_ID,
            "email": "head@example.com",
            "app_metadata": {"role": "headmaster"},
        },
    )

    principal = service.get_principal_from_access_token("headmaster-token")

    assert principal.id == OTHER_USER_ID
    assert principal.role == "head_of_school"


def test_principal_rejects_auth_profile_role_mismatch(monkeypatch):
    service = StubSupabaseAdminService(
        teachers=[],
        users=[
            {
                "id": OTHER_USER_ID,
                "email": "head@example.com",
                "name": "Headmaster",
                "role": "head_of_school",
                "school_name": "Summit View College",
                "district_name": "Jabu District",
            },
        ],
    )
    monkeypatch.setattr(
        service,
        "_get_auth_user_from_access_token",
        lambda _: {
            "id": OTHER_USER_ID,
            "email": "head@example.com",
            "app_metadata": {"role": "teacher"},
        },
    )

    with pytest.raises(HTTPException) as exc_info:
        service.get_principal_from_access_token("teacher-token")

    assert exc_info.value.status_code == 403


def test_create_teacher_account_links_legacy_teacher_row():
    service = StubSupabaseAdminService(
        teachers=[
            {
                "id": TEACHER_ID,
                "user_id": None,
                "email": "legacy.teacher@example.com",
                "name": "Legacy Teacher",
                "subject": "Biology",
                "assigned_class": "Form 4 A",
                "school_name": "Summit View College",
                "district_name": "Jabu District",
                "profile": {},
            },
        ],
    )

    teacher = service.create_teacher_account(_payload(), _principal())

    assert str(teacher.id) == TEACHER_ID
    assert str(teacher.user_id) == TEACHER_USER_ID
    assert service.tables["teachers"][0]["user_id"] == TEACHER_USER_ID
    assert service.tables["teachers"][0]["subject"] == "Basic Mathematics"
    assert service.tables["users"][0]["role"] == "teacher"
    assert service.tables["users"][0]["profile"]["teacher_id"] == TEACHER_ID
    assert service.client.auth.admin.created_payloads
    assert service.client.auth.admin.updated_payloads[0][0] == TEACHER_USER_ID


def test_create_teacher_account_repairs_already_linked_teacher_row():
    auth_user = SimpleNamespace(
        id=TEACHER_USER_ID,
        email="legacy.teacher@example.com",
    )
    service = StubSupabaseAdminService(
        auth_users=[auth_user],
        users=[
            {
                "id": TEACHER_USER_ID,
                "email": "legacy.teacher@example.com",
                "role": "head_of_school",
                "school_name": "Summit View College",
                "district_name": "Jabu District",
                "profile": {},
            },
        ],
        teachers=[
            {
                "id": TEACHER_ID,
                "user_id": TEACHER_USER_ID,
                "email": "legacy.teacher@example.com",
                "name": "Legacy Teacher",
                "school_name": "Summit View College",
                "district_name": "Jabu District",
                "profile": {},
            },
        ],
    )

    teacher = service.create_teacher_account(_payload(), _principal())

    assert str(teacher.id) == TEACHER_ID
    assert str(teacher.user_id) == TEACHER_USER_ID
    assert service.tables["teachers"][0]["user_id"] == TEACHER_USER_ID
    assert service.tables["teachers"][0]["subject"] == "Basic Mathematics"
    assert service.tables["users"][0]["role"] == "teacher"
    assert service.tables["users"][0]["profile"]["teacher_id"] == TEACHER_ID
    assert not service.client.auth.admin.created_payloads
    assert service.client.auth.admin.updated_payloads[0][0] == TEACHER_USER_ID


def test_create_teacher_account_does_not_hijack_non_teacher_auth_profile():
    auth_user = SimpleNamespace(
        id=OTHER_USER_ID,
        email="legacy.teacher@example.com",
    )
    service = StubSupabaseAdminService(
        auth_users=[auth_user],
        users=[
            {
                "id": OTHER_USER_ID,
                "email": "legacy.teacher@example.com",
                "role": "head_of_school",
                "school_name": "Summit View College",
                "district_name": "Jabu District",
                "profile": {},
            },
        ],
        teachers=[
            {
                "id": TEACHER_ID,
                "user_id": None,
                "email": "legacy.teacher@example.com",
                "name": "Legacy Teacher",
                "school_name": "Summit View College",
                "district_name": "Jabu District",
                "profile": {},
            },
        ],
    )

    with pytest.raises(HTTPException) as exc_info:
        service.create_teacher_account(_payload(), _principal())

    assert exc_info.value.status_code == 409
    assert not service.client.auth.admin.updated_payloads
