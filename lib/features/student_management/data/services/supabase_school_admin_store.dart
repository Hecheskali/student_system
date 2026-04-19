import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/services/necta_olevel_calculator.dart';
import 'supabase_service.dart';

const List<String> kStandardSchoolClassNames = <String>[
  'Form 1 A',
  'Form 1 B',
  'Form 2 A',
  'Form 2 B',
  'Form 3 A',
  'Form 3 B',
  'Form 4 A',
  'Form 4 B',
];

@immutable
class SupabaseSchoolAdminLoadResult {
  const SupabaseSchoolAdminLoadResult({
    required this.schoolName,
    required this.districtName,
    required this.headmasterName,
    required this.teachers,
    required this.resultWindow,
    required this.settings,
    required this.studentResults,
    required this.session,
  });

  final String schoolName;
  final String districtName;
  final String headmasterName;
  final List<TeacherAccount> teachers;
  final ResultWindowSettings resultWindow;
  final SchoolSettings settings;
  final List<StudentResultRecord> studentResults;
  final SessionUser? session;
}

@immutable
class SupabaseSchoolAdminAuthResult {
  const SupabaseSchoolAdminAuthResult({required this.session});

  final SessionUser session;
}

class SupabaseSchoolAdminStore {
  SupabaseSchoolAdminStore(this._service);

  final SupabaseService _service;

  SupabaseClient get _client => _service.client;

  Future<SupabaseSchoolAdminLoadResult> load({
    required SchoolAdminState fallbackState,
  }) async {
    final ({
      String schoolName,
      String districtName,
      String headmasterName,
      ResultWindowSettings resultWindow,
      SchoolSettings settings,
    }) config = await _loadConfig(fallbackState: fallbackState);

    await ensureReferenceData(
      schoolName: config.schoolName,
      districtName: config.districtName,
      classNames: kStandardSchoolClassNames,
    );

    final List<TeacherAccount> teachers = await loadTeachers();
    final List<StudentResultRecord> studentResults = await loadStudentResults();
    final SessionUser? session = await _buildSessionFromCurrentAuth(
      schoolName: config.schoolName,
      districtName: config.districtName,
      teachers: teachers,
    );

    return SupabaseSchoolAdminLoadResult(
      schoolName: config.schoolName,
      districtName: config.districtName,
      headmasterName: config.headmasterName,
      teachers: teachers,
      resultWindow: config.resultWindow,
      settings: config.settings,
      studentResults: studentResults,
      session: session,
    );
  }

  Future<SupabaseSchoolAdminAuthResult> registerUser({
    required SignUpDraft draft,
    required String password,
    required SchoolSettings settings,
    required ResultWindowSettings resultWindow,
  }) async {
    final AuthResponse response = await _service.createUserWithEmailAndPassword(
      draft.email,
      password,
    );
    final User? user = response.user;
    if (user == null) {
      throw StateError('Supabase did not return a user for this sign up.');
    }

    await ensureReferenceData(
      schoolName: draft.schoolName,
      districtName: draft.districtName,
      classNames: <String>[
        ...kStandardSchoolClassNames,
        ...draft.assignedClasses,
        if (draft.assignedClass != null) draft.assignedClass!,
      ],
    );

    await saveSettings(
      schoolName: draft.schoolName,
      districtName: draft.districtName,
      headmasterName: draft.role == UserRole.headOfSchool
          ? draft.name
          : null,
      resultWindow: resultWindow,
      settings: settings,
    );

    TeacherAccount? teacher;
    if (draft.role == UserRole.teacher) {
      teacher = await saveTeacher(
        teacher: TeacherAccount(
          id: '',
          name: draft.name,
          email: draft.email,
          subject: _normalizedAssignments(
            draft.subjects,
            fallback: draft.subject,
            defaultValue: 'Basic Mathematics',
            maxItems: 2,
          ).first,
          assignedClass: _normalizedAssignments(
            draft.assignedClasses,
            fallback: draft.assignedClass,
            defaultValue: 'Form 1 A',
          ).first,
          canUploadResults: true,
          canEditResults: true,
          subjects: _normalizedAssignments(
            draft.subjects,
            fallback: draft.subject,
            defaultValue: 'Basic Mathematics',
            maxItems: 2,
          ).skip(1).toList(growable: false),
          assignedClasses: _normalizedAssignments(
            draft.assignedClasses,
            fallback: draft.assignedClass,
            defaultValue: 'Form 1 A',
          ).skip(1).toList(growable: false),
          canRegisterStudents: settings.allowTeacherStudentRegistration,
          canDownloadResults: settings.allowTeacherResultDownloads,
        ),
        schoolName: draft.schoolName,
        districtName: draft.districtName,
        userId: user.id,
      );
    }

    final Map<String, dynamic> profilePayload = <String, dynamic>{
      if (teacher != null) 'teacher_id': teacher.id,
    };
    await _service.createUserProfile(user.id, <String, dynamic>{
      'name': draft.name,
      'email': draft.email,
      'role': _roleToDatabase(draft.role),
      'school_name': draft.schoolName,
      'district_name': draft.districtName,
      'subject': draft.subject,
      'assigned_class': draft.assignedClass,
      'subjects': draft.subjects,
      'assigned_classes': draft.assignedClasses,
      'profile': profilePayload,
    });

    final SessionUser session = teacher != null
        ? SessionUser(
            id: teacher.id,
            name: draft.name,
            email: draft.email,
            role: draft.role,
            schoolName: draft.schoolName,
            districtName: draft.districtName,
            subject: teacher.subject,
            assignedClass: teacher.assignedClass,
            subjects: teacher.effectiveSubjects,
            assignedClasses: teacher.effectiveClasses,
          )
        : SessionUser(
            id: user.id,
            name: draft.name,
            email: draft.email,
            role: draft.role,
            schoolName: draft.schoolName,
            districtName: draft.districtName,
          );

    return SupabaseSchoolAdminAuthResult(session: session);
  }

