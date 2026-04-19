import 'package:flutter/foundation.dart';

enum RiskLevel { stable, watch, urgent }

enum UserRole { teacher, academicMaster, headOfSchool }

enum SearchEntityType { student, teacher, result, subject, schoolClass }

enum ExamType { midTerm, annual, classExam, teacherNamed }

enum ExamComponent { overall, theory, practical }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.academicMaster:
        return 'Academic Master';
      case UserRole.headOfSchool:
        return 'Headmaster';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.academicMaster:
        return 'Academic Master';
      case UserRole.headOfSchool:
        return 'Headmaster';
    }
  }

  String get description {
    switch (this) {
      case UserRole.teacher:
        return 'Can add students, upload results, and update scores during the active reporting window.';
      case UserRole.academicMaster:
        return 'Manages exam uploads, reviews results, sets deadlines, and oversees academic performance.';
      case UserRole.headOfSchool:
        return 'Owns school-wide monitoring, teacher permissions, reporting windows, and performance oversight.';
    }
  }
}

extension SearchEntityTypeX on SearchEntityType {
  String get label {
    switch (this) {
      case SearchEntityType.student:
        return 'Student';
      case SearchEntityType.teacher:
        return 'Teacher';
      case SearchEntityType.result:
        return 'Result';
      case SearchEntityType.subject:
        return 'Subject';
      case SearchEntityType.schoolClass:
        return 'Class';
    }
  }
}

extension ExamTypeX on ExamType {
  String get label {
    switch (this) {
      case ExamType.midTerm:
        return 'Mid-Term';
      case ExamType.annual:
        return 'Annual';
      case ExamType.classExam:
        return 'Class Exam';
      case ExamType.teacherNamed:
        return 'Teacher Named';
    }
  }
}

extension ExamComponentX on ExamComponent {
  String get label {
    switch (this) {
      case ExamComponent.overall:
        return 'Overall';
      case ExamComponent.theory:
        return 'Theory';
      case ExamComponent.practical:
        return 'Practical';
    }
  }
}

extension RiskLevelX on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.stable:
        return 'Stable';
      case RiskLevel.watch:
        return 'Watch';
      case RiskLevel.urgent:
        return 'Urgent';
    }
  }
}

@immutable
class District {
  const District({
    required this.id,
    required this.name,
    required this.regionLabel,
    required this.totalSchools,
    required this.totalStudents,
    required this.averageAttendance,
    required this.averageScore,
    required this.focusArea,
  });

  final String id;
  final String name;
  final String regionLabel;
  final int totalSchools;
  final int totalStudents;
  final double averageAttendance;
  final double averageScore;
  final String focusArea;
}

@immutable
class School {
  const School({
    required this.id,
    required this.districtId,
    required this.name,
    required this.principal,
    required this.totalClasses,
    required this.totalStudents,
    required this.averageAttendance,
    required this.averageScore,
  });

  final String id;
  final String districtId;
  final String name;
  final String principal;
  final int totalClasses;
  final int totalStudents;
  final double averageAttendance;
  final double averageScore;
}

@immutable
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.schoolId,
    required this.districtId,
    required this.name,
    required this.teacher,
    required this.totalStudents,
    required this.averageAttendance,
    required this.averageScore,
  });

  final String id;
  final String schoolId;
  final String districtId;
  final String name;
  final String teacher;
  final int totalStudents;
  final double averageAttendance;
  final double averageScore;
}

@immutable
class Student {
  const Student({
    required this.id,
    required this.districtId,
    required this.schoolId,
    required this.classId,
    required this.fullName,
    required this.gradeLevel,
    required this.averageScore,
    required this.gpa,
    required this.attendanceRate,
    required this.riskLevel,
    required this.subjectScores,
    required this.monthlyPerformance,
  });

  final String id;
  final String districtId;
  final String schoolId;
  final String classId;
  final String fullName;
  final String gradeLevel;
  final double averageScore;
  final double gpa;
  final double attendanceRate;
  final RiskLevel riskLevel;
  final Map<String, double> subjectScores;
  final List<double> monthlyPerformance;
}

