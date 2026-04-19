import '../../domain/entities/education_entities.dart';
import '../../domain/services/necta_olevel_calculator.dart';

List<ExamMark> filterExamMarks(List<ExamMark> marks, ExamType? type) {
  if (type == null) {
    return marks;
  }
  return marks.where((ExamMark mark) => mark.type == type).toList();
}

SubjectResult? filterSubjectResult(SubjectResult subject, ExamType? type) {
  final List<ExamMark> marks = filterExamMarks(subject.examMarks, type);
  if (marks.isEmpty) {
    return null;
  }

  double average;
  // Special calculation for science subjects
  if (_isScienceSubject(subject.subject)) {
    final double theory = marks
        .where((mark) => mark.component == ExamComponent.theory)
        .fold(0.0, (sum, mark) => sum + mark.score);
    final double practical = marks
        .where((mark) => mark.component == ExamComponent.practical)
        .fold(0.0, (sum, mark) => sum + mark.score);
    // If both are present, use the formula; else fallback to normal average
    if (theory > 0 || practical > 0) {
      average = double.parse(
        ((theory + practical) / 150 * 100).toStringAsFixed(1),
      );
    } else {
      average = double.parse(
        (marks.fold<double>(
                  0,
                  (double sum, ExamMark mark) => sum + mark.score,
                ) /
                marks.length)
            .toStringAsFixed(1),
      );
    }
  } else {
    average = double.parse(
      (marks.fold<double>(0, (double sum, ExamMark mark) => sum + mark.score) /
              marks.length)
          .toStringAsFixed(1),
    );
  }
  final NectaOLevelGrade grade = NectaOLevelCalculator.gradeForScore(average);

  return SubjectResult(
    subject: subject.subject,
    examMarks: marks,
    averageScore: average,
    grade: grade.letter,
    gradePoint: grade.point,
    isCoreSubject: subject.isCoreSubject,
  );
}

bool _isScienceSubject(String subject) {
  final lower = subject.toLowerCase();
  return lower.contains('biology') ||
      lower.contains('physics') ||
      lower.contains('chemistry');
}

List<StudentResultRecord> filterStudentResultsByExamType(
  Iterable<StudentResultRecord> records,
  ExamType? type,
) {
  return records
      .map((StudentResultRecord record) {
        final List<SubjectResult> filteredSubjects = record.subjectResults
            .map((SubjectResult subject) => filterSubjectResult(subject, type))
            .whereType<SubjectResult>()
            .toList();

        if (filteredSubjects.isEmpty) {
          return record.copyWith(subjectResults: const <SubjectResult>[]);
        }

        final double averageScore = double.parse(
          (filteredSubjects.fold<double>(
                    0,
                    (double sum, SubjectResult subject) =>
                        sum + subject.averageScore,
                  ) /
                  filteredSubjects.length)
              .toStringAsFixed(1),
        );
        final double interExamAverage = double.parse(
          (filteredSubjects.fold<double>(
                    0,
                    (double sum, SubjectResult subject) =>
                        sum + subject.interExamScore,
                  ) /
                  filteredSubjects.length)
              .toStringAsFixed(1),
        );
        final NectaOLevelDivisionSummary division =
            NectaOLevelCalculator.divisionForSubjects(filteredSubjects);

        return record.copyWith(
          averageScore: averageScore,
          interExamAverage: interExamAverage,
          division: division.division,
          divisionPoints: division.points,
          subjectResults: filteredSubjects,
          riskLevel: averageScore < 45 || record.attendanceRate < 80
              ? RiskLevel.urgent
              : averageScore < 60 || record.attendanceRate < 88
              ? RiskLevel.watch
              : RiskLevel.stable,
        );
      })
      .where((StudentResultRecord record) => record.subjectResults.isNotEmpty)
      .toList();
}

String examFilterLabel(ExamType? type) {
  return type == null ? 'All exams' : type.label;
}

String formatExamMarkList(List<ExamMark> marks) {
  if (marks.isEmpty) {
    return 'No marks';
  }
  return marks
      .map(
        (ExamMark mark) =>
            '${mark.label} (${mark.type.label})'
            '${mark.component == ExamComponent.overall ? '' : ' ${mark.component.label}'}'
            ': ${mark.score.toStringAsFixed(1)}'
            ' | Exam ${formatShortDate(mark.examDate)}'
            ' | Uploaded ${formatShortDate(mark.uploadedAt)}',
      )
      .join('\n');
}

double? getAverageScoreForExamType(SubjectResult subject, ExamType type) {
  final List<ExamMark> marks = subject.examMarks
      .where((ExamMark mark) => mark.type == type)
      .toList();
  if (marks.isEmpty) {
    return null;
  }
  final double total = marks.fold<double>(
    0,
    (double sum, ExamMark mark) => sum + mark.score,
  );
  return double.parse((total / marks.length).toStringAsFixed(1));
}

String formatShortDate(DateTime? value) {
  if (value == null) {
    return 'Not recorded';
  }
  final String month = switch (value.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  return '${value.day.toString().padLeft(2, '0')} $month ${value.year}';
}

String formatDateTimeStamp(DateTime? value) {
  if (value == null) {
    return 'Not recorded';
  }
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '${formatShortDate(value)} $hour:$minute';
}

String examDateRangeLabel(Iterable<StudentResultRecord> records) {
  final List<DateTime> dates =
      records
          .expand(
            (StudentResultRecord record) => record.subjectResults.expand(
              (SubjectResult subject) =>
                  subject.examMarks.map((ExamMark mark) => mark.examDate),
            ),
          )
          .whereType<DateTime>()
          .toList()
        ..sort();
  if (dates.isEmpty) {
    return 'No exam dates recorded';
  }
  if (dates.first == dates.last) {
    return formatShortDate(dates.first);
  }
  return '${formatShortDate(dates.first)} to ${formatShortDate(dates.last)}';
}

DateTime? latestUploadDateForRecord(StudentResultRecord record) {
  final List<DateTime> dates =
      record.subjectResults
          .expand((SubjectResult subject) => subject.examMarks)
          .map((ExamMark mark) => mark.uploadedAt)
          .whereType<DateTime>()
          .toList()
        ..sort();
  return dates.isEmpty ? null : dates.last;
}
