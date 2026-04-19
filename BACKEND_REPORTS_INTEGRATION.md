# Backend Report Generation Integration

This document explains how to connect the professional exam ledger report generator to the backend.

## Overview

The system now supports **two methods** for generating reports:

1. **Frontend Generation** (Default) - Reports are generated locally in the Dart/Flutter app
2. **Backend Generation** - Reports are generated server-side by the FastAPI backend

## Architecture

### Backend Components

**New Files Created:**

- `backend/app/schemas/reports.py` - Pydantic schemas for report data
- `backend/app/services/report_generator.py` - Report generation service (PDF, Excel, CSV)
- `backend/app/api/routes/reports.py` - API endpoints for report generation

**Updated Files:**

- `backend/pyproject.toml` - Added `reportlab` and `openpyxl` dependencies
- `backend/app/main.py` - Registered reports router

### Frontend Components

**New Files Created:**

- `lib/features/student_management/data/services/backend_report_service.dart` - Dart service for backend API calls
- `lib/features/student_management/presentation/config/report_config.dart` - Configuration file
- `lib/features/student_management/presentation/utils/report_exporter.dart` - Enhanced with professional styling

## Installation

### Backend

1. Install dependencies:

```bash
cd backend
pip install reportlab openpyxl
# Or if using pip-tools:
pip-sync requirements.txt
```

1. Verify the imports work:

```bash
python -c "import reportlab; import openpyxl; print('OK')"
```

### Frontend

No additional dependencies required for frontend integration (already uses `dio` for HTTP).

## API Endpoints

### 1. Generate Report Endpoint

**POST** `/api/v1/reports/generate`

Generate a report in any supported format.

**Request Body:**

```json
{
  "report_data": {
    "title": "Exam Ledger Report",
    "subtitle": "Subject-by-subject exam sheet",
    "school_name": "Example School",
    "report_type": "All exams ledger",
    "exam_window_label": "Term 1, 2025",
    "generated_at": "2025-04-19T10:00:00Z",
    "summary": [
      {
        "label": "School",
        "value": "Example School"
      }
    ],
    "sections": [
      {
        "title": "Exam Ledger",
        "headers": ["Student", "Subject", "Score"],
        "rows": [
          ["John Doe", "Mathematics", "85.5"],
          ["Jane Smith", "English", "92.0"]
        ],
        "note": "Audit data"
      }
    ],
    "footnote": "Generated from live system",
    "pdf_landscape": true
  },
  "format": "pdf",
  "filename": "exam_ledger_report"
}
```

**Response:**

- Returns the generated file as binary attachment
- Content-Type: `application/pdf`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, or `text/csv`
- Content-Disposition: `attachment; filename="exam_ledger_report.pdf"`

### 2. Generate Exam Ledger Endpoint

**POST** `/api/v1/reports/exam-ledger`

Generate an exam ledger report from exam data.

**Request Body:**

```json
{
  "class_name": "Form 4A",
  "school_name": "Example School",
  "district_name": "Central District",
  "exam_type": "Annual",
  "exam_window_label": "June 2025",
  "headers": ["Student", "Subject", "Average", "Grade"],
  "rows": [
    ["John Doe", "Mathematics", "85.5", "A"],
    ["Jane Smith", "Mathematics", "92.0", "A+"]
  ],
  "format": "pdf"
}
```

**Response:**

- Returns: Exam ledger PDF/Excel/CSV file as attachment

## Configuration

Edit `lib/features/student_management/presentation/config/report_config.dart`:

```dart
abstract class ReportConfig {
  // Set to true to use backend for report generation
  static const bool useBackendForReports = true;
  
  // Backend API URL
  static const String backendReportApiUrl = 'http://api.yourdomain.com/api/v1';
  
  // Timeout in seconds
  static const int reportRequestTimeout = 60;
}
```

## Usage

### Enable Backend Reports

Update the configuration in `report_config.dart`:

```dart
static const bool useBackendForReports = true;
```

### Generate Report from Frontend

```dart
final BackendReportService reportService = BackendReportService(
  dio: dioClient,
  baseUrl: ReportConfig.backendReportApiUrl,
);

// Generate a report
final Uint8List? bytes = await reportService.generateReport(
  reportData: reportData,
  format: ReportFileFormat.pdf,
  suggestedBaseName: 'exam_ledger_report',
);

// Generated report is returned as bytes for download/saving
```

## Features

### PDF Generation

- ✅ Professional color scheme (blue/white/gray)
- ✅ Custom header with school name and report ID
- ✅ Metadata section (report type, exam period)
- ✅ Summary boxes with key information
- ✅ Professional table styling
- ✅ Page numbers and footer
- ✅ Landscape/portrait orientation support
- ✅ Alternating row colors

### Excel Generation

- ✅ Professional formatting
- ✅ Header colors and fonts
- ✅ Metadata section
- ✅ Multiple sections support
- ✅ Auto-adjusted column widths
- ✅ Border styling

### CSV Generation

- ✅ Structured data export
- ✅ All metadata included
- ✅ Easy import to other systems

## Performance

### Backend Advantages

- Offload heavy PDF generation from client devices
- Support for large datasets without client memory issues
- Consistent formatting across all clients
- Can be scaled independently

### Frontend Advantages

- No network latency
- Works offline
- Faster for small reports
- More responsive UI

## Development

### Running the Backend

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at: `http://localhost:8000/docs`

### Testing Report Generation

```bash
# Test PDF generation
curl -X POST http://localhost:8000/api/v1/reports/generate \
  -H "Content-Type: application/json" \
  -d @test_report.json

# Test exam ledger generation
curl -X POST http://localhost:8000/api/v1/reports/exam-ledger \
  -H "Content-Type: application/json" \
  -d @test_exam_ledger.json
```

## Troubleshooting

### reportlab not found

```bash
pip install reportlab>=4.0.0
```

### openpyxl not found

```bash
pip install openpyxl>=3.11.0
```

### Backend connection timeout

- Check backend is running: `http://localhost:8000/docs`
- Increase timeout: Edit `report_config.dart`
- Check CORS settings in `backend/app/main.py`

### PDF generation fails

- Check reportlab installation
- Verify file permissions in temp directory
- Check backend logs for detailed error

## Next Steps

1. **Enable Backend Reports**: Set `useBackendForReports = true` in config
2. **Update Report Service**: Integrate backend service with your report UI
3. **Test**: Generate reports and verify output
4. **Deploy**: Configure backend URL for production environment

## API Security

Both endpoints require authentication (JWT token) and role-based access:

- `HEAD_OF_SCHOOL` ✅
- `ACADEMIC_MASTER` ✅
- `TEACHER` ✅

Other roles are denied access to report generation endpoints.
