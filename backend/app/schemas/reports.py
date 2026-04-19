from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class ReportFormatEnum(str, Enum):
    PDF = "pdf"
    EXCEL = "excel"
    CSV = "csv"


class ReportSummaryItemSchema(BaseModel):
    label: str
    value: str


class ReportExportSectionSchema(BaseModel):
    title: str
    headers: list[str]
    rows: list[list[Optional[str | int | float]]]
    note: Optional[str] = None
    pdf_column_flexes: Optional[list[float]] = None


class ReportExportDataSchema(BaseModel):
    title: str
    subtitle: Optional[str] = None
    sections: list[ReportExportSectionSchema]
    summary: list[ReportSummaryItemSchema] = Field(default_factory=list)
    footnote: Optional[str] = None
    school_name: Optional[str] = None
    report_type: Optional[str] = None
    exam_window_label: Optional[str] = None
    generated_at: Optional[datetime] = None
    pdf_landscape: bool = False


class GenerateReportRequest(BaseModel):
    """Request schema for generating a report"""
    report_data: ReportExportDataSchema
    format: ReportFormatEnum = ReportFormatEnum.PDF
    filename: str = Field(default="report", description="Base filename without extension")


class ReportGenerationResponse(BaseModel):
    """Response after generating a report"""
    filename: str
    format: str
    size_bytes: int
    generated_at: datetime


class ExamLedgerRequest(BaseModel):
    """Request for exam ledger report"""
    class_name: str
    school_name: str
    district_name: str
    student_records: list[dict]
    exam_type: Optional[str] = None
    exam_window_label: Optional[str] = None
    format: ReportFormatEnum = ReportFormatEnum.PDF
