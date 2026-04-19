import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/entities/school_records_entities.dart';
import '../../domain/services/necta_olevel_calculator.dart';
import 'student_management_providers.dart';

final StateNotifierProvider<SchoolRecordsController, SchoolRecordsState>
schoolRecordsProvider =
    StateNotifierProvider<SchoolRecordsController, SchoolRecordsState>(
      (Ref ref) => SchoolRecordsController(
        schoolName: ref.read(schoolAdminProvider).schoolName,
        districtName: ref.read(schoolAdminProvider).districtName,
        teachers: ref.read(schoolAdminProvider).teachers,
        currentResults: ref.read(schoolAdminProvider).studentResults,
      ),
    );

final Provider<HistoricalRecordsOverview> historicalRecordsOverviewProvider =
    Provider<HistoricalRecordsOverview>((Ref ref) {
      final SchoolRecordsState state = ref.watch(schoolRecordsProvider);
      final Set<String> years = state.examSessions
          .map((ExamSession session) => session.academicYear)
          .toSet();

      return HistoricalRecordsOverview(
        totalSessions: state.examSessions.length,
        totalHistoricalRecords: state.historicalRecords.length,
        totalImportBatches: state.importBatches.length,
        trackedAcademicYears: years.length,
        nationalSessions: state.examSessions
            .where((ExamSession session) => session.type == ExamSessionType.national)
            .length,
        mockSessions: state.examSessions
            .where((ExamSession session) => session.type == ExamSessionType.mock)
            .length,
        studentRegistryCount: state.studentMasterRecords.length,
      );
    });

final Provider<List<StudentPrediction>> studentPredictionsProvider =
    Provider<List<StudentPrediction>>((Ref ref) {
      final SchoolRecordsState records = ref.watch(schoolRecordsProvider);
      final List<StudentResultRecord> currentResults = ref
          .watch(schoolOverviewProvider)
          .studentResults;

      final List<StudentPrediction> predictions = currentResults.map((
        StudentResultRecord result,
      ) {
        final List<HistoricalExamRecord> matches = records.historicalRecords
            .where(
              (HistoricalExamRecord item) =>
                  item.admissionNumber == result.admissionNumber,
            )
            .toList()
          ..sort(
            (HistoricalExamRecord a, HistoricalExamRecord b) =>
                a.recordedAt.compareTo(b.recordedAt),
          );

        final double historicalAverage = matches.isEmpty
            ? result.averageScore - 3
            : _average(
                matches.map(
                  (HistoricalExamRecord item) => item.result.averageScore,
                ),
              );
        final double delta = result.averageScore - historicalAverage;
        final double predictedAverage = _clampScore(
          result.averageScore + delta * 0.55,
        );
        final List<SubjectResult> orderedSubjects = <SubjectResult>[
          ...result.subjectResults,
        ]..sort(
            (SubjectResult a, SubjectResult b) =>
                a.averageScore.compareTo(b.averageScore),
          );

        return StudentPrediction(
          studentId: result.id,
          studentName: result.studentName,
          className: result.className,
          currentAverage: result.averageScore,
          predictedAverage: predictedAverage,
          predictedDivision:
              NectaOLevelCalculator.projectedDivisionForAverage(
                predictedAverage,
              ),
          confidenceLabel: matches.length >= 2
              ? 'High confidence'
              : 'Moderate confidence',
          focusSubjects: orderedSubjects
              .take(2)
              .map((SubjectResult item) => item.subject)
              .toList(),
        );
      }).toList()
        ..sort(
          (StudentPrediction a, StudentPrediction b) =>
              b.predictedAverage.compareTo(a.predictedAverage),
        );

      return predictions;
    });