  Future<SessionUser?> signIn({
    required String email,
    required String password,
    required String fallbackSchoolName,
    required String fallbackDistrictName,
  }) async {
    await _service.signInWithEmailAndPassword(email, password);
    return _buildSessionFromCurrentAuth(
      schoolName: fallbackSchoolName,
      districtName: fallbackDistrictName,
      teachers: await loadTeachers(),
    );
  }

  Future<void> signOut() async {
    await _service.signOut();
  }

  Future<void> ensureReferenceData({
    required String schoolName,
    required String districtName,
    required Iterable<String> classNames,
  }) async {
    final Map<String, dynamic> districtRow = await _ensureDistrict(
      districtName: districtName,
    );
    final Map<String, dynamic> schoolRow = await _ensureSchool(
      districtId: districtRow['id'] as String,
      schoolName: schoolName,
    );

    for (final String className in classNames) {
      await _ensureClass(
        districtId: districtRow['id'] as String,
        schoolId: schoolRow['id'] as String,
        className: className,
      );
    }
  }

  Future<void> saveSettings({
    required String schoolName,
    required String districtName,
    String? headmasterName,
    required ResultWindowSettings resultWindow,
    required SchoolSettings settings,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'school_name': schoolName,
      'district_name': districtName,
      'current_academic_year': settings.currentAcademicYear,
      'current_term_label': settings.currentTermLabel,
      'enforce_teacher_subject_isolation':
          settings.enforceTeacherSubjectIsolation,
      'auto_zero_missing_practicals': settings.autoZeroMissingPracticals,
      'allow_teacher_student_registration':
          settings.allowTeacherStudentRegistration,
      'allow_teacher_result_downloads': settings.allowTeacherResultDownloads,
      'show_combined_results_to_teachers':
          settings.showCombinedResultsToTeachers,
    };
    if (headmasterName != null) {
      payload['headmaster_name'] = headmasterName;
    }

    await _client.from('settings').upsert(
      <String, dynamic>{
        'id': 'deadlines',
        'upload_deadline': resultWindow.uploadDeadline.toIso8601String(),
        'edit_deadline': resultWindow.editDeadline.toIso8601String(),
        'editing_locked': resultWindow.editingLocked,
        'payload': payload,
      },
      onConflict: 'id',
    );
  }

  Future<List<TeacherAccount>> loadTeachers() async {
    final dynamic response = await _client
        .from('teachers')
        .select()
        .order('created_at');
    final List<dynamic> rows = List<dynamic>.from(response as List);
    return rows
        .map((dynamic row) => _teacherFromRow(_asMap(row)))
        .toList(growable: false);
  }

  Future<TeacherAccount> saveTeacher({
    required TeacherAccount teacher,
    required String schoolName,
    required String districtName,
    String? userId,
  }) async {
    final Map<String, dynamic>? existing = await _findTeacher(
      teacherId: _looksLikeUuid(teacher.id) ? teacher.id : null,
      userId: userId,
      email: teacher.email,
    );

    final Map<String, dynamic> payload = <String, dynamic>{
      'name': teacher.name,
      'email': teacher.email,
      'subject': teacher.subject,
      'assigned_class': teacher.assignedClass,
      'can_upload_results': teacher.canUploadResults,
      'can_edit_results': teacher.canEditResults,
      'can_register_students': teacher.canRegisterStudents,
      'can_download_results': teacher.canDownloadResults,
      'subjects': teacher.subjects,
      'assigned_classes': teacher.assignedClasses,
      'school_name': schoolName,
      'district_name': districtName,
      'profile': const <String, dynamic>{},
    };
    if (existing != null) {
      payload['id'] = existing['id'];
    }
    if (userId != null) {
      payload['user_id'] = userId;
    }

    final dynamic saved = await _client
        .from('teachers')
        .upsert(payload, onConflict: 'id')
        .select()
        .single();
    return _teacherFromRow(_asMap(saved));
  }

