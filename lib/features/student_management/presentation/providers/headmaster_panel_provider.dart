import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/entities/headmaster_panel_entities.dart';
import '../../domain/services/necta_olevel_subjects.dart';
import 'student_management_providers.dart';

final StateNotifierProvider<HeadmasterPanelController, HeadmasterPanelState>
headmasterPanelProvider =
    StateNotifierProvider<HeadmasterPanelController, HeadmasterPanelState>((
      Ref ref,
    ) {
      final HeadmasterPanelController controller = HeadmasterPanelController()
        ..syncFromAdmin(ref.read(schoolAdminProvider));
      ref.listen<SchoolAdminState>(schoolAdminProvider, (
        SchoolAdminState? previous,
        SchoolAdminState next,
      ) {
        controller.syncFromAdmin(next);
      });
      return controller;
    });

final Provider<List<StudentResultRecord>> headmasterActiveStudentsProvider =
    Provider<List<StudentResultRecord>>((Ref ref) {
      return ref
          .watch(schoolAdminProvider)
          .studentResults
          .where((StudentResultRecord record) => record.isActive)
          .toList()
        ..sort(compareStudentResultsForRoster);
    });

final Provider<List<TeacherAccount>> headmasterActiveTeachersProvider =
    Provider<List<TeacherAccount>>((Ref ref) {
      return ref
          .watch(schoolAdminProvider)
          .teachers
          .where((TeacherAccount teacher) => teacher.isActive)
          .toList()
        ..sort(
          (TeacherAccount a, TeacherAccount b) =>
              a.name.toUpperCase().compareTo(b.name.toUpperCase()),
        );
    });

final Provider<List<HeadmasterAttendanceRecord>>
headmasterAttendanceRecordsProvider =
    Provider<List<HeadmasterAttendanceRecord>>((Ref ref) {
      final DateTime now = DateTime.now();
      return ref
          .watch(headmasterActiveStudentsProvider)
          .asMap()
          .entries
          .map((MapEntry<int, StudentResultRecord> entry) {
            final StudentResultRecord record = entry.value;
            final HeadmasterAttendanceStatus status = record.attendanceRate < 80
                ? HeadmasterAttendanceStatus.absent
                : entry.key % 9 == 0 || record.attendanceRate < 88
                ? HeadmasterAttendanceStatus.late
                : HeadmasterAttendanceStatus.present;
            return HeadmasterAttendanceRecord(
              studentId: record.id,
              studentName: record.studentName,
              className: record.className,
              gender: record.gender,
              status: status,
              rate: record.attendanceRate,
              recordedAt: now,
            );
          })
          .toList(growable: false);
    });

final Provider<List<HeadmasterClassSummary>> headmasterClassSummariesProvider =
    Provider<List<HeadmasterClassSummary>>((Ref ref) {
      final SchoolAdminState admin = ref.watch(schoolAdminProvider);
      final HeadmasterPanelState panel = ref.watch(headmasterPanelProvider);
      final List<StudentResultRecord> students = ref.watch(
        headmasterActiveStudentsProvider,
      );
      final Set<String> classNames = <String>{
        ..._standardClassNames,
        ...panel.localClasses,
        ...students.map((StudentResultRecord record) => record.className),
      };

      return classNames.map((String className) {
        final List<StudentResultRecord> classStudents = students
            .where(
              (StudentResultRecord record) => record.className == className,
            )
            .toList();
        final String teacherName =
            panel.classTeacherOverrides[className] ??
            _teacherForClass(admin.teachers, className);
        return HeadmasterClassSummary(
          className: className,
          teacherName: teacherName.isEmpty ? 'Unassigned' : teacherName,
          totalStudents: classStudents.length,
          averageScore: _average(
            classStudents.map((StudentResultRecord record) {
              return record.averageScore;
            }),
          ),
          attendanceRate: _average(
            classStudents.map((StudentResultRecord record) {
              return record.attendanceRate;
            }),
          ),
          streamLabel: className.split(' ').last,
        );
      }).toList()..sort(
        (HeadmasterClassSummary a, HeadmasterClassSummary b) =>
            a.className.compareTo(b.className),
      );
    });