final Provider<List<TeacherProjection>> teacherProjectionsProvider =
    Provider<List<TeacherProjection>>((Ref ref) {
      final SchoolRecordsState records = ref.watch(schoolRecordsProvider);
      final SchoolAdminState admin = ref.watch(schoolAdminProvider);
      final List<StudentResultRecord> currentResults = ref
          .watch(schoolOverviewProvider)
          .studentResults;

      return admin.teachers.map((TeacherAccount teacher) {
        final List<StudentResultRecord> assignedStudents = currentResults
            .where(
              (StudentResultRecord result) =>
                  result.className == teacher.assignedClass,
            )
            .toList();

        final double currentAverage = assignedStudents.isEmpty
            ? 0
            : _average(
                assignedStudents.map(
                  (StudentResultRecord result) => result
                      .subjectResults
                      .firstWhere(
                        (SubjectResult subject) =>
                            subject.subject == teacher.subject,
                      )
                      .averageScore,
                ),
              );

        final List<HistoricalExamRecord> historicalMatches = records
            .historicalRecords
            .where(
              (HistoricalExamRecord record) =>
                  record.className == teacher.assignedClass,
            )
            .toList();

        final double historicalAverage = historicalMatches.isEmpty
            ? currentAverage - 2
            : _average(
                historicalMatches.map(
                  (HistoricalExamRecord record) => record.result
                      .subjectResults
                      .firstWhere(
                        (SubjectResult subject) =>
                            subject.subject == teacher.subject,
                      )
                      .averageScore,
                ),
              );

        final double projectedAverage = _clampScore(
          currentAverage + (currentAverage - historicalAverage) * 0.45,
        );

        return TeacherProjection(
          teacherId: teacher.id,
          teacherName: teacher.name,
          subject: teacher.subject,
          assignedClass: teacher.assignedClass,
          currentAverage: currentAverage,
          projectedAverage: projectedAverage,
          recommendation: projectedAverage < 55
              ? 'Reteach the weakest topic cluster and schedule short remedial cycles.'
              : projectedAverage < 65
              ? 'Push targeted practice in the middle band before the next exam window.'
              : 'Keep the momentum and share the stronger strategy across similar classes.',
        );
      }).toList()
        ..sort(
          (TeacherProjection a, TeacherProjection b) =>
              a.projectedAverage.compareTo(b.projectedAverage),
        );
    });

final Provider<List<RecommendationInsight>> recommendationInsightsProvider =
    Provider<List<RecommendationInsight>>((Ref ref) {
      final SchoolOverview overview = ref.watch(schoolOverviewProvider);
      final List<StudentPrediction> predictions = ref.watch(
        studentPredictionsProvider,
      );
      final List<TeacherProjection> teacherProjections = ref.watch(
        teacherProjectionsProvider,
      );

      final List<RecommendationInsight> recommendations =
          <RecommendationInsight>[
            if (predictions.isNotEmpty)
              RecommendationInsight(
                id: 'student-${predictions.last.studentId}',
                target: RecommendationTarget.student,
                targetName: predictions.last.studentName,
                priority: RecommendationPriority.high,
                title: 'Immediate learner support required',
                detail:
                    'Focus ${predictions.last.focusSubjects.join(' and ')} and keep weekly follow-up until the projected division improves.',
                metricLabel: 'Forecast',
                metricValue:
                    '${predictions.last.predictedAverage.toStringAsFixed(1)}%',
                route: '/results/${predictions.last.studentId}',
              ),
            if (teacherProjections.isNotEmpty)
              RecommendationInsight(
                id: 'teacher-${teacherProjections.first.teacherId}',
                target: RecommendationTarget.teacher,
                targetName: teacherProjections.first.teacherName,
                priority: RecommendationPriority.high,
                title: 'Teacher intervention board',
                detail: teacherProjections.first.recommendation,
                metricLabel: 'Projected subject average',
                metricValue:
                    '${teacherProjections.first.projectedAverage.toStringAsFixed(1)}%',
                route: '/analytics',
              ),
            RecommendationInsight(
              id: 'school-pass-rate',
              target: RecommendationTarget.school,
              targetName: overview.schoolName,
              priority: overview.passRate < 70
                  ? RecommendationPriority.high
                  : RecommendationPriority.medium,
              title: 'School-wide improvement next move',
              detail: overview.passRate < 70
                  ? 'Use the historical mock and internal records to build a recovery plan around weak classes before the next reporting cycle.'
                  : 'Use the historical archive to preserve the current momentum and identify departments ready for stretch targets.',
              metricLabel: 'Pass rate',
              metricValue: '${overview.passRate.toStringAsFixed(1)}%',
              route: '/records',
            ),
          ];

      return recommendations;
    });

