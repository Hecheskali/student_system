import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/supabase/supabase_bootstrap.dart';
import '../../data/repositories/supabase_student_management_repository.dart';
import '../../data/services/supabase_school_admin_store.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/entities/education_entities.dart';
import '../../domain/repositories/student_management_repository.dart';
import '../../domain/services/necta_olevel_calculator.dart';
import '../../domain/services/necta_olevel_subjects.dart';

final Provider<StudentManagementRepository>
studentManagementRepositoryProvider = Provider<StudentManagementRepository>((
  Ref ref,
) {
  return SupabaseStudentManagementRepository(client: SupabaseBootstrap.client);
});

final FutureProvider<List<District>> districtsProvider =
    FutureProvider<List<District>>((Ref ref) {
      return ref.watch(studentManagementRepositoryProvider).getDistricts();
    });

final schoolsProvider = FutureProvider.family<List<School>, String>((
  Ref ref,
  String districtId,
) {
  return ref.watch(studentManagementRepositoryProvider).getSchools(districtId);
});

final classesProvider = FutureProvider.family<List<SchoolClass>, String>((
  Ref ref,
  String schoolId,
) {
  return ref.watch(studentManagementRepositoryProvider).getClasses(schoolId);
});

final studentsProvider = FutureProvider.family<List<Student>, String>((
  Ref ref,
  String classId,
) {
  return ref.watch(studentManagementRepositoryProvider).getStudents(classId);
});

final studentProvider = FutureProvider.family<Student?, String>((
  Ref ref,
  String studentId,
) {
  return ref.watch(studentManagementRepositoryProvider).getStudent(studentId);
});

final FutureProvider<DashboardSummary> dashboardSummaryProvider =
    FutureProvider<DashboardSummary>((Ref ref) {
      return ref
          .watch(studentManagementRepositoryProvider)
          .getDashboardSummary();
    });

final scopeSummaryProvider = FutureProvider.family<ScopeSummary, ScopeRequest>((
  Ref ref,
  ScopeRequest request,
) {
  return ref
      .watch(studentManagementRepositoryProvider)
      .getScopeSummary(request);
});

final Provider<SupabaseService?> supabaseServiceProvider =
    Provider<SupabaseService?>((Ref ref) {
      final client = SupabaseBootstrap.client;
      if (client == null) {
        return null;
      }
      return SupabaseService(client: client);
    });

final Provider<SupabaseSchoolAdminStore?> supabaseSchoolAdminStoreProvider =
    Provider<SupabaseSchoolAdminStore?>((Ref ref) {
      final SupabaseService? service = ref.watch(supabaseServiceProvider);
      if (service == null) {
        return null;
      }
      return SupabaseSchoolAdminStore(service);
    });

final StateNotifierProvider<SchoolAdminController, SchoolAdminState>
schoolAdminProvider =
    StateNotifierProvider<SchoolAdminController, SchoolAdminState>(
      (Ref ref) => SchoolAdminController(
        store: ref.watch(supabaseSchoolAdminStoreProvider),
      ),
    );

final Provider<SchoolOverview> schoolOverviewProvider =
    Provider<SchoolOverview>((Ref ref) {
      return _buildOverview(ref.watch(schoolAdminProvider));
    });

final Provider<TeacherAccount?> currentTeacherProvider =
    Provider<TeacherAccount?>((Ref ref) {
      final SchoolAdminState state = ref.watch(schoolAdminProvider);
      final SessionUser? session = state.session;
      if (session == null || session.role != UserRole.teacher) {
        return null;
      }

      for (final TeacherAccount teacher in state.teachers) {
        if (teacher.id == session.id) {
          return teacher;
        }
      }

      return null;
    });

final studentResultProvider = Provider.family<StudentResultRecord?, String>((
  Ref ref,
  String studentId,
) {
  final List<StudentResultRecord> results = ref
      .watch(schoolAdminProvider)
      .studentResults;

  for (final StudentResultRecord record in results) {
    if (record.id == studentId) {
      return record;
    }
  }

  return null;
});

final searchResultsProvider = Provider.family<List<SearchResultItem>, String>((
  Ref ref,
  String query,
) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return const <SearchResultItem>[];
  }

  return _buildSearchIndex(
    state: ref.watch(schoolAdminProvider),
    overview: ref.watch(schoolOverviewProvider),
  ).where((SearchResultItem item) {
    final String haystack = '${item.title} ${item.subtitle} ${item.type.label}'
        .toLowerCase();
    return haystack.contains(normalized);
  }).toList();
});

class SchoolAdminController extends StateNotifier<SchoolAdminState> {
  SchoolAdminController({SupabaseSchoolAdminStore? store})
    : _store = store,
      super(_initialAdminState()) {
    if (_store != null) {
      _hydrateFromSupabase();
    }
  }

  final SupabaseSchoolAdminStore? _store;

  bool get hasLiveBackend => _store != null;