final Provider<List<HeadmasterSubjectSummary>>
headmasterSubjectSummariesProvider = Provider<List<HeadmasterSubjectSummary>>((
  Ref ref,
) {
  final HeadmasterPanelState panel = ref.watch(headmasterPanelProvider);
  final List<StudentResultRecord> students = ref.watch(
    headmasterActiveStudentsProvider,
  );
  final List<TeacherAccount> teachers = ref.watch(
    headmasterActiveTeachersProvider,
  );
  final Set<String> subjects = <String>{
    ...kNectaOLevelSubjectNames,
    for (final StudentResultRecord student in students)
      ...student.subjectResults.map((SubjectResult result) => result.subject),
  };

  return subjects.map((String subject) {
    final List<SubjectResult> subjectRows = <SubjectResult>[
      for (final StudentResultRecord student in students)
        ...student.subjectResults.where(
          (SubjectResult result) => result.subject == subject,
        ),
    ];
    final List<String> classes =
        students
            .where(
              (StudentResultRecord student) => student.subjectResults.any(
                (SubjectResult result) => result.subject == subject,
              ),
            )
            .map((StudentResultRecord student) => student.className)
            .toSet()
            .toList()
          ..sort();
    final String teacherName =
        panel.subjectTeacherOverrides[subject] ??
        _teacherForSubject(teachers, subject);
    final double passRate = subjectRows.isEmpty
        ? 0
        : subjectRows
                  .where((SubjectResult result) => result.averageScore >= 30)
                  .length /
              subjectRows.length *
              100;
    return HeadmasterSubjectSummary(
      code: _subjectCode(subject),
      subject: subject,
      teacherName: teacherName.isEmpty ? 'Unassigned' : teacherName,
      classes: classes,
      averageScore: _average(
        subjectRows.map((SubjectResult result) => result.averageScore),
      ),
      passRate: double.parse(passRate.toStringAsFixed(1)),
    );
  }).toList()..sort(
    (HeadmasterSubjectSummary a, HeadmasterSubjectSummary b) =>
        a.subject.compareTo(b.subject),
  );
});

final Provider<HeadmasterOverview> headmasterOverviewProvider =
    Provider<HeadmasterOverview>((Ref ref) {
      final HeadmasterPanelState panel = ref.watch(headmasterPanelProvider);
      final List<StudentResultRecord> students = ref.watch(
        headmasterActiveStudentsProvider,
      );
      final List<TeacherAccount> teachers = ref.watch(
        headmasterActiveTeachersProvider,
      );
      final List<HeadmasterSubjectSummary> subjects = ref.watch(
        headmasterSubjectSummariesProvider,
      );
      final List<HeadmasterClassSummary> classes = ref.watch(
        headmasterClassSummariesProvider,
      );
      final DateTime now = DateTime.now();
      final DateTime startOfToday = DateTime(now.year, now.month, now.day);
      final DateTime startOfWeek = startOfToday.subtract(
        Duration(days: now.weekday - 1),
      );
      final double feesRequired = panel.feeAccounts.fold<double>(
        0,
        (double sum, HeadmasterFeeAccount account) =>
            sum + account.requiredAmount,
      );
      final double feesCollected = panel.feeAccounts.fold<double>(
        0,
        (double sum, HeadmasterFeeAccount account) => sum + account.paidAmount,
      );

      return HeadmasterOverview(
        totalStudents: students.length,
        totalTeachers: teachers.length,
        totalClasses: classes.length,
        totalSubjects: subjects.length,
        maleStudents: students.where((StudentResultRecord record) {
          return record.gender == StudentGender.male;
        }).length,
        femaleStudents: students.where((StudentResultRecord record) {
          return record.gender == StudentGender.female;
        }).length,
        newToday: students.where((StudentResultRecord record) {
          final DateTime? registeredAt = record.registeredAt;
          return registeredAt != null && !registeredAt.isBefore(startOfToday);
        }).length,
        newThisWeek: students.where((StudentResultRecord record) {
          final DateTime? registeredAt = record.registeredAt;
          return registeredAt != null && !registeredAt.isBefore(startOfWeek);
        }).length,
        attendancePercentage: _average(
          students.map((StudentResultRecord record) => record.attendanceRate),
        ),
        feesRequired: feesRequired,
        feesCollected: feesCollected,
        feesOutstanding: (feesRequired - feesCollected)
            .clamp(0, feesRequired)
            .toDouble(),
        recentActivities: panel.auditEvents.take(8).toList(growable: false),
      );
    });

