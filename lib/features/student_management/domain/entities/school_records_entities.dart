import 'package:flutter/foundation.dart';

import 'education_entities.dart';

enum ExamSessionType { monthly, midterm, terminal, mock, national, custom }

enum ImportBatchStatus { staged, validated, imported }

enum StudentGender { female, male }

enum StudentStatus { active, transferred, graduated, alumni }

enum RecommendationTarget { student, teacher, schoolClass, school }

enum RecommendationPriority { high, medium, monitor }

extension ExamSessionTypeX on ExamSessionType {
  String get label {
    switch (this) {
      case ExamSessionType.monthly:
        return 'Monthly Exam';
      case ExamSessionType.midterm:
        return 'Midterm';
      case ExamSessionType.terminal:
        return 'Terminal Exam';
      case ExamSessionType.mock:
        return 'Mock Exam';
      case ExamSessionType.national:
        return 'National Exam';
      case ExamSessionType.custom:
        return 'Custom Session';
    }
  }
}

extension ImportBatchStatusX on ImportBatchStatus {
  String get label {
    switch (this) {
      case ImportBatchStatus.staged:
        return 'Staged';
      case ImportBatchStatus.validated:
        return 'Validated';
      case ImportBatchStatus.imported:
        return 'Imported';
    }
  }
}

extension StudentGenderX on StudentGender {
  String get label {
    switch (this) {
      case StudentGender.female:
        return 'Female';
      case StudentGender.male:
        return 'Male';
    }
  }
}

extension StudentStatusX on StudentStatus {
  String get label {
    switch (this) {
      case StudentStatus.active:
        return 'Active';
      case StudentStatus.transferred:
        return 'Transferred';
      case StudentStatus.graduated:
        return 'Graduated';
      case StudentStatus.alumni:
        return 'Alumni';
    }
  }
}

extension RecommendationTargetX on RecommendationTarget {
  String get label {
    switch (this) {
      case RecommendationTarget.student:
        return 'Student';
      case RecommendationTarget.teacher:
        return 'Teacher';
      case RecommendationTarget.schoolClass:
        return 'Class';
      case RecommendationTarget.school:
        return 'School';
    }
  }
}

extension RecommendationPriorityX on RecommendationPriority {
  String get label {
    switch (this) {
      case RecommendationPriority.high:
        return 'High priority';
      case RecommendationPriority.medium:
        return 'Action this term';
      case RecommendationPriority.monitor:
        return 'Monitor';
    }
  }
}

@immutable
class ExamSession {
  const ExamSession({
    required this.id,
    required this.name,
    required this.academicYear,
    required this.termLabel,
    required this.type,
    required this.scopeLabel,
    required this.targetClasses,
    required this.scheduledDate,
    required this.locked,
    required this.recordsCount,
    required this.notes,
  });

  final String id;
  final String name;
  final String academicYear;
  final String termLabel;
  final ExamSessionType type;
  final String scopeLabel;
  final List<String> targetClasses;
  final DateTime scheduledDate;
  final bool locked;
  final int recordsCount;
  final String notes;

  ExamSession copyWith({
    String? id,
    String? name,
    String? academicYear,
    String? termLabel,
    ExamSessionType? type,
    String? scopeLabel,
    List<String>? targetClasses,
    DateTime? scheduledDate,
    bool? locked,
    int? recordsCount,
    String? notes,
  }) {
    return ExamSession(
      id: id ?? this.id,
      name: name ?? this.name,
      academicYear: academicYear ?? this.academicYear,
      termLabel: termLabel ?? this.termLabel,
      type: type ?? this.type,
      scopeLabel: scopeLabel ?? this.scopeLabel,
      targetClasses: targetClasses ?? this.targetClasses,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      locked: locked ?? this.locked,
      recordsCount: recordsCount ?? this.recordsCount,
      notes: notes ?? this.notes,
    );
  }
}

