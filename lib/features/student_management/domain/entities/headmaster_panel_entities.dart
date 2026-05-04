import 'package:flutter/foundation.dart';

import 'education_entities.dart';

enum HeadmasterPanelSection {
  dashboard,
  students,
  teachers,
  classes,
  subjects,
  attendance,
  results,
  fees,
  reports,
  announcements,
  usersRoles,
  settings,
  auditLogs,
}

enum HeadmasterGenderFilter { all, female, male }

enum HeadmasterStatusFilter { active, deactivated, all }

enum HeadmasterRegistrationOrder { femaleThenMale, femaleOnly, maleOnly }

enum HeadmasterFeeStatus { paid, partial, outstanding }

enum HeadmasterAttendanceStatus { present, absent, late }

enum HeadmasterAuditStatus { success, warning, failed }

enum HeadmasterAccountRole {
  headmaster,
  admin,
  teacher,
  accountant,
  registrar,
  parent,
  student,
}

extension HeadmasterPanelSectionX on HeadmasterPanelSection {
  String get routeKey {
    switch (this) {
      case HeadmasterPanelSection.dashboard:
        return 'dashboard';
      case HeadmasterPanelSection.students:
        return 'students';
      case HeadmasterPanelSection.teachers:
        return 'teachers';
      case HeadmasterPanelSection.classes:
        return 'classes';
      case HeadmasterPanelSection.subjects:
        return 'subjects';
      case HeadmasterPanelSection.attendance:
        return 'attendance';
      case HeadmasterPanelSection.results:
        return 'results';
      case HeadmasterPanelSection.fees:
        return 'fees';
      case HeadmasterPanelSection.reports:
        return 'reports';
      case HeadmasterPanelSection.announcements:
        return 'announcements';
      case HeadmasterPanelSection.usersRoles:
        return 'users-roles';
      case HeadmasterPanelSection.settings:
        return 'settings';
      case HeadmasterPanelSection.auditLogs:
        return 'audit-logs';
    }
  }

  String get label {
    switch (this) {
      case HeadmasterPanelSection.dashboard:
        return 'Dashboard';
      case HeadmasterPanelSection.students:
        return 'Students';
      case HeadmasterPanelSection.teachers:
        return 'Teachers';
      case HeadmasterPanelSection.classes:
        return 'Classes';
      case HeadmasterPanelSection.subjects:
        return 'Subjects';
      case HeadmasterPanelSection.attendance:
        return 'Attendance';
      case HeadmasterPanelSection.results:
        return 'Results';
      case HeadmasterPanelSection.fees:
        return 'Fees';
      case HeadmasterPanelSection.reports:
        return 'Reports';
      case HeadmasterPanelSection.announcements:
        return 'Announcements';
      case HeadmasterPanelSection.usersRoles:
        return 'Users & Roles';
      case HeadmasterPanelSection.settings:
        return 'Settings';
      case HeadmasterPanelSection.auditLogs:
        return 'Audit Logs';
    }
  }

  String get subtitle {
    switch (this) {
      case HeadmasterPanelSection.dashboard:
        return 'Whole school command overview';
      case HeadmasterPanelSection.students:
        return 'Directory, profiles, guardians';
      case HeadmasterPanelSection.teachers:
        return 'Staff, subjects, attendance';
      case HeadmasterPanelSection.classes:
        return 'Streams, class teachers, performance';
      case HeadmasterPanelSection.subjects:
        return 'Codes, assignments, performance';
      case HeadmasterPanelSection.attendance:
        return 'Daily and monthly monitoring';
      case HeadmasterPanelSection.results:
        return 'Marks, approvals, report cards';
      case HeadmasterPanelSection.fees:
        return 'Payments and balances';
      case HeadmasterPanelSection.reports:
        return 'PDF, Excel, CSV, print';
      case HeadmasterPanelSection.announcements:
        return 'School notices';
      case HeadmasterPanelSection.usersRoles:
        return 'Accounts and permissions';
      case HeadmasterPanelSection.settings:
        return 'Theme, policies, backup';
      case HeadmasterPanelSection.auditLogs:
        return 'Security and activity trail';
    }
  }

  static HeadmasterPanelSection fromRouteKey(String? value) {
    for (final HeadmasterPanelSection section
        in HeadmasterPanelSection.values) {
      if (section.routeKey == value) {
        return section;
      }
    }
    return HeadmasterPanelSection.dashboard;
  }
}