class HeadmasterPanelController extends StateNotifier<HeadmasterPanelState> {
  HeadmasterPanelController()
    : super(
        const HeadmasterPanelState(
          feeAccounts: <HeadmasterFeeAccount>[],
          announcements: <HeadmasterAnnouncement>[],
          userAccounts: <HeadmasterUserAccount>[],
          auditEvents: <HeadmasterAuditEvent>[],
          localClasses: <String>[],
          classTeacherOverrides: <String, String>{},
          subjectTeacherOverrides: <String, String>{},
          approvedResultIds: <String>{},
          lastSeedSignature: '',
        ),
      );

  void syncFromAdmin(SchoolAdminState admin) {
    final String signature =
        '${admin.schoolName}:${admin.studentResults.length}:${admin.teachers.length}:'
        '${admin.studentResults.map((StudentResultRecord record) => '${record.id}-${record.isActive}').join('|')}:'
        '${admin.teachers.map((TeacherAccount teacher) => '${teacher.id}-${teacher.isActive}').join('|')}';
    if (signature == state.lastSeedSignature) {
      return;
    }

    state = state.copyWith(
      feeAccounts: _mergeFeeAccounts(
        existing: state.feeAccounts,
        students: admin.studentResults,
      ),
      announcements: state.announcements.isEmpty
          ? _seedAnnouncements(admin)
          : state.announcements,
      userAccounts: _mergeUserAccounts(
        existing: state.userAccounts,
        admin: admin,
      ),
      auditEvents: state.auditEvents.isEmpty
          ? _seedAuditEvents(admin)
          : state.auditEvents,
      lastSeedSignature: signature,
    );
  }

  void addAuditEvent({
    required String actor,
    required String action,
    required String target,
    required String detail,
    HeadmasterAuditStatus status = HeadmasterAuditStatus.success,
  }) {
    final DateTime now = DateTime.now();
    state = state.copyWith(
      auditEvents: <HeadmasterAuditEvent>[
        HeadmasterAuditEvent(
          id: 'audit-${now.microsecondsSinceEpoch}',
          actor: actor,
          action: action,
          target: target,
          status: status,
          createdAt: now,
          detail: detail,
        ),
        ...state.auditEvents,
      ],
    );
  }

  void addAnnouncement({
    required String title,
    required String body,
    required String audience,
  }) {
    final DateTime now = DateTime.now();
    state = state.copyWith(
      announcements: <HeadmasterAnnouncement>[
        HeadmasterAnnouncement(
          id: 'announcement-${now.microsecondsSinceEpoch}',
          title: title,
          body: body,
          audience: audience,
          createdAt: now,
          published: true,
        ),
        ...state.announcements,
      ],
    );
    addAuditEvent(
      actor: 'Headmaster',
      action: 'Published announcement',
      target: audience,
      detail: title,
    );
  }

  void toggleAnnouncementPublished(String id) {
    state = state.copyWith(
      announcements: state.announcements
          .map((HeadmasterAnnouncement item) {
            if (item.id != id) {
              return item;
            }
            return item.copyWith(published: !item.published);
          })
          .toList(growable: false),
    );
  }

