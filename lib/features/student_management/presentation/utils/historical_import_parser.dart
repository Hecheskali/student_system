import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/entities/school_records_entities.dart';
import '../../domain/services/necta_olevel_calculator.dart';
import '../../domain/services/necta_olevel_subjects.dart';

class HistoricalImportPreview {
  const HistoricalImportPreview({
    required this.fileName,
    required this.headers,
    required this.results,
    required this.warningCount,
  });

  final String fileName;
  final List<String> headers;
  final List<StudentResultRecord> results;
  final int warningCount;
}

class HistoricalImportParser {
  static final List<String> _subjects = kNectaOLevelSubjectNames;

  static Future<HistoricalImportPreview?> pickAndParse({
    required ExamSession session,
  }) async {
    final XTypeGroup typeGroup = XTypeGroup(
      label: 'Historical results',
      extensions: const <String>['csv', 'xlsx'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) {
      return null;
    }

    final Uint8List bytes = await file.readAsBytes();
    return parseFile(
      fileName: file.name,
      bytes: bytes,
      session: session,
    );
  }

  static HistoricalImportPreview parseFile({
    required String fileName,
    required Uint8List bytes,
    required ExamSession session,
  }) {
    final String lowerName = fileName.toLowerCase();
    final List<List<String>> rows = lowerName.endsWith('.xlsx')
        ? _parseExcel(bytes)
        : _parseCsv(bytes);

    if (rows.isEmpty) {
      return HistoricalImportPreview(
        fileName: fileName,
        headers: const <String>[],
        results: const <StudentResultRecord>[],
        warningCount: 1,
      );
    }

    final List<String> headers = rows.first;
    final List<String> normalizedHeaders = headers
        .map((String item) => item.trim().toLowerCase())
        .toList();
    final int admissionIndex = _indexFor(
      normalizedHeaders,
      const <String>['admission', 'admission number', 'adm'],
    );
    final int studentIndex = _indexFor(
      normalizedHeaders,
      const <String>['student', 'student name', 'name'],
    );
    final int classIndex = _indexFor(
      normalizedHeaders,
      const <String>['class', 'class name', 'stream'],
    );

    int warnings = 0;
    final List<StudentResultRecord> results = <StudentResultRecord>[];

    for (int rowIndex = 1; rowIndex < rows.length; rowIndex += 1) {
      final List<String> row = rows[rowIndex];
      if (row.every((String cell) => cell.trim().isEmpty)) {
        continue;
      }

      if (admissionIndex < 0 || studentIndex < 0 || classIndex < 0) {
        warnings += 1;
        continue;
      }

      final String admission = _cell(row, admissionIndex);
      final String studentName = _cell(row, studentIndex);
      final String className = _cell(row, classIndex);
      final List<SubjectResult> subjects = <SubjectResult>[];

      for (final String subject in _subjects) {
        final int subjectIndex = _indexFor(
          normalizedHeaders,
          <String>[subject.toLowerCase()],
        );
        if (subjectIndex < 0) {
          continue;
        }

        final double? score = double.tryParse(_cell(row, subjectIndex));
        if (score == null) {
          continue;
        }
        subjects.add(_buildSubjectResult(subject: subject, score: score));
      }

      if (admission.isEmpty ||
          studentName.isEmpty ||
          className.isEmpty ||
          subjects.length < 3) {
        warnings += 1;
        continue;
      }

      results.add(
        _composeResult(
          id: 'parsed-${session.id}-$rowIndex',
          admissionNumber: admission,
          studentName: studentName,
          className: className,
          subjectResults: subjects,
        ),
      );
    }

    return HistoricalImportPreview(
      fileName: fileName,
      headers: headers,
      results: results,
      warningCount: warnings,
    );
  }

  static List<List<String>> _parseCsv(Uint8List bytes) {
    final String text = utf8.decode(bytes);
    return LineSplitter.split(text)
        .where((String line) => line.trim().isNotEmpty)
        .map(
          (String line) => line.split(',').map((String cell) => cell.trim()).toList(),
        )
        .toList();
  }

  static List<List<String>> _parseExcel(Uint8List bytes) {
    final Excel excel = Excel.decodeBytes(bytes);
    final String? defaultSheet = excel.tables.keys.isEmpty ? null : excel.tables.keys.first;
    if (defaultSheet == null) {
      return const <List<String>>[];
    }

    final Sheet? sheet = excel.tables[defaultSheet];
    if (sheet == null) {
      return const <List<String>>[];
    }

    return sheet.rows.map((List<Data?> row) {
      return row
          .map((Data? cell) => cell == null ? '' : '${cell.value}'.trim())
          .toList();
    }).toList();
  }

  static int _indexFor(List<String> headers, List<String> candidates) {
    for (final String candidate in candidates) {
      final int index = headers.indexOf(candidate);
      if (index >= 0) {
        return index;
      }
    }
    return -1;
  }

  static String _cell(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index].trim();
  }