extension HeadmasterAccountRoleX on HeadmasterAccountRole {
  String get label {
    switch (this) {
      case HeadmasterAccountRole.headmaster:
        return 'Headmaster';
      case HeadmasterAccountRole.admin:
        return 'Admin';
      case HeadmasterAccountRole.teacher:
        return 'Teacher';
      case HeadmasterAccountRole.accountant:
        return 'Accountant';
      case HeadmasterAccountRole.registrar:
        return 'Registrar';
      case HeadmasterAccountRole.parent:
        return 'Parent';
      case HeadmasterAccountRole.student:
        return 'Student';
    }
  }
}

extension HeadmasterFeeStatusX on HeadmasterFeeStatus {
  String get label {
    switch (this) {
      case HeadmasterFeeStatus.paid:
        return 'Paid';
      case HeadmasterFeeStatus.partial:
        return 'Partial';
      case HeadmasterFeeStatus.outstanding:
        return 'Outstanding';
    }
  }
}

extension HeadmasterAttendanceStatusX on HeadmasterAttendanceStatus {
  String get label {
    switch (this) {
      case HeadmasterAttendanceStatus.present:
        return 'Present';
      case HeadmasterAttendanceStatus.absent:
        return 'Absent';
      case HeadmasterAttendanceStatus.late:
        return 'Late';
    }
  }
}

extension HeadmasterAuditStatusX on HeadmasterAuditStatus {
  String get label {
    switch (this) {
      case HeadmasterAuditStatus.success:
        return 'Success';
      case HeadmasterAuditStatus.warning:
        return 'Warning';
      case HeadmasterAuditStatus.failed:
        return 'Failed';
    }
  }
}

@immutable
class HeadmasterFeeAccount {
  const HeadmasterFeeAccount({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.requiredAmount,
    required this.paidAmount,
    required this.dueDate,
  });

  final String studentId;
  final String studentName;
  final String className;
  final double requiredAmount;
  final double paidAmount;
  final DateTime dueDate;

  double get outstandingAmount =>
      (requiredAmount - paidAmount).clamp(0, requiredAmount).toDouble();

  HeadmasterFeeStatus get status {
    if (outstandingAmount <= 0) {
      return HeadmasterFeeStatus.paid;
    }
    if (paidAmount > 0) {
      return HeadmasterFeeStatus.partial;
    }
    return HeadmasterFeeStatus.outstanding;
  }

  double get collectionRate {
    if (requiredAmount <= 0) {
      return 0;
    }
    return paidAmount / requiredAmount * 100;
  }
}

@immutable
class HeadmasterAttendanceRecord {
  const HeadmasterAttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.gender,
    required this.status,
    required this.rate,
    required this.recordedAt,
  });

  final String studentId;
  final String studentName;
  final String className;
  final StudentGender gender;
  final HeadmasterAttendanceStatus status;
  final double rate;
  final DateTime recordedAt;
}

@immutable
class HeadmasterAnnouncement {
  const HeadmasterAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.createdAt,
    required this.published,
  });

  final String id;
  final String title;
  final String body;
  final String audience;
  final DateTime createdAt;
  final bool published;

  HeadmasterAnnouncement copyWith({
    String? id,
    String? title,
    String? body,
    String? audience,
    DateTime? createdAt,
    bool? published,
  }) {
    return HeadmasterAnnouncement(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      audience: audience ?? this.audience,
      createdAt: createdAt ?? this.createdAt,
      published: published ?? this.published,
    );
  }
}

@immutable
class HeadmasterUserAccount {
  const HeadmasterUserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.passwordResetRequired,
    required this.permissions,
    required this.lastLoginAt,
  });

  final String id;
  final String name;
  final String email;
  final HeadmasterAccountRole role;
  final bool active;
  final bool passwordResetRequired;
  final List<String> permissions;
  final DateTime? lastLoginAt;

  HeadmasterUserAccount copyWith({
    String? id,
    String? name,
    String? email,
    HeadmasterAccountRole? role,
    bool? active,
    bool? passwordResetRequired,
    List<String>? permissions,
    DateTime? lastLoginAt,
    bool clearLastLoginAt = false,
  }) {
    return HeadmasterUserAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      active: active ?? this.active,
      passwordResetRequired:
          passwordResetRequired ?? this.passwordResetRequired,
      permissions: permissions ?? this.permissions,
      lastLoginAt: clearLastLoginAt ? null : (lastLoginAt ?? this.lastLoginAt),
    );
  }
}