  void setUserActive(String id, bool active) {
    state = state.copyWith(
      userAccounts: state.userAccounts
          .map((HeadmasterUserAccount account) {
            if (account.id != id) {
              return account;
            }
            return account.copyWith(active: active);
          })
          .toList(growable: false),
    );
    addAuditEvent(
      actor: 'Headmaster',
      action: active ? 'Activated user' : 'Deactivated user',
      target: id,
      detail: 'User account status changed.',
    );
  }

  void requirePasswordReset(String id) {
    state = state.copyWith(
      userAccounts: state.userAccounts
          .map((HeadmasterUserAccount account) {
            if (account.id != id) {
              return account;
            }
            return account.copyWith(passwordResetRequired: true);
          })
          .toList(growable: false),
    );
    addAuditEvent(
      actor: 'Headmaster',
      action: 'Reset password',
      target: id,
      detail: 'Password reset required on next sign-in.',
    );
  }

  void createLocalClass(String className) {
    final String normalized = className.trim();
    if (normalized.isEmpty || state.localClasses.contains(normalized)) {
      return;
    }
    state = state.copyWith(
      localClasses: <String>[...state.localClasses, normalized]..sort(),
    );
    addAuditEvent(
      actor: 'Headmaster',
      action: 'Created class',
      target: normalized,
      detail: 'Local class/stream created in the panel.',
    );
  }

  void assignClassTeacher(String className, String teacherName) {
    state = state.copyWith(
      classTeacherOverrides: <String, String>{
        ...state.classTeacherOverrides,
        className: teacherName,
      },
    );
    addAuditEvent(
      actor: 'Headmaster',
      action: 'Assigned class teacher',
      target: className,
      detail: teacherName,
    );
  }

  void assignSubjectTeacher(String subject, String teacherName) {
    state = state.copyWith(
      subjectTeacherOverrides: <String, String>{
        ...state.subjectTeacherOverrides,
        subject: teacherName,
      },
    );
    addAuditEvent(
      actor: 'Headmaster',
      action: 'Assigned subject teacher',
      target: subject,
      detail: teacherName,
    );
  }

  void approveResult(String studentId, String studentName) {
    state = state.copyWith(
      approvedResultIds: <String>{...state.approvedResultIds, studentId},
    );
    addAuditEvent(
      actor: 'Headmaster',
      action: 'Approved results',
      target: studentName,
      detail: 'Student result card approved for publishing.',
    );
  }
}

List<HeadmasterFeeAccount> _mergeFeeAccounts({
  required List<HeadmasterFeeAccount> existing,
  required List<StudentResultRecord> students,
}) {
  final Map<String, HeadmasterFeeAccount> existingByStudent =
      <String, HeadmasterFeeAccount>{
        for (final HeadmasterFeeAccount account in existing)
          account.studentId: account,
      };
  return students
      .map((StudentResultRecord student) {
        final HeadmasterFeeAccount? current = existingByStudent[student.id];
        if (current != null) {
          return HeadmasterFeeAccount(
            studentId: student.id,
            studentName: student.studentName,
            className: student.className,
            requiredAmount: current.requiredAmount,
            paidAmount: current.paidAmount,
            dueDate: current.dueDate,
          );
        }
        final int seed = student.admissionNumber.hashCode.abs();
        const double requiredAmount = 1200000;
        final double paidAmount = switch (seed % 4) {
          0 => requiredAmount,
          1 => requiredAmount * 0.72,
          2 => requiredAmount * 0.35,
          _ => 0,
        };
        return HeadmasterFeeAccount(
          studentId: student.id,
          studentName: student.studentName,
          className: student.className,
          requiredAmount: requiredAmount,
          paidAmount: paidAmount,
          dueDate: DateTime(DateTime.now().year, 9, 30),
        );
      })
      .toList(growable: false);
}