class SchoolRecordsController extends StateNotifier<SchoolRecordsState> {
  SchoolRecordsController({
    required String schoolName,
    required String districtName,
    required List<TeacherAccount> teachers,
    required List<StudentResultRecord> currentResults,
  })
    : super(
        SchoolRecordsState(
          examSessions: _seedExamSessions(),
          historicalRecords: const <HistoricalExamRecord>[],
          importBatches: const <HistoricalImportBatch>[],
          studentMasterRecords: _seedStudentRegistry(currentResults),
          schoolProfile: _seedSchoolProfile(
            schoolName: schoolName,
            districtName: districtName,
          ),
          teacherBiographies: _seedTeacherBiographies(teachers),
        ),
      ) {
    final List<HistoricalExamRecord> records = _seedHistoricalRecords(
      state.examSessions,
      currentResults,
    );
    state = state.copyWith(
      historicalRecords: records,
      importBatches: _seedImportBatches(state.examSessions, records),
      examSessions: state.examSessions.map((ExamSession session) {
        return session.copyWith(
          recordsCount: records
              .where(
                (HistoricalExamRecord item) => item.examSessionId == session.id,
              )
              .length,
        );
      }).toList(),
    );
  }

  void createExamSession({
    required String name,
    required String academicYear,
    required String termLabel,
    required ExamSessionType type,
    required String scopeLabel,
    required List<String> targetClasses,
    required String notes,
  }) {
    final int nextIndex = state.examSessions.length + 1;
    final ExamSession session = ExamSession(
      id: 'session-created-$nextIndex',
      name: name,
      academicYear: academicYear,
      termLabel: termLabel,
      type: type,
      scopeLabel: scopeLabel,
      targetClasses: targetClasses,
      scheduledDate: DateTime.now(),
      locked: false,
      recordsCount: 0,
      notes: notes,
    );

    state = state.copyWith(
      examSessions: <ExamSession>[session, ...state.examSessions],
    );
  }

  void importHistoricalRecords({
    required ExamSession session,
    required String fileName,
    required String note,
    required int warningCount,
    required List<StudentResultRecord> results,
  }) {
    final int nextIndex = state.importBatches.length + 1;
    final String batchId = 'batch-managed-$nextIndex';
    final DateTime importedAt = DateTime.now();

    final List<HistoricalExamRecord> importedRecords =
        results.asMap().entries.map((MapEntry<int, StudentResultRecord> entry) {
          final StudentResultRecord result = entry.value;
          return HistoricalExamRecord(
            id: 'historical-${session.id}-${state.historicalRecords.length + entry.key + 1}',
            examSessionId: session.id,
            importBatchId: batchId,
            examName: session.name,
            academicYear: session.academicYear,
            termLabel: session.termLabel,
            studentId: result.id,
            admissionNumber: result.admissionNumber,
            studentName: result.studentName,
            className: result.className,
            recordedAt: importedAt,
            result: result,
          );
        }).toList();

    final HistoricalImportBatch batch = HistoricalImportBatch(
      id: batchId,
      sessionId: session.id,
      sessionName: session.name,
      fileName: fileName,
      academicYear: session.academicYear,
      termLabel: session.termLabel,
      examType: session.type,
      importedAt: importedAt,
      recordCount: importedRecords.length,
      warningCount: warningCount,
      status: warningCount == 0
          ? ImportBatchStatus.imported
          : ImportBatchStatus.validated,
      note: note,
    );

    final List<StudentMasterRecord> updatedRegistry =
        _mergeRegistryFromHistoricalRecords(
          registry: state.studentMasterRecords,
          records: importedRecords,
        );

    state = state.copyWith(
      historicalRecords: <HistoricalExamRecord>[
        ...importedRecords,
        ...state.historicalRecords,
      ],
      importBatches: <HistoricalImportBatch>[batch, ...state.importBatches],
      studentMasterRecords: updatedRegistry,
      examSessions: state.examSessions.map((ExamSession current) {
        if (current.id != session.id) {
          return current;
        }
        return current.copyWith(
          recordsCount: current.recordsCount + importedRecords.length,
        );
      }).toList(),
    );
  }

