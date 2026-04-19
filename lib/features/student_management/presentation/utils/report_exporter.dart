import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ReportFileFormat { excel, pdf, csv }

extension ReportFileFormatX on ReportFileFormat {
  String get label {
    switch (this) {
      case ReportFileFormat.excel:
        return 'Excel';
      case ReportFileFormat.pdf:
        return 'PDF';
      case ReportFileFormat.csv:
        return 'CSV';
    }
  }

  String get extension {
    switch (this) {
      case ReportFileFormat.excel:
        return 'xlsx';
      case ReportFileFormat.pdf:
        return 'pdf';
      case ReportFileFormat.csv:
        return 'csv';
    }
  }

  String get mimeType {
    switch (this) {
      case ReportFileFormat.excel:
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case ReportFileFormat.pdf:
        return 'application/pdf';
      case ReportFileFormat.csv:
        return 'text/csv';
    }
  }
}

class ReportSummaryItem {
  const ReportSummaryItem({required this.label, required this.value});

  final String label;
  final String value;
}

class ReportExportSection {
  const ReportExportSection({
    required this.title,
    required this.headers,
    required this.rows,
    this.note,
  });

  final String title;
  final List<String> headers;
  final List<List<Object?>> rows;
  final String? note;
}

class ReportExportData {
  const ReportExportData({
    required this.title,
    required this.sections,
    this.subtitle,
    this.summary = const <ReportSummaryItem>[],
    this.footnote,
    this.schoolName,
    this.reportType,
    this.examWindowLabel,
    this.generatedAt,
  });

  final String title;
  final String? subtitle;
  final List<ReportSummaryItem> summary;
  final List<ReportExportSection> sections;
  final String? footnote;
  final String? schoolName;
  final String? reportType;
  final String? examWindowLabel;
  final DateTime? generatedAt;
}

class ReportExporter {
  static Future<String?> exportCsv({
    required String suggestedName,
    required String content,
  }) async {
    return _saveBytes(
      suggestedName: suggestedName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      format: ReportFileFormat.csv,
    );
  }

  static Future<String?> exportReport({
    required String suggestedBaseName,
    required ReportExportData report,
    required ReportFileFormat format,
  }) async {
    switch (format) {
      case ReportFileFormat.excel:
        return _exportExcel(
          suggestedBaseName: suggestedBaseName,
          report: report,
        );
      case ReportFileFormat.pdf:
        return _exportPdf(suggestedBaseName: suggestedBaseName, report: report);
      case ReportFileFormat.csv:
        return exportCsv(
          suggestedName: '$suggestedBaseName.${ReportFileFormat.csv.extension}',
          content: _reportToCsv(report),
        );
    }
  }

  static Future<String?> _exportExcel({
    required String suggestedBaseName,
    required ReportExportData report,
  }) async {
    final Excel excel = Excel.createExcel();
    final String? defaultSheet = excel.getDefaultSheet();

    for (int index = 0; index < report.sections.length; index += 1) {
      final ReportExportSection section = report.sections[index];
      final String sheetName = _sheetNameFor(section.title, index);

      if (index == 0 && defaultSheet != null && defaultSheet != sheetName) {
        excel.rename(defaultSheet, sheetName);
      }

      final Sheet sheet = excel[sheetName];
      sheet.appendRow(<CellValue?>[TextCellValue(report.title)]);

      if ((report.schoolName ?? '').isNotEmpty) {
        sheet.appendRow(<CellValue?>[
          TextCellValue('School'),
          TextCellValue(report.schoolName!),
        ]);
      }

      if ((report.reportType ?? '').isNotEmpty) {
        sheet.appendRow(<CellValue?>[
          TextCellValue('Report Type'),
          TextCellValue(report.reportType!),
        ]);
      }

      if ((report.examWindowLabel ?? '').isNotEmpty) {
        sheet.appendRow(<CellValue?>[
          TextCellValue('Exam Dates'),
          TextCellValue(report.examWindowLabel!),
        ]);
      }

      if (report.generatedAt != null) {
        sheet.appendRow(<CellValue?>[
          TextCellValue('Generated On'),
          TextCellValue(_formatDateTime(report.generatedAt)),
        ]);
      }

      if ((report.subtitle ?? '').isNotEmpty) {
        sheet.appendRow(<CellValue?>[TextCellValue(report.subtitle!)]);
      }

      if (report.summary.isNotEmpty) {
        for (final ReportSummaryItem item in report.summary) {
          sheet.appendRow(<CellValue?>[
            TextCellValue(item.label),
            TextCellValue(item.value),
          ]);
        }
      }

      if ((section.note ?? '').isNotEmpty) {
        sheet.appendRow(<CellValue?>[TextCellValue(section.note!)]);
      }

      sheet.appendRow(<CellValue?>[TextCellValue('')]);
      sheet.appendRow(
        section.headers.map<CellValue?>((String value) {
          return TextCellValue(value);
        }).toList(),
      );

      for (final List<Object?> row in section.rows) {
        sheet.appendRow(
          row.map<CellValue?>((Object? value) {
            return _toCellValue(value);
          }).toList(),
        );
      }

      if ((report.footnote ?? '').isNotEmpty) {
        sheet.appendRow(<CellValue?>[TextCellValue('')]);
        sheet.appendRow(<CellValue?>[TextCellValue(report.footnote!)]);
      }
    }

    final List<int>? bytes = excel.save(
      fileName: '$suggestedBaseName.${ReportFileFormat.excel.extension}',
    );
    if (bytes == null) {
      return null;
    }

    return _saveBytes(
      suggestedName: '$suggestedBaseName.${ReportFileFormat.excel.extension}',
      bytes: Uint8List.fromList(bytes),
      format: ReportFileFormat.excel,
    );
  }