  Future<void> deleteTeacher(String teacherId) async {
    await _client.from('teachers').delete().eq('id', teacherId);
  }

  Future<List<StudentResultRecord>> loadStudentResults() async {
    final dynamic response = await _client
        .from('students')
        .select()
        .order('created_at');
    final List<dynamic> rows = List<dynamic>.from(response as List);
    return rows
        .map(
          (dynamic row) => _studentRecordFromRow(
            _asMap(row),
          ),
        )
        .toList(growable: false);
  }

  Future<StudentResultRecord> saveStudentRecord({
    required StudentResultRecord record,
    required String schoolName,
    required String districtName,
  }) async {
    final ({
      String districtId,
      String schoolId,
      String classId,
    }) hierarchy = await _resolveHierarchy(
      schoolName: schoolName,
      districtName: districtName,
      className: record.className,
    );

    final Map<String, dynamic> payload = <String, dynamic>{
      if (_looksLikeUuid(record.id)) 'id': record.id,
      'district_id': hierarchy.districtId,
      'school_id': hierarchy.schoolId,
      'class_id': hierarchy.classId,
      'full_name': record.studentName,
      'admission_number': record.admissionNumber,
      'grade_level': _gradeLevelForClass(record.className),
      'class_name': record.className,
      'average_score': record.averageScore,
      'gpa': _gpaFromAverage(record.averageScore),
      'attendance_rate': record.attendanceRate,
      'risk_level': record.riskLevel.name,
      'subject_scores': <String, dynamic>{
        for (final SubjectResult subject in record.subjectResults)
          subject.subject: subject.averageScore,
      },
      'monthly_performance': record.performanceTrend
          .map((ScorePoint point) => point.value)
          .toList(growable: false),
      'subjects': record.subjectResults
          .map((SubjectResult subject) => subject.subject)
          .toList(growable: false),
      'student_profile': _studentProfilePayload(record),
    };

    final dynamic saved = _looksLikeUuid(record.id)
        ? await _client
              .from('students')
              .upsert(payload, onConflict: 'id')
              .select()
              .single()
        : await _client.from('students').insert(payload).select().single();

    final StudentResultRecord savedRecord = record.copyWith(
      id: _stringValue(_asMap(saved), 'id', fallback: record.id),
    );

    await _syncStudentExamsAndResults(
      record: savedRecord,
      classId: hierarchy.classId,
    );

    return savedRecord;
  }

  Future<void> saveStudentRecords({
    required Iterable<StudentResultRecord> records,
    required String schoolName,
    required String districtName,
  }) async {
    for (final StudentResultRecord record in records) {
      await saveStudentRecord(
        record: record,
        schoolName: schoolName,
        districtName: districtName,
      );
    }
  }

