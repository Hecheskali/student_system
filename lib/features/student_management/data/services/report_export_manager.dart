import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/report_config.dart';
import '../models/report_models.dart';
import 'backend_report_service.dart';
import 'report_exporter.dart';

/// Report export manager that handles both frontend and backend generation
class ReportExportManager {
  final Dio? _dio;
  late final BackendReportService _backendService;

  ReportExportManager({Dio? dio}) : _dio = dio {
    if (_dio != null) {
      _backendService = BackendReportService(
        dio: _dio,
        baseUrl: ReportConfig.backendReportApiUrl,
      );
    }
  }

  /// Export a report using either frontend or backend based on configuration
  Future<String?> exportReport({
    required String suggestedBaseName,
    required ReportExportData report,
    required ReportFileFormat format,
  }) async {
    // Use backend if configured and dio is available
    if (ReportConfig.useBackendForReports && _dio != null) {
      return _exportViaBackend(
        suggestedBaseName: suggestedBaseName,
        report: report,
        format: format,
      );
    }

    // Fall back to frontend generation
    return ReportExporter.exportReport(
      suggestedBaseName: suggestedBaseName,
      report: report,
      format: format,
    );
  }

  /// Export via backend API
  Future<String?> _exportViaBackend({
    required String suggestedBaseName,
    required ReportExportData report,
    required ReportFileFormat format,
  }) async {
    try {
      final Uint8List? fileBytes = await _backendService.generateReport(
        reportData: report,
        format: format,
        suggestedBaseName: suggestedBaseName,
      );

      if (fileBytes == null) {
        return null;
      }

      // Save file locally
      return _saveFileToDevice(
        filename: suggestedBaseName,
        format: format,
        bytes: fileBytes,
      );
    } catch (e) {
      print('Backend export failed: $e, falling back to frontend');
      // Fallback to frontend on error
      return ReportExporter.exportReport(
        suggestedBaseName: suggestedBaseName,
        report: report,
        format: format,
      );
    }
  }

  /// Save file to device (platform-specific)
  Future<String?> _saveFileToDevice({
    required String filename,
    required ReportFileFormat format,
    required Uint8List bytes,
  }) async {
    try {
      final String extension = _getExtension(format);

      // For web, we would handle this differently
      // For mobile/desktop, use file_selector or path_provider

      // This is a placeholder - implement per-platform logic
      // For now, return the filename to indicate success
      return '$filename.$extension';
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  String _getExtension(ReportFileFormat format) {
    switch (format) {
      case ReportFileFormat.excel:
        return 'xlsx';
      case ReportFileFormat.pdf:
        return 'pdf';
      case ReportFileFormat.csv:
        return 'csv';
    }
  }

  /// Generate exam ledger via backend
  Future<String?> generateExamLedgerViaBackend({
    required String className,
    required String schoolName,
    required String districtName,
    required List<StudentResultRecord> studentRecords,
    required List<String> headers,
    required List<List<Object?>> rows,
    String? examType,
    String? examWindowLabel,
    required ReportFileFormat format,
  }) async {
    if (!ReportConfig.useBackendForReports || _dio == null) {
      return null;
    }

    try {
      final Uint8List? fileBytes = await _backendService.generateExamLedger(
        className: className,
        schoolName: schoolName,
        districtName: districtName,
        studentRecords: studentRecords,
        headers: headers,
        rows: rows,
        examType: examType,
        examWindowLabel: examWindowLabel,
        format: format,
      );

      if (fileBytes == null) {
        return null;
      }

      return _saveFileToDevice(
        filename: 'exam_ledger_report',
        format: format,
        bytes: fileBytes,
      );
    } catch (e) {
      print('Exam ledger export failed: $e');
      return null;
    }
  }
}