  static Future<String?> _exportPdf({
    required String suggestedBaseName,
    required ReportExportData report,
  }) async {
    final pw.Document document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              report.title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            if ((report.schoolName ?? '').isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 4),
              pw.Text('School: ${report.schoolName!}'),
            ],
            if ((report.reportType ?? '').isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 2),
              pw.Text('Report type: ${report.reportType!}'),
            ],
            if ((report.examWindowLabel ?? '').isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 2),
              pw.Text('Exam dates: ${report.examWindowLabel!}'),
            ],
            if (report.generatedAt != null) ...<pw.Widget>[
              pw.SizedBox(height: 2),
              pw.Text('Generated on: ${_formatDateTime(report.generatedAt)}'),
            ],
            if ((report.subtitle ?? '').isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 6),
              pw.Text(report.subtitle!),
            ],
            if (report.summary.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 16),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: report.summary.map((ReportSummaryItem item) {
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Text('${item.label}: ${item.value}'),
                  );
                }).toList(),
              ),
            ],
            for (final ReportExportSection section
                in report.sections) ...<pw.Widget>[
              pw.SizedBox(height: 22),
              pw.Text(
                section.title,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if ((section.note ?? '').isNotEmpty) ...<pw.Widget>[
                pw.SizedBox(height: 4),
                pw.Text(section.note!, style: const pw.TextStyle(fontSize: 10)),
              ],
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: section.headers,
                data: section.rows.map<List<String>>((List<Object?> row) {
                  return row.map<String>(_stringify).toList();
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
                headerPadding: const pw.EdgeInsets.all(7),
                border: pw.TableBorder.all(color: PdfColors.grey400),
              ),
            ],
            if ((report.footnote ?? '').isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 18),
              pw.Text(
                report.footnote!,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ];
        },
      ),
    );

    final Uint8List bytes = await document.save();
    return _saveBytes(
      suggestedName: '$suggestedBaseName.${ReportFileFormat.pdf.extension}',
      bytes: bytes,
      format: ReportFileFormat.pdf,
    );
  }

  static Future<String?> _saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    required ReportFileFormat format,
  }) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: format.label, extensions: <String>[format.extension]),
      ],
    );

    if (location == null) {
      return null;
    }

    final XFile file = XFile.fromData(
      bytes,
      mimeType: format.mimeType,
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return location.path;
  }

  static String _reportToCsv(ReportExportData report) {
    final StringBuffer buffer = StringBuffer()..writeln(report.title);

    if ((report.schoolName ?? '').isNotEmpty) {
      buffer.writeln('School,${report.schoolName}');
    }
    if ((report.reportType ?? '').isNotEmpty) {
      buffer.writeln('Report Type,${report.reportType}');
    }
    if ((report.examWindowLabel ?? '').isNotEmpty) {
      buffer.writeln('Exam Dates,${report.examWindowLabel}');
    }
    if (report.generatedAt != null) {
      buffer.writeln('Generated On,${_formatDateTime(report.generatedAt)}');
    }

    if ((report.subtitle ?? '').isNotEmpty) {
      buffer.writeln(report.subtitle);
    }

    if (report.summary.isNotEmpty) {
      for (final ReportSummaryItem item in report.summary) {
        buffer.writeln('${item.label},${item.value}');
      }
      buffer.writeln();
    }

    for (int index = 0; index < report.sections.length; index += 1) {
      final ReportExportSection section = report.sections[index];
      buffer.writeln(section.title);
      if ((section.note ?? '').isNotEmpty) {
        buffer.writeln(section.note);
      }
      buffer.writeln(section.headers.join(','));
      for (final List<Object?> row in section.rows) {
        buffer.writeln(row.map<String>(_csvEscape).join(','));
      }
      if (index != report.sections.length - 1) {
        buffer.writeln();
      }
    }

    if ((report.footnote ?? '').isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(report.footnote);
    }

    return buffer.toString();
  }

  static CellValue? _toCellValue(Object? value) {
    if (value == null) {
      return TextCellValue('');
    }
    if (value is int) {
      return IntCellValue(value);
    }
    if (value is double) {
      return DoubleCellValue(value);
    }
    if (value is bool) {
      return BoolCellValue(value);
    }
    return TextCellValue(_stringify(value));
  }

  static String _sheetNameFor(String title, int index) {
    final String cleaned = title.replaceAll(RegExp(r'[:\\/?*\[\]]'), '').trim();
    final String fallback = 'Sheet ${index + 1}';
    final String value = cleaned.isEmpty ? fallback : cleaned;
    return value.length <= 31 ? value : value.substring(0, 31);
  }

  static String _stringify(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is double) {
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    }
    return value.toString();
  }

  static String _csvEscape(Object? value) {
    final String text = _stringify(value);
    if (!text.contains(',') && !text.contains('"') && !text.contains('\n')) {
      return text;
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '';
    }
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}