  Future<({
    String schoolName,
    String districtName,
    String headmasterName,
    ResultWindowSettings resultWindow,
    SchoolSettings settings,
  })> _loadConfig({
    required SchoolAdminState fallbackState,
  }) async {
    final dynamic row = await _client
        .from('settings')
        .select()
        .eq('id', 'deadlines')
        .maybeSingle();

    if (row == null) {
      return (
        schoolName: fallbackState.schoolName,
        districtName: fallbackState.districtName,
        headmasterName: fallbackState.headmasterName,
        resultWindow: fallbackState.resultWindow,
        settings: fallbackState.settings,
      );
    }

    final Map<String, dynamic> settingsRow = _asMap(row);
    final Map<String, dynamic> payload = _mapValue(settingsRow['payload']);

    return (
      schoolName: _stringValue(
        payload,
        'school_name',
        fallback: fallbackState.schoolName,
      ),
      districtName: _stringValue(
        payload,
        'district_name',
        fallback: fallbackState.districtName,
      ),
      headmasterName: _stringValue(
        payload,
        'headmaster_name',
        fallback: fallbackState.headmasterName,
      ),
      resultWindow: ResultWindowSettings(
        uploadDeadline: _dateTimeValue(
          settingsRow['upload_deadline'],
          fallbackState.resultWindow.uploadDeadline,
        ),
        editDeadline: _dateTimeValue(
          settingsRow['edit_deadline'],
          fallbackState.resultWindow.editDeadline,
        ),
        editingLocked: _boolValue(
          settingsRow,
          'editing_locked',
          fallback: fallbackState.resultWindow.editingLocked,
        ),
      ),
      settings: SchoolSettings(
        currentAcademicYear: _stringValue(
          payload,
          'current_academic_year',
          fallback: fallbackState.settings.currentAcademicYear,
        ),
        currentTermLabel: _stringValue(
          payload,
          'current_term_label',
          fallback: fallbackState.settings.currentTermLabel,
        ),
        enforceTeacherSubjectIsolation: _boolValue(
          payload,
          'enforce_teacher_subject_isolation',
          fallback: fallbackState.settings.enforceTeacherSubjectIsolation,
        ),
        autoZeroMissingPracticals: _boolValue(
          payload,
          'auto_zero_missing_practicals',
          fallback: fallbackState.settings.autoZeroMissingPracticals,
        ),
        allowTeacherStudentRegistration: _boolValue(
          payload,
          'allow_teacher_student_registration',
          fallback: fallbackState.settings.allowTeacherStudentRegistration,
        ),
        allowTeacherResultDownloads: _boolValue(
          payload,
          'allow_teacher_result_downloads',
          fallback: fallbackState.settings.allowTeacherResultDownloads,
        ),
        showCombinedResultsToTeachers: _boolValue(
          payload,
          'show_combined_results_to_teachers',
          fallback: fallbackState.settings.showCombinedResultsToTeachers,
        ),
      ),
    );
  }

  Future<SessionUser?> _buildSessionFromCurrentAuth({
    required String schoolName,
    required String districtName,
    required List<TeacherAccount> teachers,
  }) async {
    final User? user = _service.currentUser;
    if (user == null) {
      return null;
    }

    Map<String, dynamic>? profile = await _service.getUserProfile(user.id);
    if (profile == null) {
      final Map<String, dynamic> metadata = _mapValue(user.userMetadata);
      final String displayName = _stringValue(
        metadata,
        'full_name',
        fallback: _stringValue(
          metadata,
          'name',
          fallback: (user.email ?? 'Administrator').split('@').first,
        ),
      );
      await _service.createUserProfile(user.id, <String, dynamic>{
        'name': displayName,
        'email': user.email ?? '',
        'role': 'head_of_school',
        'school_name': schoolName,
        'district_name': districtName,
        'subjects': const <String>[],
        'assigned_classes': const <String>[],
        'profile': const <String, dynamic>{'auto_provisioned': true},
      });
      profile = await _service.getUserProfile(user.id);
      profile ??= <String, dynamic>{
        'name': displayName,
        'email': user.email ?? '',
        'role': 'head_of_school',
        'school_name': schoolName,
        'district_name': districtName,
        'subjects': const <String>[],
        'assigned_classes': const <String>[],
        'profile': const <String, dynamic>{'auto_provisioned': true},
      };
    }

    final UserRole role = _roleFromDatabase(
      _stringValue(profile, 'role', fallback: 'teacher'),
    );
    final String resolvedSchoolName = _stringValue(
      profile,
      'school_name',
      fallback: schoolName,
    );
    final String resolvedDistrictName = _stringValue(
      profile,
      'district_name',
      fallback: districtName,
    );

    if (role == UserRole.teacher) {
      final Map<String, dynamic> userProfile = _mapValue(profile['profile']);
      final String teacherId = _stringValue(userProfile, 'teacher_id');

      TeacherAccount? teacher;
      for (final TeacherAccount item in teachers) {
        if (item.id == teacherId || item.email == user.email) {
          teacher = item;
          break;
        }
      }

      teacher ??= await _loadTeacherForUser(user.id, user.email ?? '');

      if (teacher != null) {
        return SessionUser(
          id: teacher.id,
          name: teacher.name,
          email: teacher.email,
          role: role,
          schoolName: resolvedSchoolName,
          districtName: resolvedDistrictName,
          subject: teacher.subject,
          assignedClass: teacher.assignedClass,
          subjects: teacher.effectiveSubjects,
          assignedClasses: teacher.effectiveClasses,
        );
      }
    }

    return SessionUser(
      id: user.id,
      name: _stringValue(profile, 'name', fallback: user.email ?? 'User'),
      email: _stringValue(profile, 'email', fallback: user.email ?? ''),
      role: role,
      schoolName: resolvedSchoolName,
      districtName: resolvedDistrictName,
      subject: _nullableString(profile['subject']),
      assignedClass: _nullableString(profile['assigned_class']),
      subjects: _stringList(profile['subjects']),
      assignedClasses: _stringList(profile['assigned_classes']),
    );
  }