  void saveStudentMasterRecord(StudentMasterRecord record) {
    bool updated = false;
    final List<StudentMasterRecord> registry = state.studentMasterRecords.map((
      StudentMasterRecord current,
    ) {
      if (current.admissionNumber != record.admissionNumber) {
        return current;
      }
      updated = true;
      return record;
    }).toList();

    state = state.copyWith(
      studentMasterRecords: updated
          ? registry
          : <StudentMasterRecord>[record, ...state.studentMasterRecords],
    );
  }

  void saveSchoolProfile(SchoolProfile profile) {
    state = state.copyWith(schoolProfile: profile);
  }

  void saveTeacherBiography(TeacherBiography biography) {
    bool updated = false;
    final List<TeacherBiography> biographies = state.teacherBiographies.map((
      TeacherBiography current,
    ) {
      if (current.id != biography.id) {
        return current;
      }
      updated = true;
      return biography;
    }).toList();

    state = state.copyWith(
      teacherBiographies: updated
          ? biographies
          : <TeacherBiography>[biography, ...state.teacherBiographies],
    );
  }
}

class SchoolRecordsState {
  const SchoolRecordsState({
    required this.examSessions,
    required this.historicalRecords,
    required this.importBatches,
    required this.studentMasterRecords,
    required this.schoolProfile,
    required this.teacherBiographies,
  });

  final List<ExamSession> examSessions;
  final List<HistoricalExamRecord> historicalRecords;
  final List<HistoricalImportBatch> importBatches;
  final List<StudentMasterRecord> studentMasterRecords;
  final SchoolProfile schoolProfile;
  final List<TeacherBiography> teacherBiographies;

  SchoolRecordsState copyWith({
    List<ExamSession>? examSessions,
    List<HistoricalExamRecord>? historicalRecords,
    List<HistoricalImportBatch>? importBatches,
    List<StudentMasterRecord>? studentMasterRecords,
    SchoolProfile? schoolProfile,
    List<TeacherBiography>? teacherBiographies,
  }) {
    return SchoolRecordsState(
      examSessions: examSessions ?? this.examSessions,
      historicalRecords: historicalRecords ?? this.historicalRecords,
      importBatches: importBatches ?? this.importBatches,
      studentMasterRecords: studentMasterRecords ?? this.studentMasterRecords,
      schoolProfile: schoolProfile ?? this.schoolProfile,
      teacherBiographies: teacherBiographies ?? this.teacherBiographies,
    );
  }
}

List<ExamSession> _seedExamSessions() {
  return const <ExamSession>[];
}

List<StudentMasterRecord> _seedStudentRegistry(
  List<StudentResultRecord> currentResults,
) {
  return currentResults.map((StudentResultRecord result) {
    return StudentMasterRecord(
      id: 'registry-${result.id}',
      admissionNumber: result.admissionNumber,
      fullName: result.studentName,
      formLevel: result.className.split(' ').take(2).join(' '),
      className: result.className,
      guardianName: '',
      guardianPhone: '',
      gender: StudentGender.female,
      dateOfBirth: DateTime(2009, 1, 1),
      admissionDate: DateTime.now(),
      status: StudentStatus.active,
      subjectCombination: result.subjectResults
          .map((SubjectResult subject) => subject.subject)
          .toList(),
      notes: '',
      latestAverage: result.averageScore,
      latestDivision: result.division,
      riskLevel: result.riskLevel,
    );
  }).toList();
}