@immutable
class HeadmasterAuditEvent {
  const HeadmasterAuditEvent({
    required this.id,
    required this.actor,
    required this.action,
    required this.target,
    required this.status,
    required this.createdAt,
    required this.detail,
  });

  final String id;
  final String actor;
  final String action;
  final String target;
  final HeadmasterAuditStatus status;
  final DateTime createdAt;
  final String detail;
}

@immutable
class HeadmasterClassSummary {
  const HeadmasterClassSummary({
    required this.className,
    required this.teacherName,
    required this.totalStudents,
    required this.averageScore,
    required this.attendanceRate,
    required this.streamLabel,
  });

  final String className;
  final String teacherName;
  final int totalStudents;
  final double averageScore;
  final double attendanceRate;
  final String streamLabel;
}

@immutable
class HeadmasterSubjectSummary {
  const HeadmasterSubjectSummary({
    required this.code,
    required this.subject,
    required this.teacherName,
    required this.classes,
    required this.averageScore,
    required this.passRate,
  });

  final String code;
  final String subject;
  final String teacherName;
  final List<String> classes;
  final double averageScore;
  final double passRate;
}

@immutable
class HeadmasterOverview {
  const HeadmasterOverview({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalClasses,
    required this.totalSubjects,
    required this.maleStudents,
    required this.femaleStudents,
    required this.newToday,
    required this.newThisWeek,
    required this.attendancePercentage,
    required this.feesRequired,
    required this.feesCollected,
    required this.feesOutstanding,
    required this.recentActivities,
  });

  final int totalStudents;
  final int totalTeachers;
  final int totalClasses;
  final int totalSubjects;
  final int maleStudents;
  final int femaleStudents;
  final int newToday;
  final int newThisWeek;
  final double attendancePercentage;
  final double feesRequired;
  final double feesCollected;
  final double feesOutstanding;
  final List<HeadmasterAuditEvent> recentActivities;

  double get feeCollectionRate {
    if (feesRequired <= 0) {
      return 0;
    }
    return feesCollected / feesRequired * 100;
  }
}

@immutable
class HeadmasterPanelState {
  const HeadmasterPanelState({
    required this.feeAccounts,
    required this.announcements,
    required this.userAccounts,
    required this.auditEvents,
    required this.localClasses,
    required this.classTeacherOverrides,
    required this.subjectTeacherOverrides,
    required this.approvedResultIds,
    required this.lastSeedSignature,
  });

  final List<HeadmasterFeeAccount> feeAccounts;
  final List<HeadmasterAnnouncement> announcements;
  final List<HeadmasterUserAccount> userAccounts;
  final List<HeadmasterAuditEvent> auditEvents;
  final List<String> localClasses;
  final Map<String, String> classTeacherOverrides;
  final Map<String, String> subjectTeacherOverrides;
  final Set<String> approvedResultIds;
  final String lastSeedSignature;

  HeadmasterPanelState copyWith({
    List<HeadmasterFeeAccount>? feeAccounts,
    List<HeadmasterAnnouncement>? announcements,
    List<HeadmasterUserAccount>? userAccounts,
    List<HeadmasterAuditEvent>? auditEvents,
    List<String>? localClasses,
    Map<String, String>? classTeacherOverrides,
    Map<String, String>? subjectTeacherOverrides,
    Set<String>? approvedResultIds,
    String? lastSeedSignature,
  }) {
    return HeadmasterPanelState(
      feeAccounts: feeAccounts ?? this.feeAccounts,
      announcements: announcements ?? this.announcements,
      userAccounts: userAccounts ?? this.userAccounts,
      auditEvents: auditEvents ?? this.auditEvents,
      localClasses: localClasses ?? this.localClasses,
      classTeacherOverrides:
          classTeacherOverrides ?? this.classTeacherOverrides,
      subjectTeacherOverrides:
          subjectTeacherOverrides ?? this.subjectTeacherOverrides,
      approvedResultIds: approvedResultIds ?? this.approvedResultIds,
      lastSeedSignature: lastSeedSignature ?? this.lastSeedSignature,
    );
  }
}