  Future<TeacherAccount?> _loadTeacherForUser(String userId, String email) async {
    final Map<String, dynamic>? byUser = await _findTeacher(
      userId: userId,
      email: null,
    );
    if (byUser != null) {
      return _teacherFromRow(byUser);
    }

    final Map<String, dynamic>? byEmail = await _findTeacher(
      userId: null,
      email: email,
    );
    if (byEmail != null) {
      return _teacherFromRow(byEmail);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _findTeacher({
    String? teacherId,
    String? userId,
    String? email,
  }) async {
    if (teacherId != null && teacherId.isNotEmpty) {
      final dynamic row = await _client
          .from('teachers')
          .select()
          .eq('id', teacherId)
          .maybeSingle();
      if (row != null) {
        return _asMap(row);
      }
    }

    if (userId != null && userId.isNotEmpty) {
      final dynamic row = await _client
          .from('teachers')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        return _asMap(row);
      }
    }

    if (email != null && email.isNotEmpty) {
      final dynamic row = await _client
          .from('teachers')
          .select()
          .eq('email', email)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        return _asMap(row);
      }
    }

    return null;
  }

  Future<({
    String districtId,
    String schoolId,
    String classId,
  })> _resolveHierarchy({
    required String schoolName,
    required String districtName,
    required String className,
  }) async {
    await ensureReferenceData(
      schoolName: schoolName,
      districtName: districtName,
      classNames: <String>[className],
    );

    final Map<String, dynamic> district = await _ensureDistrict(
      districtName: districtName,
    );
    final Map<String, dynamic> school = await _ensureSchool(
      districtId: district['id'] as String,
      schoolName: schoolName,
    );
    final Map<String, dynamic> schoolClass = await _ensureClass(
      districtId: district['id'] as String,
      schoolId: school['id'] as String,
      className: className,
    );

    return (
      districtId: district['id'] as String,
      schoolId: school['id'] as String,
      classId: schoolClass['id'] as String,
    );
  }

  Future<Map<String, dynamic>> _ensureDistrict({
    required String districtName,
  }) async {
    final dynamic existing = await _client
        .from('districts')
        .select()
        .eq('name', districtName)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      return _asMap(existing);
    }