List<HeadmasterAnnouncement> _seedAnnouncements(SchoolAdminState admin) {
  final DateTime now = DateTime.now();
  return <HeadmasterAnnouncement>[
    HeadmasterAnnouncement(
      id: 'announcement-report-window',
      title: 'Result approval window is open',
      body:
          'Teachers should finish result uploads before leadership approval closes.',
      audience: 'Teachers',
      createdAt: now.subtract(const Duration(hours: 3)),
      published: true,
    ),
    HeadmasterAnnouncement(
      id: 'announcement-attendance',
      title: 'Daily attendance monitoring',
      body: 'Class teachers should confirm absent and late students by noon.',
      audience: 'All Staff',
      createdAt: now.subtract(const Duration(days: 1)),
      published: true,
    ),
  ];
}

List<HeadmasterUserAccount> _mergeUserAccounts({
  required List<HeadmasterUserAccount> existing,
  required SchoolAdminState admin,
}) {
  final Map<String, HeadmasterUserAccount> existingById =
      <String, HeadmasterUserAccount>{
        for (final HeadmasterUserAccount account in existing)
          account.id: account,
      };
  final DateTime now = DateTime.now();
  final List<HeadmasterUserAccount> accounts = <HeadmasterUserAccount>[
    HeadmasterUserAccount(
      id: 'headmaster',
      name: admin.headmasterName,
      email: 'headmaster@school.local',
      role: HeadmasterAccountRole.headmaster,
      active: true,
      passwordResetRequired: false,
      permissions: const <String>[
        'All dashboards',
        'Approve results',
        'Manage users',
        'Audit logs',
      ],
      lastLoginAt: now.subtract(const Duration(minutes: 26)),
    ),
    for (final TeacherAccount teacher in admin.teachers)
      HeadmasterUserAccount(
        id: teacher.id,
        name: teacher.name,
        email: teacher.email,
        role: HeadmasterAccountRole.teacher,
        active: teacher.isActive,
        passwordResetRequired: false,
        permissions: <String>[
          if (teacher.canUploadResults) 'Upload results',
          if (teacher.canEditResults) 'Edit marks',
          if (teacher.canRegisterStudents) 'Register students',
          if (teacher.canDownloadResults) 'Download reports',
        ],
        lastLoginAt: now.subtract(Duration(days: 1 + teacher.name.length % 5)),
      ),
    HeadmasterUserAccount(
      id: 'accountant',
      name: 'School Accountant',
      email: 'accountant@school.local',
      role: HeadmasterAccountRole.accountant,
      active: true,
      passwordResetRequired: false,
      permissions: const <String>['Fees', 'Finance reports'],
      lastLoginAt: now.subtract(const Duration(hours: 5)),
    ),
    HeadmasterUserAccount(
      id: 'registrar',
      name: 'School Registrar',
      email: 'registrar@school.local',
      role: HeadmasterAccountRole.registrar,
      active: true,
      passwordResetRequired: true,
      permissions: const <String>['Students', 'Registration reports'],
      lastLoginAt: now.subtract(const Duration(days: 3)),
    ),
    HeadmasterUserAccount(
      id: 'parent-portal',
      name: 'Parent Portal',
      email: 'parents@school.local',
      role: HeadmasterAccountRole.parent,
      active: true,
      passwordResetRequired: false,
      permissions: const <String>['View own child'],
      lastLoginAt: null,
    ),
    HeadmasterUserAccount(
      id: 'student-portal',
      name: 'Student Portal',
      email: 'students@school.local',
      role: HeadmasterAccountRole.student,
      active: true,
      passwordResetRequired: false,
      permissions: const <String>['View own results'],
      lastLoginAt: null,
    ),
    HeadmasterUserAccount(
      id: 'admin-office',
      name: 'Admin Office',
      email: 'admin@school.local',
      role: HeadmasterAccountRole.admin,
      active: true,
      passwordResetRequired: false,
      permissions: const <String>['Students', 'Teachers', 'Reports'],
      lastLoginAt: now.subtract(const Duration(hours: 2)),
    ),
  ];

  return accounts
      .map((HeadmasterUserAccount account) {
        final HeadmasterUserAccount? current = existingById[account.id];
        if (current == null) {
          return account;
        }
        return account.copyWith(
          active: current.active,
          passwordResetRequired: current.passwordResetRequired,
          permissions: current.permissions,
          lastLoginAt: current.lastLoginAt,
        );
      })
      .toList(growable: false);
}

