# Quick Start: Backend Report Generation

This guide walks you through setting up and testing the backend report generation system.

## Prerequisites

- Python 3.11+
- pip or poetry
- Git
- curl or Postman (for API testing)

## Step 1: Install Backend Dependencies

```bash
# Navigate to backend directory
cd backend

# Install dependencies
pip install -r requirements.txt
# or if using pyproject.toml:
pip install -e ".[dev]"
```

Verify installation:

```bash
python -c "import reportlab, openpyxl; print('✓ Dependencies installed')"
```

## Step 2: Start the Backend Server

```bash
# From backend directory
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

You should see:

```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete
```

Access the API documentation: <http://localhost:8000/docs>

## Step 3: Test Report Generation

### Option A: Using cURL

Create a test report file `test_report.json`:

```json
{
  "report_data": {
    "title": "Test Exam Ledger Report",
    "subtitle": "Professional report test",
    "school_name": "Example School",
    "report_type": "All exams ledger",
    "exam_window_label": "Term 1, 2025",
    "summary": [
      {"label": "School", "value": "Example School"},
      {"label": "Class", "value": "Form 4A"},
      {"label": "Students", "value": "45"}
    ],
    "sections": [
      {
        "title": "Exam Ledger",
        "note": "Subject-by-subject exam sheet",
        "headers": ["Student", "Subject", "Score", "Grade"],
        "rows": [
          ["John Doe", "Mathematics", "85.5", "A"],
          ["John Doe", "English", "78.0", "B"],
          ["Jane Smith", "Mathematics", "92.0", "A+"],
          ["Jane Smith", "English", "88.5", "A"]
        ]
      }
    ],
    "footnote": "Generated from the live results center"
  },
  "format": "pdf",
  "filename": "exam_ledger_test"
}
```

Generate PDF:

```bash
curl -X POST http://localhost:8000/api/v1/reports/generate \
  -H "Content-Type: application/json" \
  -d @test_report.json \
  --output exam_ledger_test.pdf
```

Generate Excel:

```bash
curl -X POST http://localhost:8000/api/v1/reports/generate \
  -H "Content-Type: application/json" \
  -d '{"report_data": {...}, "format": "excel", "filename": "exam_ledger_test"}' \
  --output exam_ledger_test.xlsx
```

### Option B: Using Postman

1. Open Postman
2. Create a new POST request
3. URL: `http://localhost:8000/api/v1/reports/generate`
4. Headers:
   - `Content-Type: application/json`
   - `Authorization: Bearer <JWT_TOKEN>` (if authentication is enabled)
5. Body (raw JSON): Copy the test_report.json content
6. Send
7. Inspect response (should be PDF binary)

## Step 4: Configure Frontend

### Enable Backend Reports

Edit `lib/features/student_management/presentation/config/report_config.dart`:

```dart
abstract class ReportConfig {
  static const bool useBackendForReports = true;  // ← Change to true
  static const String backendReportApiUrl = 'http://localhost:8000/api/v1';
  static const int reportRequestTimeout = 60;
}
```

### Update Results Screen Integration

In your results_screen.dart export methods, update to use backend:

```dart
import 'package:student_system/features/student_management/data/services/report_export_manager.dart';

// Use ReportExportManager instead of ReportExporter
final ReportExportManager manager = ReportExportManager(dio: dioClient);

final String? path = await manager.exportReport(
  suggestedBaseName: 'exam_ledger_report',
  report: report,
  format: format,
);
```

## Step 5: Test the Full Integration

1. **Start Backend:**

   ```bash
   cd backend
   uvicorn app.main:app --reload
   ```

2. **Start Frontend (Flutter):**

   ```bash
   flutter run
   ```

3. **Generate a Report:**
   - Navigate to Results Center
   - Select a class
   - Click "Export Reports"
   - Choose "Exam Ledger" → "PDF"
   - File should download (now via backend!)

## Troubleshooting

### Backend Reports Not Working

**Check 1: Backend is running**

```bash
curl http://localhost:8000/docs
# Should return Swagger UI
```

**Check 2: Network reachability**

```bash
curl http://localhost:8000/api/v1/reports/generate
# Should return 405 (method not allowed) or error, but not connection refused
```

**Check 3: CORS issues**

- Update backend CORS settings in `app/main.py`
- Add your frontend URL to `allowed_origins`

**Check 4: Authentication**

- If 401 error, ensure JWT token is sent with requests
- Check token expiration

**Check 5: Large files**

- Increase request timeout: `ReportConfig.reportRequestTimeout = 120`
- Check backend log for memory issues

### PDF Generation Fails

**Check 1: ReportLab installation**

```bash
python -c "from reportlab.lib.pagesizes import A4; print('OK')"
```

**Check 2: Permissions**

- Ensure temp directory is writable: `/tmp`, `%TEMP%`, etc.

**Check 3: Memory**

- Large reports need sufficient RAM
- Consider streaming for very large datasets

### Excel/CSV Generation Issues

**Check 1: OpenPyXL installation**

```bash
python -c "from openpyxl import Workbook; print('OK')"
```

**Check 2: File format**

- Verify format parameter is 'pdf', 'excel', or 'csv'
- Check for typos in enum values

## Performance Tips

1. **Use Backend for:**
   - Large datasets (>100 students)
   - Complex reports with many sections
   - PDF generation (memory intensive)

2. **Use Frontend for:**
   - Quick exports
   - Offline functionality
   - Small reports

3. **Optimization:**
   - Cache reports on backend
   - Implement pagination for large datasets
   - Use streaming for very large files

## Monitoring

### Check Backend Health

```bash
curl http://localhost:8000/health
# or
curl http://localhost:8000/api/v1/health
```

### View API Logs

Backend logs are printed to console:

```
INFO:     POST /api/v1/reports/generate HTTP/1.1" 200
INFO:     Report generated: exam_ledger.pdf (245.3 KB)
```

### Monitor Resource Usage

```bash
# Memory usage
ps aux | grep uvicorn

# Monitor in real-time
top -p <PID>
```

## Next Steps

1. ✅ Backend running and tested
2. ⏭️ Deploy backend to production server
3. ⏭️ Update frontend config with production URL
4. ⏭️ Test full end-to-end workflow
5. ⏭️ Document deployment for team

## Support

For issues:

1. Check backend logs: `uvicorn` console output
2. Check frontend logs: Flutter DevTools
3. Test API directly with curl
4. Review `BACKEND_REPORTS_INTEGRATION.md` for detailed info