    final dynamic inserted = await _client
        .from('districts')
        .insert(<String, dynamic>{
          'name': districtName,
          'region_label': 'Configured district',
          'focus_area': 'Academic monitoring',
        })
        .select()
        .single();
    return _asMap(inserted);
  }

  Future<Map<String, dynamic>> _ensureSchool({
    required String districtId,
    required String schoolName,
  }) async {
    final dynamic existing = await _client
        .from('schools')
        .select()
        .eq('district_id', districtId)
        .eq('name', schoolName)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      return _asMap(existing);
    }

    final dynamic inserted = await _client
        .from('schools')
        .insert(<String, dynamic>{
          'district_id': districtId,
          'name': schoolName,
          'principal': '',
        })
        .select()
        .single();
    return _asMap(inserted);
  }

  Future<Map<String, dynamic>> _ensureClass({
    required String districtId,
    required String schoolId,
    required String className,
  }) async {
    final dynamic existing = await _client
        .from('classes')
        .select()
        .eq('school_id', schoolId)
        .eq('name', className)
        .limit(1)
        .maybeSingle();
    if (existing != null) {
      return _asMap(existing);
    }

    final dynamic inserted = await _client
        .from('classes')
        .insert(<String, dynamic>{
          'school_id': schoolId,
          'district_id': districtId,
          'name': className,
          'teacher': '',
        })
        .select()
        .single();
    return _asMap(inserted);
  }

  TeacherAccount _teacherFromRow(Map<String, dynamic> row) {
    return TeacherAccount(
      id: _stringValue(row, 'id'),
      name: _stringValue(row, 'name'),
      email: _stringValue(row, 'email'),
      subject: _stringValue(row, 'subject'),
      assignedClass: _stringValue(row, 'assigned_class'),
      canUploadResults: _boolValue(row, 'can_upload_results', fallback: true),
      canEditResults: _boolValue(row, 'can_edit_results', fallback: true),
      subjects: _stringList(row['subjects']),
      assignedClasses: _stringList(row['assigned_classes']),
      canRegisterStudents: _boolValue(
        row,
        'can_register_students',
        fallback: true,
      ),
      canDownloadResults: _boolValue(
        row,
        'can_download_results',
        fallback: true,
      ),
    );
  }

  StudentResultRecord _studentRecordFromRow(Map<String, dynamic> row) {
    final Map<String, dynamic> profile = _mapValue(row['student_profile']);
    final List<SubjectResult> subjectResults =
        _subjectResultsFromPayload(profile['subject_results']);
    final List<ScorePoint> performanceTrend = _scorePointsFromPayload(
      profile['performance_trend'],
      fallbackValues: _doubleList(row['monthly_performance']),
    );

    final List<SubjectResult> resolvedSubjectResults = subjectResults.isNotEmpty
        ? subjectResults
        : _subjectResultsFromScores(
            _mapValue(row['subject_scores']),
            _stringList(row['subjects']),
          );

    final NectaOLevelDivisionSummary division =
        NectaOLevelCalculator.divisionForSubjects(resolvedSubjectResults);

    return StudentResultRecord(
      id: _stringValue(row, 'id'),
      admissionNumber: _stringValue(row, 'admission_number'),
      studentName: _stringValue(row, 'full_name'),
      className: _stringValue(row, 'class_name'),
      averageScore: _doubleValue(row, 'average_score'),
      interExamAverage: _doubleValue(
        profile,
        'inter_exam_average',
        fallback: _average(
          resolvedSubjectResults.map((SubjectResult subject) {
            return subject.interExamScore;
          }),
        ),
      ),
      division: _stringValue(
        profile,
        'division',
        fallback: division.division,
      ),
      divisionPoints: _intValue(
        profile,
        'division_points',
        fallback: division.points,
      ),
      attendanceRate: _doubleValue(row, 'attendance_rate'),
      subjectResults: resolvedSubjectResults,
      performanceTrend: performanceTrend,
      riskLevel: _riskLevelFromString(
        _stringValue(row, 'risk_level', fallback: 'stable'),
      ),
    );
  }

  Future<void> _syncStudentExamsAndResults({
    required StudentResultRecord record,
    required String classId,
  }) async {
    for (final SubjectResult subject in record.subjectResults) {
      if (subject.examMarks.isEmpty) {
        continue;
      }

      final Map<String, List<ExamMark>> grouped = <String, List<ExamMark>>{};
      for (final ExamMark mark in subject.examMarks) {
        final String key = mark.sessionKey ?? '${mark.type.name}:${mark.label}';
        grouped.putIfAbsent(key, () => <ExamMark>[]).add(mark);
      }

      for (final List<ExamMark> group in grouped.values) {
        final ExamMark anchor = group.first;
        final String? teacherId = anchor.teacherId;
        final dynamic existingExam = await _client
            .from('exams')
            .select()
            .eq('class_id', classId)
            .eq('subject', subject.subject)
            .eq('title', anchor.label)
            .eq('exam_type', anchor.type.name)
            .eq(
              'exam_date',
              (anchor.examDate ?? DateTime.now()).toIso8601String().split('T').first,
            )
            .limit(1)
            .maybeSingle();

        final dynamic savedExam = existingExam != null
            ? await _client
                  .from('exams')
                  .update(<String, dynamic>{
                    'teacher_id': teacherId != null && _looksLikeUuid(teacherId)
                        ? teacherId
                        : null,
                    'term_label': null,
                    'academic_year': null,
                    'total_marks': 100,
                    'payload': <String, dynamic>{
                      'teacher_name': anchor.teacherName,
                      'session_key': anchor.sessionKey,
                    },
                  })
                  .eq('id', _asMap(existingExam)['id'])
                  .select()
                  .single()
            : await _client
                  .from('exams')
                  .insert(<String, dynamic>{
                    'class_id': classId,
                    'teacher_id': teacherId != null && _looksLikeUuid(teacherId)
                        ? teacherId
                        : null,
                    'subject': subject.subject,
                    'title': anchor.label,
                    'exam_type': anchor.type.name,
                    'exam_date': (anchor.examDate ?? DateTime.now())
                        .toIso8601String()
                        .split('T')
                        .first,
                    'total_marks': 100,
                    'payload': <String, dynamic>{
                      'teacher_name': anchor.teacherName,
                      'session_key': anchor.sessionKey,
                    },
                  })
                  .select()
                  .single();

        final String examId = _stringValue(_asMap(savedExam), 'id');
        await _client.from('results').delete().eq('exam_id', examId).eq(
          'student_id',
          record.id,
        );

        if (group.isEmpty) {
          continue;
        }

        await _client.from('results').insert(
          group.map((ExamMark mark) {
            return <String, dynamic>{
              'student_id': record.id,
              'exam_id': examId,
              'class_id': classId,
              'subject': subject.subject,
              'exam_type': mark.type.name,
              'component': mark.component.name,
              'label': mark.label,
              'score': mark.score,
              'average_score': subject.averageScore,
              'division': record.division,
              'payload': <String, dynamic>{
                'session_key': mark.sessionKey,
                'teacher_id': mark.teacherId,
                'teacher_name': mark.teacherName,
                'exam_date': mark.examDate?.toIso8601String(),
                'uploaded_at': mark.uploadedAt?.toIso8601String(),
              },
            };
          }).toList(growable: false),
        );
      }
    }
  }
}

