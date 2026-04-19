import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/report_models.dart';

/// Service to handle report generation via backend API
class BackendReportService {
  final Dio _dio;
  final String _baseUrl;

  BackendReportService({
    required Dio dio,
    String baseUrl = 'http://localhost:8000/api/v1',
  }) : _dio = dio,
       _baseUrl = baseUrl;

  /// Generate a report via the backend
  ///
  /// Returns the file bytes if successful
  Future<Uint8List?> generateReport({
    required ReportExportData reportData,
    required ReportFileFormat format,
    required String suggestedBaseName,
  }) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'report_data': _reportToJson(reportData),
        'format': format.name,
        'filename': suggestedBaseName,
      };

      final Response<List<int>> response = await _dio.post<List<int>>(
        '$_baseUrl/reports/generate',
        data: payload,
        options: Options(
          responseType: ResponseType.bytes,
          contentType: Headers.jsonContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }

      debugPrint('Failed to generate report: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      debugPrint('DioException generating report: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error generating report: $e');
      return null;
    }
  }

  /// Generate an exam ledger report via the backend
  ///
  /// Returns the file bytes if successful
  Future<Uint8List?> generateExamLedger({
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
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'class_name': className,
        'school_name': schoolName,
        'district_name': districtName,
        'exam_type': examType ?? 'All',
        'exam_window_label': examWindowLabel ?? '',
        'headers': headers,
        'rows': rows.map((List<Object?> row) {
          return row.map((Object? cell) {
            if (cell == null) return '';
            if (cell is double) return cell.toStringAsFixed(1);
            return cell.toString();
          }).toList();
        }).toList(),
        'format': format.name,
      };

      final Response<List<int>> response = await _dio.post<List<int>>(
        '$_baseUrl/reports/exam-ledger',
        data: payload,
        options: Options(
          responseType: ResponseType.bytes,
          contentType: Headers.jsonContentType,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }

      debugPrint('Failed to generate exam ledger: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      debugPrint('DioException generating exam ledger: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error generating exam ledger: $e');
      return null;
    }
  }

  /// Convert ReportExportData to JSON format for API
  Map<String, dynamic> _reportToJson(ReportExportData report) {
    return <String, dynamic>{
      'title': report.title,
      'subtitle': report.subtitle,
      'school_name': report.schoolName,
      'report_type': report.reportType,
      'exam_window_label': report.examWindowLabel,
      'generated_at': report.generatedAt?.toIso8601String(),
      'pdf_landscape': report.pdfLandscape,
      'summary': report.summary
          .map(
            (ReportSummaryItem item) => <String, dynamic>{
              'label': item.label,
              'value': item.value,
            },
          )
          .toList(),
      'sections': report.sections
          .map(
            (ReportExportSection section) => <String, dynamic>{
              'title': section.title,
              'note': section.note,
              'headers': section.headers,
              'rows': section.rows
                  .map(
                    (List<Object?> row) => row
                        .map((Object? cell) => cell?.toString() ?? '')
                        .toList(),
                  )
                  .toList(),
              'pdf_column_flexes': section.pdfColumnFlexes,
            },
          )
          .toList(),
      'footnote': report.footnote,
    };
  }
}