List<HeadmasterAuditEvent> _seedAuditEvents(SchoolAdminState admin) {
  final DateTime now = DateTime.now();
  final String sampleStudent = admin.studentResults.isEmpty
      ? 'student record'
      : admin.studentResults.first.studentName;
  final String sampleTeacher = admin.teachers.isEmpty
      ? 'Teacher account'
      : admin.teachers.first.name;
  return <HeadmasterAuditEvent>[
    HeadmasterAuditEvent(
      id: 'audit-login',
      actor: admin.headmasterName,
      action: 'Logged in',
      target: 'Headmaster Panel',
      status: HeadmasterAuditStatus.success,
      createdAt: now.subtract(const Duration(minutes: 18)),
      detail: 'Login history captured for the current leadership session.',
    ),
    HeadmasterAuditEvent(
      id: 'audit-student-edit',
      actor: 'Admin Office',
      action: 'Edited student record',
      target: sampleStudent,
      status: HeadmasterAuditStatus.success,
      createdAt: now.subtract(const Duration(hours: 1)),
      detail: 'Guardian/contact and class profile reviewed.',
    ),
    HeadmasterAuditEvent(
      id: 'audit-marks',
      actor: sampleTeacher,
      action: 'Edited marks',
      target: 'Class result sheet',
      status: HeadmasterAuditStatus.warning,
      createdAt: now.subtract(const Duration(hours: 3)),
      detail: 'Mark changes remain visible for approval before publishing.',
    ),
    HeadmasterAuditEvent(
      id: 'audit-failed-login',
      actor: 'Unknown user',
      action: 'Failed login attempt',
      target: 'Teacher portal',
      status: HeadmasterAuditStatus.failed,
      createdAt: now.subtract(const Duration(hours: 8)),
      detail: 'Invalid password attempt blocked by role-based access.',
    ),
    HeadmasterAuditEvent(
      id: 'audit-backup',
      actor: 'System',
      action: 'Backup record created',
      target: admin.schoolName,
      status: HeadmasterAuditStatus.success,
      createdAt: now.subtract(const Duration(days: 1)),
      detail: 'Daily backup checkpoint stored for restore readiness.',
    ),
  ];
}

String _teacherForClass(List<TeacherAccount> teachers, String className) {
  for (final TeacherAccount teacher in teachers) {
    if (teacher.isActive && teacher.effectiveClasses.contains(className)) {
      return teacher.name;
    }
  }
  return '';
}

String _teacherForSubject(List<TeacherAccount> teachers, String subject) {
  for (final TeacherAccount teacher in teachers) {
    if (teacher.isActive && teacher.effectiveSubjects.contains(subject)) {
      return teacher.name;
    }
  }
  return '';
}

String _subjectCode(String subject) {
  final String normalized = subject.toUpperCase().replaceAll(
    RegExp(r'[^A-Z]'),
    '',
  );
  final String prefix = normalized.length >= 3
      ? normalized.substring(0, 3)
      : normalized.padRight(3, 'X');
  final int number = 100 + (subject.hashCode.abs() % 800);
  if (subject.toLowerCase().contains('mathematics')) {
    return 'MAT101';
  }
  if (subject.toLowerCase().contains('english')) {
    return 'ENG101';
  }
  if (subject.toLowerCase().contains('physics')) {
    return 'PHY101';
  }
  return '$prefix$number';
}

double _average(Iterable<double> values) {
  final List<double> list = values.toList();
  if (list.isEmpty) {
    return 0;
  }
  return double.parse(
    (list.fold<double>(0, (double sum, double value) => sum + value) /
            list.length)
        .toStringAsFixed(1),
  );
}

const List<String> _standardClassNames = <String>[
  'Form 1 A',
  'Form 1 B',
  'Form 2 A',
  'Form 2 B',
  'Form 3 A',
  'Form 3 B',
  'Form 4 A',
  'Form 4 B',
];
