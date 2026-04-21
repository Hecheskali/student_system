import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/services/report_file_saver.dart';

// Professional color scheme for reports
class ReportColors {
  static const PdfColor primary = PdfColor(
    0.08,
    0.30,
    0.70,
  ); // Professional blue
  static const PdfColor primaryDark = PdfColor(0.05, 0.20, 0.50); // Dark blue
  static const PdfColor accent = PdfColor(
    0.90,
    0.35,
    0.15,
  ); // Professional orange
  static const PdfColor lightBg = PdfColor(0.96, 0.97, 0.99); // Light blue-gray
  static const PdfColor mediumBg = PdfColor(
    0.92,
    0.94,
    0.97,
  ); // Medium blue-gray
  static const PdfColor textDark = PdfColor(0.15, 0.20, 0.30); // Dark text
  static const PdfColor textLight = PdfColor(0.45, 0.50, 0.60); // Light text
  static const PdfColor border = PdfColor(0.80, 0.83, 0.88); // Border color
  static const PdfColor success = PdfColor(0.20, 0.65, 0.50); // Success green
  static const PdfColor warning = PdfColor(0.95, 0.60, 0.10); // Warning orange
}

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
    this.pdfColumnFlexes,
  });

  final String title;
  final List<String> headers;
  final List<List<Object?>> rows;
  final String? note;
  final List<double>? pdfColumnFlexes;
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
    this.pdfLandscape = false,
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
  final bool pdfLandscape;
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
    final bool useLandscape =
        report.pdfLandscape ||
        report.sections.any(
          (ReportExportSection section) => section.headers.length >= 9,
        );

    document.addPage(
      pw.MultiPage(
        pageFormat: useLandscape
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        margin: pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        build: (pw.Context context) => _buildProfessionalReport(
          report: report,
          useLandscape: useLandscape,
          context: context,
        ),
        footer: (pw.Context context) =>
            _buildProfessionalFooter(report, context),
      ),
    );

    final Uint8List bytes = await document.save();
    return _saveBytes(
      suggestedName: '$suggestedBaseName.${ReportFileFormat.pdf.extension}',
      bytes: bytes,
      format: ReportFileFormat.pdf,
    );
  }

  static List<pw.Widget> _buildProfessionalReport({
    required ReportExportData report,
    required bool useLandscape,
    required pw.Context context,
  }) {
    return <pw.Widget>[
      _buildProfessionalHeader(report),
      pw.SizedBox(height: 18),
      _buildMetadataSection(report),
      pw.SizedBox(height: 20),
      if (report.summary.isNotEmpty) ...<pw.Widget>[
        _buildSummaryBoxes(report),
        pw.SizedBox(height: 20),
      ],
      for (
        int index = 0;
        index < report.sections.length;
        index += 1
      ) ...<pw.Widget>[
        ..._buildProfessionalSection(
          section: report.sections[index],
          useLandscape: useLandscape,
        ),
        if (index < report.sections.length - 1) pw.SizedBox(height: 16),
      ],
    ];
  }

  static pw.Widget _buildProfessionalHeader(ReportExportData report) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: ReportColors.primary, width: 3),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      report.title.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: ReportColors.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if ((report.schoolName ?? '').isNotEmpty)
                      pw.SizedBox(height: 4),
                    if ((report.schoolName ?? '').isNotEmpty)
                      pw.Text(
                        report.schoolName!,
                        style: pw.TextStyle(
                          fontSize: 11,
                          color: ReportColors.textLight,
                        ),
                      ),
                  ],
                ),
              ),
              if (report.generatedAt != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: <pw.Widget>[
                    pw.Text(
                      _formatDate(report.generatedAt),
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: ReportColors.textLight,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'ID: ${_generateReportId(report.generatedAt)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: ReportColors.border,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if ((report.subtitle ?? '').isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 8),
            pw.Text(
              report.subtitle!,
              style: pw.TextStyle(
                fontSize: 10,
                color: ReportColors.textLight,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildMetadataSection(ReportExportData report) {
    final List<pw.Widget> metadata = <pw.Widget>[];

    if ((report.reportType ?? '').isNotEmpty) {
      metadata.add(_buildMetadataItem('Report Type', report.reportType!));
    }
    if ((report.examWindowLabel ?? '').isNotEmpty) {
      metadata.add(_buildMetadataItem('Exam Period', report.examWindowLabel!));
    }

    if (metadata.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Wrap(spacing: 24, runSpacing: 8, children: metadata);
  }

  static pw.Widget _buildMetadataItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            color: ReportColors.textLight,
            letterSpacing: 0.3,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            color: ReportColors.textDark,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryBoxes(ReportExportData report) {
    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: report.summary.map((ReportSummaryItem item) {
        return pw.Container(
          width: 140,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: ReportColors.lightBg,
            border: pw.Border(
              left: pw.BorderSide(color: ReportColors.primary, width: 3),
            ),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Text(
                item.label,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(fontSize: 8, color: ReportColors.textLight),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                item.value,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: ReportColors.primary,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static List<pw.Widget> _buildProfessionalSection({
    required ReportExportSection section,
    required bool useLandscape,
  }) {
    final bool denseTable = useLandscape || section.headers.length >= 9;
    final double cellFontSize = denseTable ? 7.8 : 9;
    final double headerFontSize = denseTable ? 8.5 : 10;

    return <pw.Widget>[
      pw.Text(
        section.title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: ReportColors.primaryDark,
          letterSpacing: 0.3,
        ),
      ),
      if ((section.note ?? '').isNotEmpty) ...<pw.Widget>[
        pw.SizedBox(height: 4),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: ReportColors.mediumBg,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            section.note!,
            style: pw.TextStyle(
              fontSize: 9,
              color: ReportColors.textLight,
              height: 1.3,
            ),
          ),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.TableHelper.fromTextArray(
        headers: section.headers,
        data: section.rows.map<List<String>>((List<Object?> row) {
          return row.map<String>(_stringify).toList();
        }).toList(),
        columnWidths: _buildPdfColumnWidths(section),
        cellAlignments: _buildPdfCellAlignments(section.headers),
        headerAlignments: _buildPdfCellAlignments(section.headers),
        headerStyle: pw.TextStyle(
          fontSize: headerFontSize,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.3,
        ),
        headerDecoration: pw.BoxDecoration(color: ReportColors.primary),
        rowDecoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: ReportColors.border, width: 0.5),
          ),
        ),
        oddRowDecoration: pw.BoxDecoration(
          color: ReportColors.lightBg,
          border: pw.Border(
            bottom: pw.BorderSide(color: ReportColors.border, width: 0.5),
          ),
        ),
        cellStyle: pw.TextStyle(
          fontSize: cellFontSize,
          color: ReportColors.textDark,
        ),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: pw.EdgeInsets.symmetric(
          horizontal: denseTable ? 5 : 7,
          vertical: denseTable ? 6 : 8,
        ),
        headerPadding: pw.EdgeInsets.symmetric(
          horizontal: denseTable ? 5 : 8,
          vertical: denseTable ? 8 : 9,
        ),
        border: pw.TableBorder(
          top: pw.BorderSide(color: ReportColors.primary, width: 1.5),
          bottom: pw.BorderSide(color: ReportColors.border, width: 0.5),
          horizontalInside: pw.BorderSide(
            color: ReportColors.border,
            width: 0.3,
          ),
          verticalInside: pw.BorderSide(color: ReportColors.border, width: 0.3),
          left: pw.BorderSide(color: ReportColors.border, width: 0.5),
          right: pw.BorderSide(color: ReportColors.border, width: 0.5),
        ),
      ),
    ];
  }

  static pw.Widget _buildProfessionalFooter(
    ReportExportData report,
    pw.Context context,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: ReportColors.border, width: 1),
        ),
      ),
      padding: const pw.EdgeInsets.only(top: 12),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                if ((report.footnote ?? '').isNotEmpty)
                  pw.Text(
                    report.footnote!,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: ReportColors.textLight,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: ReportColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<String?> _saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    required ReportFileFormat format,
  }) async {
    return saveGeneratedReport(
      suggestedName: suggestedName,
      bytes: bytes,
      formatLabel: format.label,
      extension: format.extension,
      mimeType: format.mimeType,
    );
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

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    final List<String> monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final String month = monthNames[value.month - 1];
    return '${value.day} $month ${value.year}';
  }

  static String _generateReportId(DateTime? value) {
    if (value == null) {
      return 'N/A';
    }
    final String year = value.year.toString().substring(2);
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return 'RPT-$year$month$day-$hour$minute';
  }

  static Map<int, pw.TableColumnWidth>? _buildPdfColumnWidths(
    ReportExportSection section,
  ) {
    final List<String> headers = section.headers;
    if (headers.isEmpty) {
      return null;
    }

    if (section.pdfColumnFlexes != null &&
        section.pdfColumnFlexes!.length == headers.length) {
      return <int, pw.TableColumnWidth>{
        for (int index = 0; index < headers.length; index += 1)
          index: pw.FlexColumnWidth(section.pdfColumnFlexes![index]),
      };
    }

    return <int, pw.TableColumnWidth>{
      for (int index = 0; index < headers.length; index += 1)
        index: pw.FlexColumnWidth(_inferPdfColumnFlex(headers[index])),
    };
  }

  static Map<int, pw.Alignment> _buildPdfCellAlignments(List<String> headers) {
    return <int, pw.Alignment>{
      for (int index = 0; index < headers.length; index += 1)
        index: _inferPdfAlignment(headers[index]),
    };
  }

  static double _inferPdfColumnFlex(String header) {
    final String normalized = header.toLowerCase();

    if (normalized.contains('student')) {
      return 2.3;
    }
    if (normalized.contains('subject')) {
      return 1.8;
    }
    if (normalized.contains('uploaded on')) {
      return 1.6;
    }
    if (normalized.contains('uploaded by')) {
      return 1.35;
    }
    if (normalized.contains('exam label')) {
      return 1.45;
    }
    if (normalized.contains('exam date')) {
      return 1.1;
    }
    if (normalized.contains('exam type')) {
      return 1.15;
    }
    if (normalized.contains('admission')) {
      return 1.25;
    }
    if (normalized == 'class') {
      return 1.0;
    }
    if (normalized.contains('division')) {
      return 1.15;
    }
    if (normalized.contains('attendance')) {
      return 1.1;
    }
    if (normalized.contains('average')) {
      return 1.0;
    }
    if (normalized.contains('score') ||
        normalized.contains('grade') ||
        normalized.contains('points')) {
      return 0.85;
    }
    return 1.0;
  }

  static pw.Alignment _inferPdfAlignment(String header) {
    final String normalized = header.toLowerCase();

    if (normalized.contains('score') ||
        normalized.contains('average') ||
        normalized.contains('attendance') ||
        normalized.contains('points') ||
        normalized.contains('conducted')) {
      return pw.Alignment.centerRight;
    }

    if (normalized.contains('date') ||
        normalized.contains('type') ||
        normalized == 'class' ||
        normalized.contains('division') ||
        normalized.contains('grade')) {
      return pw.Alignment.center;
    }

    return pw.Alignment.centerLeft;
  }
}