Map<String, dynamic> _studentProfilePayload(StudentResultRecord record) {
  return <String, dynamic>{
    'division': record.division,
    'division_points': record.divisionPoints,
    'inter_exam_average': record.interExamAverage,
    'subject_results': record.subjectResults.map(_subjectPayload).toList(),
    'performance_trend': record.performanceTrend.map(_scorePointPayload).toList(),
  };
}

Map<String, dynamic> _subjectPayload(SubjectResult subject) {
  return <String, dynamic>{
    'subject': subject.subject,
    'average_score': subject.averageScore,
    'grade': subject.grade,
    'grade_point': subject.gradePoint,
    'is_core_subject': subject.isCoreSubject,
    'exam_marks': subject.examMarks.map(_examMarkPayload).toList(),
  };
}

Map<String, dynamic> _examMarkPayload(ExamMark mark) {
  return <String, dynamic>{
    'id': mark.id,
    'label': mark.label,
    'type': mark.type.name,
    'score': mark.score,
    'component': mark.component.name,
    'session_key': mark.sessionKey,
    'teacher_id': mark.teacherId,
    'teacher_name': mark.teacherName,
    'exam_date': mark.examDate?.toIso8601String(),
    'uploaded_at': mark.uploadedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _scorePointPayload(ScorePoint point) {
  return <String, dynamic>{'label': point.label, 'value': point.value};
}

List<SubjectResult> _subjectResultsFromPayload(dynamic value) {
  if (value is! List) {
    return const <SubjectResult>[];
  }

  return value.map((dynamic item) {
    final Map<String, dynamic> row = _mapValue(item);
    final List<ExamMark> examMarks = _examMarksFromPayload(row['exam_marks']);
    final double averageScore = _doubleValue(
      row,
      'average_score',
      fallback: _average(examMarks.map((ExamMark mark) => mark.score)),
    );
    final NectaOLevelGrade grade = NectaOLevelCalculator.gradeForScore(
      averageScore,
    );

    return SubjectResult(
      subject: _stringValue(row, 'subject'),
      examMarks: examMarks,
      averageScore: averageScore,
      grade: _stringValue(row, 'grade', fallback: grade.letter),
      gradePoint: _intValue(row, 'grade_point', fallback: grade.point),
      isCoreSubject: _boolValue(row, 'is_core_subject', fallback: true),
    );
  }).toList(growable: false);
}

List<ExamMark> _examMarksFromPayload(dynamic value) {
  if (value is! List) {
    return const <ExamMark>[];
  }

  return value.map((dynamic item) {
    final Map<String, dynamic> row = _mapValue(item);
    return ExamMark(
      id: _stringValue(row, 'id'),
      label: _stringValue(row, 'label'),
      type: _examTypeFromString(_stringValue(row, 'type', fallback: 'classExam')),
      score: _doubleValue(row, 'score'),
      component: _examComponentFromString(
        _stringValue(row, 'component', fallback: 'overall'),
      ),
      sessionKey: _nullableString(row['session_key']),
      teacherId: _nullableString(row['teacher_id']),
      teacherName: _nullableString(row['teacher_name']),
      examDate: _nullableDateTime(row['exam_date']),
      uploadedAt: _nullableDateTime(row['uploaded_at']),
    );
  }).toList(growable: false);
}

List<ScorePoint> _scorePointsFromPayload(
  dynamic value, {
  List<double> fallbackValues = const <double>[],
}) {
  if (value is List) {
    return value.map((dynamic item) {
      final Map<String, dynamic> row = _mapValue(item);
      return ScorePoint(
        label: _stringValue(row, 'label'),
        value: _doubleValue(row, 'value'),
      );
    }).toList(growable: false);
  }

  if (fallbackValues.isEmpty) {
    return const <ScorePoint>[
      ScorePoint(label: 'Term 1', value: 0),
      ScorePoint(label: 'Inter', value: 0),
      ScorePoint(label: 'Term 2', value: 0),
      ScorePoint(label: 'Current', value: 0),
    ];
  }

  final List<String> labels = <String>['Term 1', 'Inter', 'Term 2', 'Current'];
  return List<ScorePoint>.generate(labels.length, (int index) {
    final double valueForIndex = index < fallbackValues.length
        ? fallbackValues[index]
        : fallbackValues.last;
    return ScorePoint(label: labels[index], value: valueForIndex);
  }, growable: false);
}

List<SubjectResult> _subjectResultsFromScores(
  Map<String, dynamic> scores,
  List<String> subjects,
) {
  final List<String> sourceSubjects = subjects.isNotEmpty
      ? subjects
      : scores.keys.map((Object key) => key.toString()).toList(growable: false);

  return sourceSubjects.map((String subject) {
    final double score = (scores[subject] as num?)?.toDouble() ?? 0;
    final NectaOLevelGrade grade = NectaOLevelCalculator.gradeForScore(score);
    return SubjectResult(
      subject: subject,
      examMarks: const <ExamMark>[],
      averageScore: score,
      grade: grade.letter,
      gradePoint: grade.point,
      isCoreSubject: true,
    );
  }).toList(growable: false);
}

String _gradeLevelForClass(String className) {
  final RegExpMatch? match = RegExp(r'Form\s+(\d)').firstMatch(className);
  if (match == null) {
    return className;
  }
  return 'Form ${match.group(1)}';
}

double _gpaFromAverage(double average) {
  return double.parse((average.clamp(0, 100) / 20).toStringAsFixed(2));
}

String _roleToDatabase(UserRole role) {
  switch (role) {
    case UserRole.teacher:
      return 'teacher';
    case UserRole.academicMaster:
      return 'academic_master';
    case UserRole.headOfSchool:
      return 'head_of_school';
  }
}

UserRole _roleFromDatabase(String value) {
  switch (value) {
    case 'academic_master':
      return UserRole.academicMaster;
    case 'head_of_school':
      return UserRole.headOfSchool;
    default:
      return UserRole.teacher;
  }
}

ExamType _examTypeFromString(String value) {
  switch (value) {
    case 'midTerm':
      return ExamType.midTerm;
    case 'annual':
      return ExamType.annual;
    case 'teacherNamed':
      return ExamType.teacherNamed;
    default:
      return ExamType.classExam;
  }
}

ExamComponent _examComponentFromString(String value) {
  switch (value) {
    case 'theory':
      return ExamComponent.theory;
    case 'practical':
      return ExamComponent.practical;
    default:
      return ExamComponent.overall;
  }
}

RiskLevel _riskLevelFromString(String value) {
  switch (value) {
    case 'watch':
      return RiskLevel.watch;
    case 'urgent':
      return RiskLevel.urgent;
    default:
      return RiskLevel.stable;
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return Map<String, dynamic>.from(value as Map);
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String _stringValue(
  Map<String, dynamic> map,
  String key, {
  String fallback = '',
}) {
  final dynamic value = map[key];
  if (value is String) {
    return value;
  }
  return fallback;
}

String? _nullableString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

double _doubleValue(
  Map<String, dynamic> map,
  String key, {
  double fallback = 0,
}) {
  final dynamic value = map[key];
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

int _intValue(
  Map<String, dynamic> map,
  String key, {
  int fallback = 0,
}) {
  final dynamic value = map[key];
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

bool _boolValue(
  Map<String, dynamic> map,
  String key, {
  bool fallback = false,
}) {
  final dynamic value = map[key];
  if (value is bool) {
    return value;
  }
  return fallback;
}

DateTime _dateTimeValue(dynamic value, DateTime fallback) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? fallback;
  }
  return fallback;
}

DateTime? _nullableDateTime(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((dynamic item) => item.toString())
      .where((String item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

List<double> _doubleList(dynamic value) {
  if (value is! List) {
    return const <double>[];
  }
  return value
      .whereType<num>()
      .map((num item) => item.toDouble())
      .toList(growable: false);
}

double _average(Iterable<double> values) {
  final List<double> list = values.toList(growable: false);
  if (list.isEmpty) {
    return 0;
  }
  final double total = list.fold<double>(0, (double sum, double item) {
    return sum + item;
  });
  return double.parse((total / list.length).toStringAsFixed(1));
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

List<String> _normalizedAssignments(
  List<String> values, {
  String? fallback,
  required String defaultValue,
  int? maxItems,
}) {
  final Set<String> unique = <String>{
    ...values
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty),
    if (fallback != null && fallback.trim().isNotEmpty) fallback.trim(),
  };
  final List<String> normalized = unique.isEmpty
      ? <String>[defaultValue]
      : unique.toList(growable: false);
  if (maxItems != null && normalized.length > maxItems) {
    return normalized.take(maxItems).toList(growable: false);
  }
  return normalized;
}