  static SubjectResult _buildSubjectResult({
    required String subject,
    required double score,
  }) {
    final double clamped = score.clamp(0, 100).toDouble();
    final double average = double.parse(
      clamped.toStringAsFixed(1),
    );
    final NectaOLevelGrade grade = NectaOLevelCalculator.gradeForScore(average);

    return SubjectResult(
      subject: subject,
      examMarks: <ExamMark>[
        ExamMark(
          id: '$subject-class',
          label: 'Class Exam 1',
          type: ExamType.classExam,
          score: (clamped - 4).clamp(0, 100).toDouble(),
        ),
        ExamMark(
          id: '$subject-mid',
          label: 'Mid-Term 1',
          type: ExamType.midTerm,
          score: (clamped - 2).clamp(0, 100).toDouble(),
        ),
        ExamMark(
          id: '$subject-annual',
          label: 'Annual 1',
          type: ExamType.annual,
          score: clamped,
        ),
      ],
      averageScore: average,
      grade: grade.letter,
      gradePoint: grade.point,
    );
  }

  static StudentResultRecord _composeResult({
    required String id,
    required String admissionNumber,
    required String studentName,
    required String className,
    required List<SubjectResult> subjectResults,
  }) {
    final NectaOLevelDivisionSummary divisionSummary =
        NectaOLevelCalculator.divisionForSubjects(subjectResults);
    final double averageScore = double.parse(
      (
        subjectResults.fold<double>(
              0,
              (double total, SubjectResult subject) => total + subject.averageScore,
            ) /
            subjectResults.length
      ).toStringAsFixed(1),
    );
    final double interExamAverage = double.parse(
      (
        subjectResults.fold<double>(
              0,
              (double total, SubjectResult subject) => total + subject.interExamScore,
            ) /
            subjectResults.length
      ).toStringAsFixed(1),
    );
    final RiskLevel riskLevel = averageScore < 45
        ? RiskLevel.urgent
        : averageScore < 60
        ? RiskLevel.watch
        : RiskLevel.stable;

    return StudentResultRecord(
      id: id,
      admissionNumber: admissionNumber,
      studentName: studentName,
      className: className,
      averageScore: averageScore,
      interExamAverage: interExamAverage,
      division: divisionSummary.division,
      divisionPoints: divisionSummary.points,
      attendanceRate: 90,
      subjectResults: subjectResults,
      performanceTrend: <ScorePoint>[
        ScorePoint(label: 'Term 1', value: (averageScore - 5).clamp(0, 100).toDouble()),
        ScorePoint(label: 'Inter', value: (averageScore - 2).clamp(0, 100).toDouble()),
        ScorePoint(label: 'Term 2', value: (averageScore - 1).clamp(0, 100).toDouble()),
        ScorePoint(label: 'Current', value: averageScore),
      ],
      riskLevel: riskLevel,
    );
  }
}