@immutable
class ScorePoint {
  const ScorePoint({required this.label, required this.value});

  final String label;
  final double value;
}

@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.totalDistricts,
    required this.totalSchools,
    required this.totalStudents,
    required this.averageAttendance,
    required this.averageScore,
    required this.atRiskStudents,
    required this.focusStudentId,
    required this.focusStudentName,
    required this.districtPerformance,
    required this.systemTrend,
  });

  final int totalDistricts;
  final int totalSchools;
  final int totalStudents;
  final double averageAttendance;
  final double averageScore;
  final int atRiskStudents;
  final String focusStudentId;
  final String focusStudentName;
  final List<ScorePoint> districtPerformance;
  final List<ScorePoint> systemTrend;
}

@immutable
class ScopeRequest {
  const ScopeRequest({
    this.districtId,
    this.schoolId,
    this.classId,
    this.studentId,
  });

  final String? districtId;
  final String? schoolId;
  final String? classId;
  final String? studentId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ScopeRequest &&
        other.districtId == districtId &&
        other.schoolId == schoolId &&
        other.classId == classId &&
        other.studentId == studentId;
  }

  @override
  int get hashCode => Object.hash(districtId, schoolId, classId, studentId);
}

@immutable
class ScopeSummary {
  const ScopeSummary({
    required this.title,
    required this.subtitle,
    required this.totalStudents,
    required this.averageAttendance,
    required this.averageScore,
    required this.atRiskStudents,
    required this.topPerformer,
    required this.riskDistribution,
    required this.trend,
  });

  final String title;
  final String subtitle;
  final int totalStudents;
  final double averageAttendance;
  final double averageScore;
  final int atRiskStudents;
  final String topPerformer;
  final Map<String, int> riskDistribution;
  final List<ScorePoint> trend;
}

@immutable
class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.schoolName,
    required this.districtName,
    this.subject,
    this.assignedClass,
    this.subjects = const <String>[],
    this.assignedClasses = const <String>[],
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String schoolName;
  final String districtName;
  final String? subject;
  final String? assignedClass;
  final List<String> subjects;
  final List<String> assignedClasses;

  List<String> get effectiveSubjects {
    final List<String> values = <String>[
      if (subject != null && subject!.trim().isNotEmpty) subject!,
      ...subjects,
    ];
    return values.toSet().toList(growable: false);
  }

  List<String> get effectiveClasses {
    final List<String> values = <String>[
      if (assignedClass != null && assignedClass!.trim().isNotEmpty)
        assignedClass!,
      ...assignedClasses,
    ];
    return values.toSet().toList(growable: false);
  }
}

@immutable
class TeacherAccount {
  const TeacherAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.subject,
    required this.assignedClass,
    required this.canUploadResults,
    required this.canEditResults,
    this.subjects = const <String>[],
    this.assignedClasses = const <String>[],
    this.canRegisterStudents = true,
    this.canDownloadResults = true,
  });

  final String id;
  final String name;
  final String email;
  final String subject;
  final String assignedClass;
  final bool canUploadResults;
  final bool canEditResults;
  final List<String> subjects;
  final List<String> assignedClasses;
  final bool canRegisterStudents;
  final bool canDownloadResults;

  List<String> get effectiveSubjects {
    final List<String> values = <String>[subject, ...subjects];
    return values.toSet().toList(growable: false);
  }

  List<String> get effectiveClasses {
    final List<String> values = <String>[assignedClass, ...assignedClasses];
    return values.toSet().toList(growable: false);
  }

  bool teachesSubject(String value) {
    return effectiveSubjects.contains(value);
  }

  TeacherAccount copyWith({
    String? id,
    String? name,
    String? email,
    String? subject,
    String? assignedClass,
    bool? canUploadResults,
    bool? canEditResults,
    List<String>? subjects,
    List<String>? assignedClasses,
    bool? canRegisterStudents,
    bool? canDownloadResults,
  }) {
    return TeacherAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      subject: subject ?? this.subject,
      assignedClass: assignedClass ?? this.assignedClass,
      canUploadResults: canUploadResults ?? this.canUploadResults,
      canEditResults: canEditResults ?? this.canEditResults,
      subjects: subjects ?? this.subjects,
      assignedClasses: assignedClasses ?? this.assignedClasses,
      canRegisterStudents: canRegisterStudents ?? this.canRegisterStudents,
      canDownloadResults: canDownloadResults ?? this.canDownloadResults,
    );
  }
}