@immutable
class HistoricalExamRecord {
  const HistoricalExamRecord({
    required this.id,
    required this.examSessionId,
    required this.importBatchId,
    required this.examName,
    required this.academicYear,
    required this.termLabel,
    required this.studentId,
    required this.admissionNumber,
    required this.studentName,
    required this.className,
    required this.recordedAt,
    required this.result,
  });

  final String id;
  final String examSessionId;
  final String importBatchId;
  final String examName;
  final String academicYear;
  final String termLabel;
  final String studentId;
  final String admissionNumber;
  final String studentName;
  final String className;
  final DateTime recordedAt;
  final StudentResultRecord result;
}

@immutable
class HistoricalImportBatch {
  const HistoricalImportBatch({
    required this.id,
    required this.sessionId,
    required this.sessionName,
    required this.fileName,
    required this.academicYear,
    required this.termLabel,
    required this.examType,
    required this.importedAt,
    required this.recordCount,
    required this.warningCount,
    required this.status,
    required this.note,
  });

  final String id;
  final String sessionId;
  final String sessionName;
  final String fileName;
  final String academicYear;
  final String termLabel;
  final ExamSessionType examType;
  final DateTime importedAt;
  final int recordCount;
  final int warningCount;
  final ImportBatchStatus status;
  final String note;
}

@immutable
class StudentMasterRecord {
  const StudentMasterRecord({
    required this.id,
    required this.admissionNumber,
    required this.fullName,
    required this.formLevel,
    required this.className,
    required this.guardianName,
    required this.guardianPhone,
    required this.gender,
    required this.dateOfBirth,
    required this.admissionDate,
    required this.status,
    required this.subjectCombination,
    required this.notes,
    required this.latestAverage,
    required this.latestDivision,
    required this.riskLevel,
  });

  final String id;
  final String admissionNumber;
  final String fullName;
  final String formLevel;
  final String className;
  final String guardianName;
  final String guardianPhone;
  final StudentGender gender;
  final DateTime dateOfBirth;
  final DateTime admissionDate;
  final StudentStatus status;
  final List<String> subjectCombination;
  final String notes;
  final double latestAverage;
  final String latestDivision;
  final RiskLevel riskLevel;

  StudentMasterRecord copyWith({
    String? id,
    String? admissionNumber,
    String? fullName,
    String? formLevel,
    String? className,
    String? guardianName,
    String? guardianPhone,
    StudentGender? gender,
    DateTime? dateOfBirth,
    DateTime? admissionDate,
    StudentStatus? status,
    List<String>? subjectCombination,
    String? notes,
    double? latestAverage,
    String? latestDivision,
    RiskLevel? riskLevel,
  }) {
    return StudentMasterRecord(
      id: id ?? this.id,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      fullName: fullName ?? this.fullName,
      formLevel: formLevel ?? this.formLevel,
      className: className ?? this.className,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      admissionDate: admissionDate ?? this.admissionDate,
      status: status ?? this.status,
      subjectCombination: subjectCombination ?? this.subjectCombination,
      notes: notes ?? this.notes,
      latestAverage: latestAverage ?? this.latestAverage,
      latestDivision: latestDivision ?? this.latestDivision,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }
}

@immutable
class RecommendationInsight {
  const RecommendationInsight({
    required this.id,
    required this.target,
    required this.targetName,
    required this.priority,
    required this.title,
    required this.detail,
    required this.metricLabel,
    required this.metricValue,
    required this.route,
  });

  final String id;
  final RecommendationTarget target;
  final String targetName;
  final RecommendationPriority priority;
  final String title;
  final String detail;
  final String metricLabel;
  final String metricValue;
  final String route;
}

@immutable
class StudentPrediction {
  const StudentPrediction({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.currentAverage,
    required this.predictedAverage,
    required this.predictedDivision,
    required this.confidenceLabel,
    required this.focusSubjects,
  });

  final String studentId;
  final String studentName;
  final String className;
  final double currentAverage;
  final double predictedAverage;
  final String predictedDivision;
  final String confidenceLabel;
  final List<String> focusSubjects;
}

@immutable
class TeacherProjection {
  const TeacherProjection({
    required this.teacherId,
    required this.teacherName,
    required this.subject,
    required this.assignedClass,
    required this.currentAverage,
    required this.projectedAverage,
    required this.recommendation,
  });