  Future<void> _hydrateFromSupabase() async {
    if (_store == null) {
      return;
    }
    final SupabaseSchoolAdminStore store = _store;

    try {
      final SupabaseSchoolAdminLoadResult loaded = await store.load(
        fallbackState: state,
      );
      state = state.copyWith(
        session: loaded.session,
        schoolName: loaded.schoolName,
        districtName: loaded.districtName,
        headmasterName: loaded.headmasterName,
        teachers: loaded.teachers,
        resultWindow: loaded.resultWindow,
        settings: loaded.settings,
        studentResults: loaded.studentResults,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Supabase school data hydration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> refreshData() async {
    await _hydrateFromSupabase();
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_store == null) {
      throw StateError('Supabase is not configured for this app.');
    }
    final SupabaseSchoolAdminStore store = _store;

    final SessionUser? session = await store.signIn(
      email: email,
      password: password,
      fallbackSchoolName: state.schoolName,
      fallbackDistrictName: state.districtName,
    );

    // Immediately update state with the session from sign in
    if (session != null) {
      state = state.copyWith(session: session);
    }

    await _hydrateFromSupabase();

    if (session == null && state.session == null) {
      throw StateError('Login succeeded but no school profile was found.');
    }
  }

  void loginAs(UserRole role, {String? teacherId}) {
    if (role == UserRole.headOfSchool) {
      state = state.copyWith(
        session: SessionUser(
          id: 'headmaster-1',
          name: state.headmasterName,
          email: 'headmaster@summitview.edu',
          role: UserRole.headOfSchool,
          schoolName: state.schoolName,
          districtName: state.districtName,
        ),
      );
      return;
    }

    if (role == UserRole.academicMaster) {
      state = state.copyWith(
        session: SessionUser(
          id: 'academic-master-1',
          name: 'Academic Master',
          email: 'academic.master@summitview.edu',
          role: UserRole.academicMaster,
          schoolName: state.schoolName,
          districtName: state.districtName,
        ),
      );
      return;
    }

    if (state.teachers.isEmpty) {
      return;
    }

    final TeacherAccount teacher = state.teachers.firstWhere(
      (TeacherAccount account) => account.id == teacherId,
      orElse: () => state.teachers.first,
    );
    state = state.copyWith(
      session: SessionUser(
        id: teacher.id,
        name: teacher.name,
        email: teacher.email,
        role: UserRole.teacher,
        schoolName: state.schoolName,
        districtName: state.districtName,
        subject: teacher.subject,
        assignedClass: teacher.assignedClass,
        subjects: teacher.effectiveSubjects,
        assignedClasses: teacher.effectiveClasses,
      ),
    );
  }

  Future<void> registerUser(SignUpDraft draft, {String? password}) async {
    if (_store != null && password != null && password.trim().isNotEmpty) {
      final SupabaseSchoolAdminStore store = _store;
      final SupabaseSchoolAdminAuthResult auth = await store.registerUser(
        draft: draft,
        password: password.trim(),
        settings: state.settings,
        resultWindow: state.resultWindow,
      );
      await _hydrateFromSupabase();
      state = state.copyWith(
        session: auth.session,
        schoolName: draft.schoolName,
        districtName: draft.districtName,
        headmasterName: draft.role == UserRole.headOfSchool
            ? draft.name
            : state.headmasterName,
      );
      return;
    }

    if (draft.role == UserRole.teacher) {
      final List<String> teacherSubjects = _normalizedAssignments(
        draft.subjects,
        fallback: draft.subject,
        defaultValue: 'Basic Mathematics',
        maxItems: 2,
      );
      final List<String> teacherClasses = _normalizedAssignments(
        draft.assignedClasses,
        fallback: draft.assignedClass,
        defaultValue: 'Form 1 A',
      );
      final TeacherAccount teacher = TeacherAccount(
        id: 'teacher-${state.teachers.length + 1}',
        name: draft.name,
        email: draft.email,
        subject: teacherSubjects.first,
        assignedClass: teacherClasses.first,
        canUploadResults: true,
        canEditResults: true,
        subjects: teacherSubjects.skip(1).toList(growable: false),
        assignedClasses: teacherClasses.skip(1).toList(growable: false),
        canRegisterStudents: state.settings.allowTeacherStudentRegistration,
        canDownloadResults: state.settings.allowTeacherResultDownloads,
      );

      state = state.copyWith(
        schoolName: draft.schoolName,
        districtName: draft.districtName,
        teachers: <TeacherAccount>[...state.teachers, teacher],
        session: SessionUser(
          id: teacher.id,
          name: teacher.name,
          email: teacher.email,
          role: UserRole.teacher,
          schoolName: draft.schoolName,
          districtName: draft.districtName,
          subject: teacher.subject,
          assignedClass: teacher.assignedClass,
          subjects: teacher.effectiveSubjects,
          assignedClasses: teacher.effectiveClasses,
        ),
      );
      return;
    }

    if (draft.role == UserRole.academicMaster) {
      state = state.copyWith(
        schoolName: draft.schoolName,
        districtName: draft.districtName,
        session: SessionUser(
          id: 'academic-master-1',
          name: draft.name,
          email: draft.email,
          role: UserRole.academicMaster,
          schoolName: draft.schoolName,
          districtName: draft.districtName,
        ),
      );
      _persistSettings();
      return;
    }

    state = state.copyWith(
      schoolName: draft.schoolName,
      districtName: draft.districtName,
      headmasterName: draft.name,
      session: SessionUser(
        id: 'headmaster-1',
        name: draft.name,
        email: draft.email,
        role: UserRole.headOfSchool,
        schoolName: draft.schoolName,
        districtName: draft.districtName,
      ),
    );
    _persistSettings();
  }

  void logout() {
    state = state.copyWith(clearSession: true);
    if (_store != null) {
      final SupabaseSchoolAdminStore store = _store;
      unawaited(store.signOut());
    }
  }

  Future<void> addTeacher({
    required String name,
    required String email,
    required List<String> subjects,
    required List<String> assignedClasses,
  }) async {
    final List<String> normalizedSubjects = _normalizedAssignments(
      subjects,
      defaultValue: 'Basic Mathematics',
      maxItems: 2,
    );
    final List<String> normalizedClasses = _normalizedAssignments(
      assignedClasses,
      defaultValue: 'Form 1 A',
    );
    final TeacherAccount teacher = TeacherAccount(
      id: 'teacher-${state.teachers.length + 1}',
      name: name,
      email: email,
      subject: normalizedSubjects.first,
      assignedClass: normalizedClasses.first,
      canUploadResults: true,
      canEditResults: true,
      subjects: normalizedSubjects.skip(1).toList(growable: false),
      assignedClasses: normalizedClasses.skip(1).toList(growable: false),
      canRegisterStudents: state.settings.allowTeacherStudentRegistration,
      canDownloadResults: state.settings.allowTeacherResultDownloads,
    );

    if (_store == null) {
      state = state.copyWith(
        teachers: <TeacherAccount>[...state.teachers, teacher],
      );
      return;
    }
    final SupabaseSchoolAdminStore store = _store;

    try {
      final TeacherAccount savedTeacher = await store.saveTeacher(
        teacher: teacher,
        schoolName: state.schoolName,
        districtName: state.districtName,
      );
      state = state.copyWith(
        teachers: <TeacherAccount>[...state.teachers, savedTeacher],
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Saving teacher failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void removeTeacher(String teacherId) {
    state = state.copyWith(
      teachers: state.teachers
          .where((TeacherAccount teacher) => teacher.id != teacherId)
          .toList(),
    );

    if (state.session?.id == teacherId) {
      logout();
    }

    if (_store != null) {
      final SupabaseSchoolAdminStore store = _store;
      _persist(() => store.deleteTeacher(teacherId));
    }
  }

  void toggleTeacherUpload(String teacherId) {
    state = state.copyWith(
      teachers: state.teachers.map((TeacherAccount teacher) {
        if (teacher.id != teacherId) {
          return teacher;
        }

        return teacher.copyWith(canUploadResults: !teacher.canUploadResults);
      }).toList(),
    );
    _persistTeacherById(teacherId);
  }

  void toggleTeacherEdit(String teacherId) {
    state = state.copyWith(
      teachers: state.teachers.map((TeacherAccount teacher) {
        if (teacher.id != teacherId) {
          return teacher;
        }

        return teacher.copyWith(canEditResults: !teacher.canEditResults);
      }).toList(),
    );
    _persistTeacherById(teacherId);
  }

  void toggleTeacherRegistration(String teacherId) {
    state = state.copyWith(
      teachers: state.teachers.map((TeacherAccount teacher) {
        if (teacher.id != teacherId) {
          return teacher;
        }
        return teacher.copyWith(
          canRegisterStudents: !teacher.canRegisterStudents,
        );
      }).toList(),
    );
    _persistTeacherById(teacherId);
  }

  void toggleTeacherDownloads(String teacherId) {
    state = state.copyWith(
      teachers: state.teachers.map((TeacherAccount teacher) {
        if (teacher.id != teacherId) {
          return teacher;
        }
        return teacher.copyWith(
          canDownloadResults: !teacher.canDownloadResults,
        );
      }).toList(),
    );
    _persistTeacherById(teacherId);
  }

  void updateTeacherAssignments({
    required String teacherId,
    required List<String> subjects,
    required List<String> assignedClasses,
  }) {
    final List<String> normalizedSubjects = _normalizedAssignments(
      subjects,
      defaultValue: 'Basic Mathematics',
      maxItems: 2,
    );
    final List<String> normalizedClasses = _normalizedAssignments(
      assignedClasses,
      defaultValue: 'Form 1 A',
    );

    state = state.copyWith(
      teachers: state.teachers.map((TeacherAccount teacher) {
        if (teacher.id != teacherId) {
          return teacher;
        }
        return teacher.copyWith(
          subject: normalizedSubjects.first,
          subjects: normalizedSubjects.skip(1).toList(growable: false),
          assignedClass: normalizedClasses.first,
          assignedClasses: normalizedClasses.skip(1).toList(growable: false),
        );
      }).toList(),
    );

    final SessionUser? session = state.session;
    if (session != null &&
        session.role == UserRole.teacher &&
        session.id == teacherId) {
      loginAs(UserRole.teacher, teacherId: teacherId);
    }

    _persistTeacherById(teacherId);
  }

  void extendUploadDeadline(Duration duration) {
    state = state.copyWith(
      resultWindow: state.resultWindow.copyWith(
        uploadDeadline: state.resultWindow.uploadDeadline.add(duration),
      ),
    );
    _persistSettings();
  }

  void extendEditDeadline(Duration duration) {
    state = state.copyWith(
      resultWindow: state.resultWindow.copyWith(
        editDeadline: state.resultWindow.editDeadline.add(duration),
      ),
    );
    _persistSettings();
  }

  void setEditingLocked(bool locked) {
    state = state.copyWith(
      resultWindow: state.resultWindow.copyWith(editingLocked: locked),
    );
    _persistSettings();
  }

  void updateSettings(SchoolSettings settings) {
    state = state.copyWith(
      settings: settings,
      teachers: state.teachers.map((TeacherAccount teacher) {
        return teacher.copyWith(
          canRegisterStudents: settings.allowTeacherStudentRegistration
              ? teacher.canRegisterStudents
              : false,
          canDownloadResults: settings.allowTeacherResultDownloads
              ? teacher.canDownloadResults
              : false,
        );
      }).toList(),
    );
    _persistSettings();
  }

  void setTeacherStudentRegistrationEnabled(bool enabled) {
    updateSettings(
      state.settings.copyWith(allowTeacherStudentRegistration: enabled),
    );
  }

  void setTeacherResultDownloadsEnabled(bool enabled) {
    updateSettings(
      state.settings.copyWith(allowTeacherResultDownloads: enabled),
    );
  }

  void setTeacherSubjectIsolation(bool enabled) {
    updateSettings(
      state.settings.copyWith(enforceTeacherSubjectIsolation: enabled),
    );
  }

  void setAutoZeroPracticals(bool enabled) {
    updateSettings(state.settings.copyWith(autoZeroMissingPracticals: enabled));
  }

  void setCombinedResultsVisibilityForTeachers(bool enabled) {
    updateSettings(
      state.settings.copyWith(showCombinedResultsToTeachers: enabled),
    );
  }

  void setAcademicCycle({
    required String academicYear,
    required String termLabel,
  }) {
    updateSettings(
      state.settings.copyWith(
        currentAcademicYear: academicYear,
        currentTermLabel: termLabel,
      ),
    );
  }

  Future<void> addStudent({
    required String studentName,
    required String className,
    List<String> subjects = const <String>[],
    String? admissionNumber,
    double? attendanceRate,
  }) async {
    final int nextIndex = state.studentResults.length + 1;
    final List<SubjectResult> subjectResults = _buildDefaultSubjects(
      nextIndex,
      selectedSubjects: subjects,
    );
    StudentResultRecord record = _composeStudentRecord(
      id: 'managed-student-$nextIndex',
      admissionNumber: admissionNumber?.trim().isNotEmpty == true
          ? admissionNumber!.trim()
          : 'SVC-${nextIndex.toString().padLeft(3, '0')}',
      studentName: studentName,
      className: className,
      attendanceRate:
          (attendanceRate ?? (90 + (nextIndex % 6).toDouble())).clamp(0, 100)
              as double,
      subjectResults: subjectResults,
      performanceTrend: <ScorePoint>[
        const ScorePoint(label: 'Term 1', value: 48),
        const ScorePoint(label: 'Inter', value: 54),
        const ScorePoint(label: 'Term 2', value: 58),
        const ScorePoint(label: 'Current', value: 62),
      ],
    );

    if (_store != null) {
      final SupabaseSchoolAdminStore store = _store;
      try {
        record = await store.saveStudentRecord(
          record: record,
          schoolName: state.schoolName,
          districtName: state.districtName,
        );
      } on Object catch (error, stackTrace) {
        debugPrint('Saving student failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        rethrow;
      }
    }

    state = state.copyWith(
      studentResults: <StudentResultRecord>[...state.studentResults, record],
    );
  }

  void uploadScores({
    required String studentId,
    required String subject,
    required List<ExamMark> examMarks,
  }) {
    final DateTime now = DateTime.now();
    StudentResultRecord? updatedRecord;
    final List<StudentResultRecord> nextResults = state.studentResults
        .map((StudentResultRecord record) {
          if (record.id != studentId) {
            return record;
          }

          final List<SubjectResult> updatedSubjects = record.subjectResults.map(
            (SubjectResult current) {
              if (current.subject != subject) {
                return current;
              }

              final List<ExamMark> uploadedMarks = examMarks.map((
                ExamMark mark,
              ) {
                return mark.copyWith(
                  examDate: mark.examDate ?? now,
                  uploadedAt: mark.uploadedAt ?? now,
                );
              }).toList();

              return _buildSubjectResult(
                subject: current.subject,
                examMarks: <ExamMark>[...current.examMarks, ...uploadedMarks],
                isCoreSubject: current.isCoreSubject,
              );
            },
          ).toList();

          final double nextAverage = _average(
            updatedSubjects.map((SubjectResult item) => item.averageScore),
          );

          final List<ScorePoint> updatedTrend = <ScorePoint>[
            ...record.performanceTrend.take(record.performanceTrend.length - 1),
            ScorePoint(
              label: 'Current',
              value: double.parse(nextAverage.toStringAsFixed(1)),
            ),
          ];

          updatedRecord = _composeStudentRecord(
            id: record.id,
            admissionNumber: record.admissionNumber,
            studentName: record.studentName,
            className: record.className,
            attendanceRate: record.attendanceRate,
            subjectResults: updatedSubjects,
            performanceTrend: updatedTrend,
          );
          return updatedRecord!;
        })
        .toList(growable: false);

    state = state.copyWith(studentResults: nextResults);
    if (updatedRecord != null) {
      _persistStudentRecord(updatedRecord!);
    }
  }

  void saveSubjectScoreSheet({
    required String teacherId,
    required String teacherName,
    required String className,
    required String subject,
    required String examLabel,
    required ExamType examType,
    required DateTime examDate,
    required Map<String, double> theoryScores,
    Map<String, double>? practicalScores,
  }) {
    final TeacherAccount? teacher = _teacherById(state.teachers, teacherId);
    if (teacher == null) {
      return;
    }

    final bool canUpload =
        teacher.canUploadResults &&
        !state.resultWindow.editingLocked &&
        (!state.settings.enforceTeacherSubjectIsolation ||
            teacher.teachesSubject(subject));
    if (!canUpload) {
      return;
    }

    final bool usesPracticals = _subjectUsesPracticals(
      className: className,
      subject: subject,
    );
    final DateTime uploadedAt = DateTime.now();
    final String sessionKey =
        '${subject.toLowerCase()}-${examType.name}-${examLabel.toLowerCase().replaceAll(' ', '-')}-${examDate.toIso8601String().split('T').first}';

    final List<StudentResultRecord> updatedRecords = <StudentResultRecord>[];
    final List<StudentResultRecord> nextResults = state.studentResults
        .map((StudentResultRecord record) {
          if (record.className != className ||
              !theoryScores.containsKey(record.id) ||
              !record.subjectResults.any(
                (SubjectResult result) => result.subject == subject,
              )) {
            return record;
          }

          final double theory = (theoryScores[record.id] ?? 0).clamp(0, 100);
          final double? practical = usesPracticals
              ? (practicalScores?[record.id] ??
                    (state.settings.autoZeroMissingPracticals ? 0 : null))
              : null;
          if (usesPracticals && practical == null) {
            return record;
          }

          final List<SubjectResult> updatedSubjects = record.subjectResults.map(
            (SubjectResult current) {
              if (current.subject != subject) {
                return current;
              }

              final List<ExamMark> remainingMarks = current.examMarks.where((
                ExamMark mark,
              ) {
                return mark.sessionKey != sessionKey;
              }).toList();

              final List<ExamMark> nextMarks = <ExamMark>[
                ...remainingMarks,
                ExamMark(
                  id: '$sessionKey-theory',
                  label: examLabel,
                  type: examType,
                  score: theory,
                  component: usesPracticals
                      ? ExamComponent.theory
                      : ExamComponent.overall,
                  sessionKey: sessionKey,
                  teacherId: teacherId,
                  teacherName: teacherName,
                  examDate: examDate,
                  uploadedAt: uploadedAt,
                ),
                if (usesPracticals)
                  ExamMark(
                    id: '$sessionKey-practical',
                    label: examLabel,
                    type: examType,
                    score: practical!,
                    component: ExamComponent.practical,
                    sessionKey: sessionKey,
                    teacherId: teacherId,
                    teacherName: teacherName,
                    examDate: examDate,
                    uploadedAt: uploadedAt,
                  ),
              ];

              return _buildSubjectResult(
                subject: current.subject,
                examMarks: nextMarks,
                isCoreSubject: current.isCoreSubject,
              );
            },
          ).toList();

          final StudentResultRecord nextRecord = _recomposeRecord(
            record,
            updatedSubjects,
          );
          updatedRecords.add(nextRecord);
          return nextRecord;
        })
        .toList(growable: false);

    state = state.copyWith(studentResults: nextResults);
    _persistStudentRecords(updatedRecords);
  }

  void _persistTeacherById(String teacherId) {
    final TeacherAccount? teacher = _teacherById(state.teachers, teacherId);
    if (teacher == null || _store == null) {
      return;
    }
    final SupabaseSchoolAdminStore store = _store;

    _persist(() async {
      await store.saveTeacher(
        teacher: teacher,
        schoolName: state.schoolName,
        districtName: state.districtName,
      );
    });
  }

  void _persistSettings() {
    if (_store == null) {
      return;
    }
    final SupabaseSchoolAdminStore store = _store;

    _persist(() async {
      await store.saveSettings(
        schoolName: state.schoolName,
        districtName: state.districtName,
        headmasterName: state.headmasterName,
        resultWindow: state.resultWindow,
        settings: state.settings,
      );
    });
  }

  void _persistStudentRecord(StudentResultRecord record) {
    if (_store == null) {
      return;
    }
    final SupabaseSchoolAdminStore store = _store;

    _persist(() async {
      final StudentResultRecord saved = await store.saveStudentRecord(
        record: record,
        schoolName: state.schoolName,
        districtName: state.districtName,
      );
      state = state.copyWith(
        studentResults: state.studentResults
            .map((StudentResultRecord item) {
              return item.id == record.id ? saved : item;
            })
            .toList(growable: false),
      );
    });
  }

  void _persistStudentRecords(List<StudentResultRecord> records) {
    if (_store == null || records.isEmpty) {
      return;
    }
    final SupabaseSchoolAdminStore store = _store;

    _persist(() async {
      final List<StudentResultRecord> savedRecords = <StudentResultRecord>[];
      for (final StudentResultRecord record in records) {
        savedRecords.add(
          await store.saveStudentRecord(
            record: record,
            schoolName: state.schoolName,
            districtName: state.districtName,
          ),
        );
      }

      state = state.copyWith(
        studentResults: state.studentResults
            .map((StudentResultRecord item) {
              for (final StudentResultRecord saved in savedRecords) {
                if (saved.id == item.id ||
                    item.admissionNumber == saved.admissionNumber) {
                  return saved;
                }
              }
              return item;
            })
            .toList(growable: false),
      );
    });
  }

  void _persist(Future<void> Function() task) {
    unawaited(() async {
      try {
        await task();
      } on Object catch (error, stackTrace) {
        debugPrint('Supabase persistence failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }());
  }
}

SchoolOverview _buildOverview(SchoolAdminState state) {
  final List<StudentResultRecord> results =
      <StudentResultRecord>[...state.studentResults]..sort(
        (StudentResultRecord a, StudentResultRecord b) =>
            b.averageScore.compareTo(a.averageScore),
      );

  final Map<String, int> divisionDistribution = <String, int>{
    'Division I': 0,
    'Division II': 0,
    'Division III': 0,
    'Division IV': 0,
    'Division 0': 0,
  };

  for (final StudentResultRecord record in results) {
    divisionDistribution[record.division] =
        (divisionDistribution[record.division] ?? 0) + 1;
  }

  return SchoolOverview(
    schoolName: state.schoolName,
    districtName: state.districtName,
    headmasterName: state.headmasterName,
    totalTeachers: state.teachers.length,
    totalStudents: results.length,
    totalClasses: results
        .map((StudentResultRecord item) => item.className)
        .toSet()
        .length,
    averageScore: _average(
      results.map((StudentResultRecord item) => item.averageScore),
    ),
    averageInterExamScore: _average(
      results.map((StudentResultRecord item) => item.interExamAverage),
    ),
    passRate: results.isEmpty
        ? 0
        : results
                  .where(
                    (StudentResultRecord item) => item.division != 'Division 0',
                  )
                  .length /
              results.length *
              100,
    divisionDistribution: divisionDistribution,
    systemTrend: _buildSystemTrend(results),
    studentResults: results,
    subjectPerformance: _buildSubjectPerformance(results),
    classPerformance: _buildClassPerformance(results),
  );
}

List<SearchResultItem> _buildSearchIndex({
  required SchoolAdminState state,
  required SchoolOverview overview,
}) {
  final List<SearchResultItem> items = <SearchResultItem>[];

  for (final StudentResultRecord record in overview.studentResults) {
    items.add(
      SearchResultItem(
        id: record.id,
        type: SearchEntityType.student,
        title: record.studentName,
        subtitle:
            '${record.className} • ${record.division} • ${record.averageScore.toStringAsFixed(1)}%',
        route: '/results/${record.id}',
      ),
    );
    items.add(
      SearchResultItem(
        id: 'result-${record.id}',
        type: SearchEntityType.result,
        title: '${record.studentName} result sheet',
        subtitle:
            '${record.subjectResults.length} subjects • ${record.examsConducted} exams logged',
        route: '/results/${record.id}',
      ),
    );
  }

  for (final TeacherAccount teacher in state.teachers) {
    items.add(
      SearchResultItem(
        id: teacher.id,
        type: SearchEntityType.teacher,
        title: teacher.name,
        subtitle:
            '${teacher.effectiveSubjects.join(', ')} • ${teacher.effectiveClasses.join(', ')} • upload ${teacher.canUploadResults ? 'on' : 'off'}',
        route: '/dashboard',
      ),
    );
  }

  for (final SubjectPerformanceSummary subject in overview.subjectPerformance) {
    items.add(
      SearchResultItem(
        id: subject.subject,
        type: SearchEntityType.subject,
        title: subject.subject,
        subtitle:
            'Avg ${subject.averageScore.toStringAsFixed(1)}% • Pass ${subject.passRate.toStringAsFixed(1)}%',
        route: '/analytics',
      ),
    );
  }

  for (final ClassPerformanceSummary schoolClass in overview.classPerformance) {
    items.add(
      SearchResultItem(
        id: schoolClass.className,
        type: SearchEntityType.schoolClass,
        title: schoolClass.className,
        subtitle:
            '${schoolClass.totalStudents} students • Avg ${schoolClass.averageScore.toStringAsFixed(1)}%',
        route: '/analytics',
      ),
    );
  }

  return items;
}

List<ScorePoint> _buildSystemTrend(List<StudentResultRecord> results) {
  const List<String> labels = <String>['Term 1', 'Inter', 'Term 2', 'Current'];
  if (results.isEmpty) {
    return labels
        .map((String label) => ScorePoint(label: label, value: 0))
        .toList();
  }

  return List<ScorePoint>.generate(labels.length, (int index) {
    return ScorePoint(
      label: labels[index],
      value: _average(
        results.map(
          (StudentResultRecord record) => record.performanceTrend[index].value,
        ),
      ),
    );
  });
}

List<SubjectPerformanceSummary> _buildSubjectPerformance(
  List<StudentResultRecord> results,
) {
  final Map<String, List<SubjectResult>> grouped =
      <String, List<SubjectResult>>{};
  final Map<String, String> topStudentBySubject = <String, String>{};
  final Map<String, double> topScoreBySubject = <String, double>{};

  for (final StudentResultRecord record in results) {
    for (final SubjectResult result in record.subjectResults) {
      grouped.putIfAbsent(result.subject, () => <SubjectResult>[]).add(result);
      final double currentTop = topScoreBySubject[result.subject] ?? -1;
      if (result.averageScore > currentTop) {
        topScoreBySubject[result.subject] = result.averageScore;
        topStudentBySubject[result.subject] = record.studentName;
      }
    }
  }

  final List<SubjectPerformanceSummary> summaries =
      grouped.entries.map((MapEntry<String, List<SubjectResult>> entry) {
        final List<SubjectResult> subjectResults = entry.value;
        final double averageScore = _average(
          subjectResults.map((SubjectResult item) => item.averageScore),
        );
        final double interExamAverage = _average(
          subjectResults.map((SubjectResult item) => item.interExamScore),
        );
        final double passRate = subjectResults.isEmpty
            ? 0
            : subjectResults
                      .where(
                        (SubjectResult item) =>
                            NectaOLevelCalculator.gradeForScore(
                              item.averageScore,
                            ).passed,
                      )
                      .length /
                  subjectResults.length *
                  100;

        return SubjectPerformanceSummary(
          subject: entry.key,
          averageScore: averageScore,
          interExamAverage: interExamAverage,
          passRate: passRate,
          topStudent: topStudentBySubject[entry.key] ?? 'No data',
          trend: <ScorePoint>[
            ScorePoint(label: 'Exam 1', value: averageScore - 7),
            ScorePoint(label: 'Exam 2', value: averageScore - 3),
            ScorePoint(label: 'Inter', value: interExamAverage),
            ScorePoint(label: 'Current', value: averageScore),
          ],
        );
      }).toList()..sort(
        (SubjectPerformanceSummary a, SubjectPerformanceSummary b) =>
            b.averageScore.compareTo(a.averageScore),
      );

  return summaries;
}

List<ClassPerformanceSummary> _buildClassPerformance(
  List<StudentResultRecord> results,
) {
  final Map<String, List<StudentResultRecord>> grouped =
      <String, List<StudentResultRecord>>{};
  for (final StudentResultRecord record in results) {
    grouped
        .putIfAbsent(record.className, () => <StudentResultRecord>[])
        .add(record);
  }

  final List<ClassPerformanceSummary> summaries =
      grouped.entries.map((MapEntry<String, List<StudentResultRecord>> entry) {
        final List<StudentResultRecord> classResults = entry.value;
        final Map<String, int> divisionDistribution = <String, int>{
          'Division I': 0,
          'Division II': 0,
          'Division III': 0,
          'Division IV': 0,
          'Division 0': 0,
        };

        for (final StudentResultRecord result in classResults) {
          divisionDistribution[result.division] =
              (divisionDistribution[result.division] ?? 0) + 1;
        }

        final StudentResultRecord topStudent = classResults.first;
        return ClassPerformanceSummary(
          className: entry.key,
          totalStudents: classResults.length,
          averageScore: _average(
            classResults.map((StudentResultRecord item) => item.averageScore),
          ),
          interExamAverage: _average(
            classResults.map(
              (StudentResultRecord item) => item.interExamAverage,
            ),
          ),
          passRate:
              classResults
                  .where(
                    (StudentResultRecord item) => item.division != 'Division 0',
                  )
                  .length /
              classResults.length *
              100,
          topStudent: topStudent.studentName,
          divisionDistribution: divisionDistribution,
          trend: _buildSystemTrend(classResults),
        );
      }).toList()..sort(
        (ClassPerformanceSummary a, ClassPerformanceSummary b) =>
            b.averageScore.compareTo(a.averageScore),
      );

  return summaries;
}

double _average(Iterable<double> values) {
  final List<double> list = values.toList();
  if (list.isEmpty) {
    return 0;
  }

  final double total = list.fold<double>(
    0,
    (double sum, double item) => sum + item,
  );
  return double.parse((total / list.length).toStringAsFixed(1));
}

SchoolAdminState _initialAdminState() {
  return SchoolAdminState(
    session: null,
    schoolName: 'Summit View College',
    districtName: 'Jabu District',
    headmasterName: 'Head Grace Njeri',
    teachers: const <TeacherAccount>[],
    resultWindow: ResultWindowSettings(
      uploadDeadline: DateTime.now().add(const Duration(days: 4)),
      editDeadline: DateTime.now().add(const Duration(days: 6)),
      editingLocked: false,
    ),
    settings: const SchoolSettings(
      currentAcademicYear: '2026',
      currentTermLabel: 'Term II',
      enforceTeacherSubjectIsolation: true,
      autoZeroMissingPracticals: true,
      allowTeacherStudentRegistration: true,
      allowTeacherResultDownloads: true,
      showCombinedResultsToTeachers: true,
    ),
    studentResults: const <StudentResultRecord>[],
  );
}

List<SubjectResult> _buildDefaultSubjects(
  int index, {
  List<String> selectedSubjects = const <String>[],
}) {
  final List<String> sourceSubjects = selectedSubjects.isEmpty
      ? kNectaOLevelDefaultSubjectNames
      : selectedSubjects;

  return sourceSubjects.asMap().entries.map((MapEntry<int, String> entry) {
    final bool isCoreSubject = entry.key < 7;
    return SubjectResult(
      subject: entry.value,
      examMarks: <ExamMark>[],
      averageScore: 0.0,
      grade: '-',
      gradePoint: 0,
      isCoreSubject: isCoreSubject,
    );
  }).toList();
}

SubjectResult _buildSubjectResult({
  required String subject,
  required List<ExamMark> examMarks,
  bool isCoreSubject = true,
}) {
  final double averageScore = _averageExamScore(examMarks);
  final NectaOLevelGrade grade = NectaOLevelCalculator.gradeForScore(
    averageScore,
  );

  return SubjectResult(
    subject: subject,
    examMarks: examMarks,
    averageScore: averageScore,
    grade: grade.letter,
    gradePoint: grade.point,
    isCoreSubject: isCoreSubject,
  );
}

StudentResultRecord _composeStudentRecord({
  required String id,
  required String admissionNumber,
  required String studentName,
  required String className,
  required double attendanceRate,
  required List<SubjectResult> subjectResults,
  required List<ScorePoint> performanceTrend,
}) {
  final NectaOLevelDivisionSummary divisionSummary =
      NectaOLevelCalculator.divisionForSubjects(subjectResults);
  final double averageScore = _average(
    subjectResults.map((SubjectResult item) => item.averageScore),
  );
  final double interExamAverage = _average(
    subjectResults.map((SubjectResult item) => item.interExamScore),
  );

  return StudentResultRecord(
    id: id,
    admissionNumber: admissionNumber,
    studentName: studentName,
    className: className,
    averageScore: averageScore,
    interExamAverage: interExamAverage,
    division: divisionSummary.division,
    divisionPoints: divisionSummary.points,
    attendanceRate: attendanceRate,
    subjectResults: subjectResults,
    performanceTrend: performanceTrend,
    riskLevel: _riskFor(averageScore, attendanceRate),
  );
}

StudentResultRecord _recomposeRecord(
  StudentResultRecord record,
  List<SubjectResult> subjectResults,
) {
  return _composeStudentRecord(
    id: record.id,
    admissionNumber: record.admissionNumber,
    studentName: record.studentName,
    className: record.className,
    attendanceRate: record.attendanceRate,
    subjectResults: subjectResults,
    performanceTrend: <ScorePoint>[
      ...record.performanceTrend.take(record.performanceTrend.length - 1),
      ScorePoint(
        label: 'Current',
        value: _average(
          subjectResults.map((SubjectResult item) => item.averageScore),
        ),
      ),
    ],
  );
}

RiskLevel _riskFor(double averageScore, double attendanceRate) {
  if (averageScore < 45 || attendanceRate < 80) {
    return RiskLevel.urgent;
  }
  if (averageScore < 60 || attendanceRate < 88) {
    return RiskLevel.watch;
  }
  return RiskLevel.stable;
}

double _averageExamScore(List<ExamMark> examMarks) {
  if (examMarks.isEmpty) {
    return 0;
  }

  final Map<String, List<ExamMark>> grouped = <String, List<ExamMark>>{};
  for (final ExamMark mark in examMarks) {
    final String key = mark.sessionKey ?? '${mark.type.name}:${mark.label}';
    grouped.putIfAbsent(key, () => <ExamMark>[]).add(mark);
  }

  final List<double> sessionAverages = grouped.values
      .map((List<ExamMark> group) {
        final double total = group.fold<double>(
          0,
          (double sum, ExamMark mark) => sum + mark.score,
        );
        return total / group.length;
      })
      .toList(growable: false);

  return _average(sessionAverages);
}

TeacherAccount? _teacherById(List<TeacherAccount> teachers, String teacherId) {
  for (final TeacherAccount teacher in teachers) {
    if (teacher.id == teacherId) {
      return teacher;
    }
  }
  return null;
}

List<String> _normalizedAssignments(
  List<String> values, {
  String? fallback,
  required String defaultValue,
  int? maxItems,
}) {
  final Set<String> uniqueAssignments = <String>{
    ...values
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty),
    if (fallback != null && fallback.trim().isNotEmpty) fallback.trim(),
  };
  final List<String> normalized = uniqueAssignments.toList();

  if (normalized.isEmpty) {
    normalized.add(defaultValue);
  }

  if (maxItems != null && normalized.length > maxItems) {
    return normalized.take(maxItems).toList(growable: false);
  }

  return normalized.toList(growable: false);
}

bool _subjectUsesPracticals({
  required String className,
  required String subject,
}) {
  final bool seniorClass =
      className.startsWith('Form 3') || className.startsWith('Form 4');
  return seniorClass &&
      const <String>{'Biology', 'Chemistry', 'Physics'}.contains(subject);
}