SchoolProfile _seedSchoolProfile({
  required String schoolName,
  required String districtName,
}) {
  return SchoolProfile(
    schoolName: schoolName,
    districtName: districtName,
    tagline: '',
    about: '',
    mission: '',
    vision: '',
    logoUrl: '',
    heroImageUrl: '',
    introVideoUrl: '',
    galleryImageUrls: const <String>[],
    galleryVideoUrls: const <String>[],
  );
}

List<TeacherBiography> _seedTeacherBiographies(List<TeacherAccount> teachers) {
  return teachers.map((TeacherAccount teacher) {
    return TeacherBiography(
      id: teacher.id,
      name: teacher.name,
      subject: teacher.subject,
      assignedClass: teacher.assignedClass,
      roleTitle: '${teacher.subject} Teacher',
      biography: '',
      qualifications: '',
      yearsOfService: 0,
      photoUrl: '',
      introVideoUrl: '',
      galleryImageUrls: const <String>[],
      galleryVideoUrls: const <String>[],
    );
  }).toList();
}

List<HistoricalExamRecord> _seedHistoricalRecords(
  List<ExamSession> sessions,
  List<StudentResultRecord> currentResults,
) {
  return const <HistoricalExamRecord>[];
}

List<HistoricalImportBatch> _seedImportBatches(
  List<ExamSession> sessions,
  List<HistoricalExamRecord> records,
) {
  return const <HistoricalImportBatch>[];
}

List<StudentMasterRecord> _mergeRegistryFromHistoricalRecords({
  required List<StudentMasterRecord> registry,
  required List<HistoricalExamRecord> records,
}) {
  final Map<String, StudentMasterRecord> merged = <String, StudentMasterRecord>{
    for (final StudentMasterRecord item in registry) item.admissionNumber: item,
  };

  for (final HistoricalExamRecord record in records) {
    final StudentMasterRecord? current = merged[record.admissionNumber];
    if (current != null) {
      merged[record.admissionNumber] = current.copyWith(
        className: record.className,
        formLevel: record.className.split(' ').take(2).join(' '),
        latestAverage: record.result.averageScore,
        latestDivision: record.result.division,
        riskLevel: record.result.riskLevel,
      );
      continue;
    }

    merged[record.admissionNumber] = StudentMasterRecord(
      id: 'registry-${record.studentId}',
      admissionNumber: record.admissionNumber,
      fullName: record.studentName,
      formLevel: record.className.split(' ').take(2).join(' '),
      className: record.className,
      guardianName: 'Imported guardian',
      guardianPhone: 'Pending update',
      gender: StudentGender.female,
      dateOfBirth: DateTime(2009, 1, 1),
      admissionDate: DateTime.now(),
      status: StudentStatus.active,
      subjectCombination: record.result.subjectResults
          .map((SubjectResult item) => item.subject)
          .toList(),
      notes: 'Imported from historical archive batch.',
      latestAverage: record.result.averageScore,
      latestDivision: record.result.division,
      riskLevel: record.result.riskLevel,
    );
  }

  return merged.values.toList()
    ..sort(
      (StudentMasterRecord a, StudentMasterRecord b) =>
          a.fullName.compareTo(b.fullName),
    );
}

double _average(Iterable<double> values) {
  final List<double> list = values.toList();
  if (list.isEmpty) {
    return 0;
  }
  final double total = list.fold<double>(0, (double sum, double item) => sum + item);
  return double.parse((total / list.length).toStringAsFixed(1));
}

double _clampScore(double value) {
  return value.clamp(0, 100).toDouble();
}