  final String teacherId;
  final String teacherName;
  final String subject;
  final String assignedClass;
  final double currentAverage;
  final double projectedAverage;
  final String recommendation;
}

@immutable
class HistoricalRecordsOverview {
  const HistoricalRecordsOverview({
    required this.totalSessions,
    required this.totalHistoricalRecords,
    required this.totalImportBatches,
    required this.trackedAcademicYears,
    required this.nationalSessions,
    required this.mockSessions,
    required this.studentRegistryCount,
  });

  final int totalSessions;
  final int totalHistoricalRecords;
  final int totalImportBatches;
  final int trackedAcademicYears;
  final int nationalSessions;
  final int mockSessions;
  final int studentRegistryCount;
}

@immutable
class SchoolProfile {
  const SchoolProfile({
    required this.schoolName,
    required this.districtName,
    required this.tagline,
    required this.about,
    required this.mission,
    required this.vision,
    required this.logoUrl,
    required this.heroImageUrl,
    required this.introVideoUrl,
    required this.galleryImageUrls,
    required this.galleryVideoUrls,
  });

  final String schoolName;
  final String districtName;
  final String tagline;
  final String about;
  final String mission;
  final String vision;
  final String logoUrl;
  final String heroImageUrl;
  final String introVideoUrl;
  final List<String> galleryImageUrls;
  final List<String> galleryVideoUrls;

  SchoolProfile copyWith({
    String? schoolName,
    String? districtName,
    String? tagline,
    String? about,
    String? mission,
    String? vision,
    String? logoUrl,
    String? heroImageUrl,
    String? introVideoUrl,
    List<String>? galleryImageUrls,
    List<String>? galleryVideoUrls,
  }) {
    return SchoolProfile(
      schoolName: schoolName ?? this.schoolName,
      districtName: districtName ?? this.districtName,
      tagline: tagline ?? this.tagline,
      about: about ?? this.about,
      mission: mission ?? this.mission,
      vision: vision ?? this.vision,
      logoUrl: logoUrl ?? this.logoUrl,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      introVideoUrl: introVideoUrl ?? this.introVideoUrl,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      galleryVideoUrls: galleryVideoUrls ?? this.galleryVideoUrls,
    );
  }
}

@immutable
class TeacherBiography {
  const TeacherBiography({
    required this.id,
    required this.name,
    required this.subject,
    required this.assignedClass,
    required this.roleTitle,
    required this.biography,
    required this.qualifications,
    required this.yearsOfService,
    required this.photoUrl,
    required this.introVideoUrl,
    required this.galleryImageUrls,
    required this.galleryVideoUrls,
  });

  final String id;
  final String name;
  final String subject;
  final String assignedClass;
  final String roleTitle;
  final String biography;
  final String qualifications;
  final int yearsOfService;
  final String photoUrl;
  final String introVideoUrl;
  final List<String> galleryImageUrls;
  final List<String> galleryVideoUrls;

  TeacherBiography copyWith({
    String? id,
    String? name,
    String? subject,
    String? assignedClass,
    String? roleTitle,
    String? biography,
    String? qualifications,
    int? yearsOfService,
    String? photoUrl,
    String? introVideoUrl,
    List<String>? galleryImageUrls,
    List<String>? galleryVideoUrls,
  }) {
    return TeacherBiography(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      assignedClass: assignedClass ?? this.assignedClass,
      roleTitle: roleTitle ?? this.roleTitle,
      biography: biography ?? this.biography,
      qualifications: qualifications ?? this.qualifications,
      yearsOfService: yearsOfService ?? this.yearsOfService,
      photoUrl: photoUrl ?? this.photoUrl,
      introVideoUrl: introVideoUrl ?? this.introVideoUrl,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      galleryVideoUrls: galleryVideoUrls ?? this.galleryVideoUrls,
    );
  }
}
