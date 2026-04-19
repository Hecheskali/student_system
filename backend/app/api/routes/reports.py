from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import require_roles
from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.reports import (
    GenerateReportRequest,
    ReportGenerationResponse,
    ReportFormatEnum,
)
from app.services.report_generator import ReportGenerator

router = APIRouter(prefix="/reports", tags=["reports"])


@router.post("/generate")
async def generate_report(
    payload: GenerateReportRequest,
    current_user: User = Depends(
        require_roles(
            UserRole.head_of_school,
            UserRole.academic_master,
            UserRole.teacher,
        )
    ),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """
    Generate a professional report in the specified format.
    
    Supports PDF, Excel, and CSV formats.
    Returns the generated file as a downloadable attachment.
    """
    try:
        # Generate report
        file_bytes, mime_type = ReportGenerator.generate(
            report_data=payload.report_data,
            file_format=payload.format,
        )

        # Determine file extension
        extension_map = {
            ReportFormatEnum.PDF: "pdf",
            ReportFormatEnum.EXCEL: "xlsx",
            ReportFormatEnum.CSV: "csv",
        }
        extension = extension_map.get(payload.format, "bin")
        filename = f"{payload.filename}.{extension}"

        # Return as downloadable file
        return StreamingResponse(
            iter([file_bytes]),
            media_type=mime_type,
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "Content-Length": str(len(file_bytes)),
            },
        )

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Report generation failed: {str(e)}",
        )


@router.post("/exam-ledger")
async def generate_exam_ledger(
    payload: dict,
    current_user: User = Depends(
        require_roles(
            UserRole.head_of_school,
            UserRole.academic_master,
            UserRole.teacher,
        )
    ),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """
    Generate an exam ledger report from exam data.
    
    This endpoint accepts raw exam data and generates a formatted report.
    """
    try:
        from app.schemas.reports import ReportExportDataSchema, ReportExportSectionSchema

        # Extract data from payload
        title = f"{payload.get('school_name', 'School')} Exam Ledger"
        subtitle = f"Exam ledger for {payload.get('class_name', 'Class')}"

        # Build report structure
        report_data = ReportExportDataSchema(
            title=title,
            subtitle=subtitle,
            school_name=payload.get("school_name"),
            report_type=payload.get("exam_type", "All exams"),
            exam_window_label=payload.get("exam_window_label"),
            sections=[
                ReportExportSectionSchema(
                    title="Exam Ledger",
                    note="Subject-by-subject exam sheet with labeled exam records",
                    headers=payload.get("headers", []),
                    rows=payload.get("rows", []),
                )
            ],
            footnote="Generated from the live results center",
        )

        # Generate report
        file_format = ReportFormatEnum(payload.get("format", "pdf").lower())
        file_bytes, mime_type = ReportGenerator.generate(
            report_data=report_data,
            file_format=file_format,
        )

        # Build filename
        extension_map = {
            ReportFormatEnum.PDF: "pdf",
            ReportFormatEnum.EXCEL: "xlsx",
            ReportFormatEnum.CSV: "csv",
        }
        extension = extension_map.get(file_format, "bin")
        filename = f"exam_ledger_report.{extension}"

        # Return as downloadable file
        return StreamingResponse(
            iter([file_bytes]),
            media_type=mime_type,
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "Content-Length": str(len(file_bytes)),
            },
        )

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Exam ledger generation failed: {str(e)}",
        )