@immutable
class SchoolSettings {
  const SchoolSettings({
    required this.currentAcademicYear,
    required this.currentTermLabel,
    required this.enforceTeacherSubjectIsolation,
    required this.autoZeroMissingPracticals,
    required this.allowTeacherStudentRegistration,
    required this.allowTeacherResultDownloads,
    required this.showCombinedResultsToTeachers,
  });

  final String currentAcademicYear;
  final String currentTermLabel;
  final bool enforceTeacherSubjectIsolation;
  final bool autoZeroMissingPracticals;
  final bool allowTeacherStudentRegistration;
  final bool allowTeacherResultDownloads;
  final bool showCombinedResultsToTeachers;

  SchoolSettings copyWith({
    String? currentAcademicYear,
    String? currentTermLabel,
    bool? enforceTeacherSubjectIsolation,
    bool? autoZeroMissingPracticals,
    bool? allowTeacherStudentRegistration,
    bool? allowTeacherResultDownloads,
    bool? showCombinedResultsToTeachers,
  }) {
    return SchoolSettings(
      currentAcademicYear: currentAcademicYear ?? this.currentAcademicYear,
      currentTermLabel: currentTermLabel ?? this.currentTermLabel,
      enforceTeacherSubjectIsolation:
          enforceTeacherSubjectIsolation ?? this.enforceTeacherSubjectIsolation,
      autoZeroMissingPracticals:
          autoZeroMissingPracticals ?? this.autoZeroMissingPracticals,
      allowTeacherStudentRegistration:
          allowTeacherStudentRegistration ??
          this.allowTeacherStudentRegistration,
      allowTeacherResultDownloads:
          allowTeacherResultDownloads ?? this.allowTeacherResultDownloads,
      showCombinedResultsToTeachers:
          showCombinedResultsToTeachers ?? this.showCombinedResultsToTeachers,
    );
  }
}

@immutable
class ResultWindowSettings {
  const ResultWindowSettings({
    required this.uploadDeadline,
    required this.editDeadline,
    required this.editingLocked,
  });

  final DateTime uploadDeadline;
  final DateTime editDeadline;
  final bool editingLocked;

  ResultWindowSettings copyWith({
    DateTime? uploadDeadline,
    DateTime? editDeadline,
    bool? editingLocked,
  }) {
    return ResultWindowSettings(
      uploadDeadline: uploadDeadline ?? this.uploadDeadline,
      editDeadline: editDeadline ?? this.editDeadline,
      editingLocked: editingLocked ?? this.editingLocked,
    );
  }
}

@immutable
class ExamMark {
  const ExamMark({
    required this.id,
    required this.label,
    required this.type,
    required this.score,
    this.component = ExamComponent.overall,
    this.sessionKey,
    this.teacherId,
    this.teacherName,
    this.examDate,
    this.uploadedAt,
  });

  final String id;
  final String label;
  final ExamType type;
  final double score;
  final ExamComponent component;
  final String? sessionKey;
  final String? teacherId;
  final String? teacherName;
  final DateTime? examDate;
  final DateTime? uploadedAt;

