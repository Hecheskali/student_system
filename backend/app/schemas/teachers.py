import uuid

from pydantic import BaseModel, EmailStr, Field, field_validator


class TeacherAccountBase(BaseModel):
    name: str = Field(min_length=3, max_length=255)
    email: EmailStr
    subject: str = Field(min_length=1, max_length=120)
    assigned_class: str = Field(min_length=1, max_length=120)
    subjects: list[str] = Field(default_factory=list, max_length=2)
    assigned_classes: list[str] = Field(default_factory=list)
    can_upload_results: bool = True
    can_edit_results: bool = True
    can_register_students: bool = True
    can_download_results: bool = True
    is_active: bool = True

    @field_validator("name", "subject", "assigned_class")
    @classmethod
    def trim_required_text(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Value cannot be blank.")
        return trimmed

    @field_validator("subjects", "assigned_classes")
    @classmethod
    def normalize_string_list(cls, value: list[str]) -> list[str]:
        normalized: list[str] = []
        for item in value:
            trimmed = item.strip()
            if trimmed and trimmed not in normalized:
                normalized.append(trimmed)
        return normalized


class TeacherAccountCreate(TeacherAccountBase):
    password: str = Field(min_length=6, max_length=128)
    school_name: str = Field(min_length=1, max_length=255)
    district_name: str = Field(min_length=1, max_length=255)

    @field_validator("password")
    @classmethod
    def validate_initial_password(cls, value: str) -> str:
        trimmed = value.strip()
        if len(trimmed) < 6:
            raise ValueError("Initial password must be at least 6 characters.")
        return trimmed

    @field_validator("school_name", "district_name")
    @classmethod
    def trim_school_text(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Value cannot be blank.")
        return trimmed


class TeacherAccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=3, max_length=255)
    email: EmailStr | None = None
    subject: str | None = Field(default=None, min_length=1, max_length=120)
    assigned_class: str | None = Field(default=None, min_length=1, max_length=120)
    subjects: list[str] | None = Field(default=None, max_length=2)
    assigned_classes: list[str] | None = None
    can_upload_results: bool | None = None
    can_edit_results: bool | None = None
    can_register_students: bool | None = None
    can_download_results: bool | None = None
    is_active: bool | None = None

    @field_validator("name", "subject", "assigned_class")
    @classmethod
    def trim_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Value cannot be blank.")
        return trimmed

    @field_validator("subjects", "assigned_classes")
    @classmethod
    def normalize_optional_string_list(
        cls,
        value: list[str] | None,
    ) -> list[str] | None:
        if value is None:
            return None
        normalized: list[str] = []
        for item in value:
            trimmed = item.strip()
            if trimmed and trimmed not in normalized:
                normalized.append(trimmed)
        return normalized


class TeacherAccountRead(TeacherAccountBase):
    id: uuid.UUID
    user_id: uuid.UUID
    school_name: str
    district_name: str