  ExamMark copyWith({
    String? id,
    String? label,
    ExamType? type,
    double? score,
    ExamComponent? component,
    String? sessionKey,
    String? teacherId,
    String? teacherName,
    DateTime? examDate,
    DateTime? uploadedAt,
  }) {
    return ExamMark(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      score: score ?? this.score,
      component: component ?? this.component,
      sessionKey: sessionKey ?? this.sessionKey,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      examDate: examDate ?? this.examDate,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}

@immutable
class SubjectResult {
  const SubjectResult({
    required this.subject,
    required this.examMarks,
    required this.averageScore,
    required this.grade,
    required this.gradePoint,
    this.isCoreSubject = true,
  });

  final String subject;
  final List<ExamMark> examMarks;
  final double averageScore;
  final String grade;
  final int gradePoint;
  final bool isCoreSubject;

  List<double> get examScores =>
      examMarks.map((ExamMark mark) => mark.score).toList(growable: false);

  bool get hasPracticalComponents =>
      examMarks.any((ExamMark mark) => mark.component != ExamComponent.overall);

  double get interExamScore {
    final List<ExamMark> midTerms = examMarks
        .where((ExamMark mark) => mark.type == ExamType.midTerm)
        .toList();
    final List<double> groupedScores = _groupedExamAverages(midTerms);
    if (groupedScores.isEmpty) {
      return 0;
    }
    final double total = groupedScores.fold<double>(
      0,
      (double sum, double score) => sum + score,
    );
    return double.parse((total / groupedScores.length).toStringAsFixed(1));
  }

  int get examsConducted => examMarks.length;

  SubjectResult copyWith({
    String? subject,
    List<ExamMark>? examMarks,
    double? averageScore,
    String? grade,
    int? gradePoint,
    bool? isCoreSubject,
  }) {
    return SubjectResult(
      subject: subject ?? this.subject,
      examMarks: examMarks ?? this.examMarks,
      averageScore: averageScore ?? this.averageScore,
      grade: grade ?? this.grade,
      gradePoint: gradePoint ?? this.gradePoint,
      isCoreSubject: isCoreSubject ?? this.isCoreSubject,
    );
  }
}

@immutable
class StudentResultRecord {
  const StudentResultRecord({
    required this.id,
    required this.admissionNumber,
    required this.studentName,
    required this.className,
    required this.averageScore,
    required this.interExamAverage,
    required this.division,
    required this.divisionPoints,
    required this.attendanceRate,
    required this.subjectResults,
    required this.performanceTrend,
    required this.riskLevel,
  });

  final String id;
  final String admissionNumber;
  final String studentName;
  final String className;
  final double averageScore;
  final double interExamAverage;
  final String division;
  final int divisionPoints;
  final double attendanceRate;
  final List<SubjectResult> subjectResults;
  final List<ScorePoint> performanceTrend;
  final RiskLevel riskLevel;

  int get examsConducted => subjectResults.fold<int>(
    0,
    (int total, SubjectResult result) => total + result.examsConducted,
  );

  String subjectGrade(String subject) {
    return subjectResults
        .firstWhere((SubjectResult item) => item.subject == subject)
        .grade;
  }

  StudentResultRecord copyWith({
    String? id,
    String? admissionNumber,
    String? studentName,
    String? className,
    double? averageScore,
    double? interExamAverage,
    String? division,
    int? divisionPoints,
    double? attendanceRate,
    List<SubjectResult>? subjectResults,
    List<ScorePoint>? performanceTrend,
    RiskLevel? riskLevel,
  }) {
    return StudentResultRecord(
      id: id ?? this.id,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      averageScore: averageScore ?? this.averageScore,
      interExamAverage: interExamAverage ?? this.interExamAverage,
      division: division ?? this.division,
      divisionPoints: divisionPoints ?? this.divisionPoints,
      attendanceRate: attendanceRate ?? this.attendanceRate,
      subjectResults: subjectResults ?? this.subjectResults,
      performanceTrend: performanceTrend ?? this.performanceTrend,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }
}

@immutable
class SubjectPerformanceSummary {
  const SubjectPerformanceSummary({
    required this.subject,
    required this.averageScore,
    required this.interExamAverage,
    required this.passRate,
    required this.topStudent,
    required this.trend,
  });

  final String subject;
  final double averageScore;
  final double interExamAverage;
  final double passRate;
  final String topStudent;
  final List<ScorePoint> trend;
}

@immutable
class ClassPerformanceSummary {
  const ClassPerformanceSummary({
    required this.className,
    required this.totalStudents,
    required this.averageScore,
    required this.interExamAverage,
    required this.passRate,
    required this.topStudent,
    required this.divisionDistribution,
    required this.trend,
  });

  final String className;
  final int totalStudents;
  final double averageScore;
  final double interExamAverage;
  final double passRate;
  final String topStudent;
  final Map<String, int> divisionDistribution;
  final List<ScorePoint> trend;
}

@immutable
class SearchResultItem {
  const SearchResultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String id;
  final SearchEntityType type;
  final String title;
  final String subtitle;
  final String route;
}

@immutable
class SchoolOverview {
  const SchoolOverview({
    required this.schoolName,
    required this.districtName,
    required this.headmasterName,
    required this.totalTeachers,
    required this.totalStudents,
    required this.totalClasses,
    required this.averageScore,
    required this.averageInterExamScore,
    required this.passRate,
    required this.divisionDistribution,
    required this.systemTrend,
    required this.studentResults,
    required this.subjectPerformance,
    required this.classPerformance,
  });

  final String schoolName;
  final String districtName;
  final String headmasterName;
  final int totalTeachers;
  final int totalStudents;
  final int totalClasses;
  final double averageScore;
  final double averageInterExamScore;
  final double passRate;
  final Map<String, int> divisionDistribution;
  final List<ScorePoint> systemTrend;
  final List<StudentResultRecord> studentResults;
  final List<SubjectPerformanceSummary> subjectPerformance;
  final List<ClassPerformanceSummary> classPerformance;
}

@immutable
class SignUpDraft {
  const SignUpDraft({
    required this.name,
    required this.email,
    required this.role,
    required this.schoolName,
    required this.districtName,
    this.subject,
    this.assignedClass,
    this.subjects = const <String>[],
    this.assignedClasses = const <String>[],
  });

  final String name;
  final String email;
  final UserRole role;
  final String schoolName;
  final String districtName;
  final String? subject;
  final String? assignedClass;
  final List<String> subjects;
  final List<String> assignedClasses;
}

@immutable
class SchoolAdminState {
  const SchoolAdminState({
    required this.session,
    required this.schoolName,
    required this.districtName,
    required this.headmasterName,
    required this.teachers,
    required this.resultWindow,
    required this.settings,
    required this.studentResults,
  });

  final SessionUser? session;
  final String schoolName;
  final String districtName;
  final String headmasterName;
  final List<TeacherAccount> teachers;
  final ResultWindowSettings resultWindow;
  final SchoolSettings settings;
  final List<StudentResultRecord> studentResults;

  SchoolAdminState copyWith({
    SessionUser? session,
    bool clearSession = false,
    String? schoolName,
    String? districtName,
    String? headmasterName,
    List<TeacherAccount>? teachers,
    ResultWindowSettings? resultWindow,
    SchoolSettings? settings,
    List<StudentResultRecord>? studentResults,
  }) {
    return SchoolAdminState(
      session: clearSession ? null : (session ?? this.session),
      schoolName: schoolName ?? this.schoolName,
      districtName: districtName ?? this.districtName,
      headmasterName: headmasterName ?? this.headmasterName,
      teachers: teachers ?? this.teachers,
      resultWindow: resultWindow ?? this.resultWindow,
      settings: settings ?? this.settings,
      studentResults: studentResults ?? this.studentResults,
    );
  }
}

List<double> _groupedExamAverages(List<ExamMark> marks) {
  if (marks.isEmpty) {
    return const <double>[];
  }

  final Map<String, List<ExamMark>> grouped = <String, List<ExamMark>>{};
  for (final ExamMark mark in marks) {
    final String key = mark.sessionKey ?? '${mark.type.name}:${mark.label}';
    grouped.putIfAbsent(key, () => <ExamMark>[]).add(mark);
  }

  return grouped.values
      .map((List<ExamMark> group) {
        final double total = group.fold<double>(
          0,
          (double sum, ExamMark mark) => sum + mark.score,
        );
        return double.parse((total / group.length).toStringAsFixed(1));
      })
      .toList(growable: false);
}
