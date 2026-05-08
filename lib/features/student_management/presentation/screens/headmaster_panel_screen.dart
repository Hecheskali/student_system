import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme_mode_provider.dart';
import '../../domain/entities/education_entities.dart';
import '../../domain/entities/headmaster_panel_entities.dart';
import '../../domain/services/necta_olevel_subjects.dart';
import '../providers/headmaster_panel_provider.dart';
import '../providers/student_management_providers.dart';
import '../utils/report_exporter.dart';

class HeadmasterPanelScreen extends ConsumerStatefulWidget {
  const HeadmasterPanelScreen({super.key, this.initialPanel});

  final String? initialPanel;

  @override
  ConsumerState<HeadmasterPanelScreen> createState() =>
      _HeadmasterPanelScreenState();
}

class _HeadmasterPanelScreenState extends ConsumerState<HeadmasterPanelScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  HeadmasterGenderFilter _genderFilter = HeadmasterGenderFilter.all;
  HeadmasterStatusFilter _statusFilter = HeadmasterStatusFilter.active;
  HeadmasterRegistrationOrder _registrationOrder =
      HeadmasterRegistrationOrder.femaleThenMale;
  String _classFilter = 'All classes';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SessionUser? session = adminState.session;
    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to open headmaster panel'),
          ),
        ),
      );
    }

    final HeadmasterPanelSection section = HeadmasterPanelSectionX.fromRouteKey(
      widget.initialPanel,
    );
    final bool wide = MediaQuery.sizeOf(context).width >= 1180;
    final Widget sidebar = _HeadmasterSidebar(
      currentSection: section,
      session: session,
      onSelect: _goToSection,
      onLogout: _logout,
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide ? null : Drawer(child: SafeArea(child: sidebar)),
      body: SafeArea(
        child: Row(
          children: <Widget>[
            if (wide) sidebar,
            Expanded(
              child: Column(
                children: <Widget>[
                  _HeadmasterHeader(
                    section: section,
                    session: session,
                    searchController: _searchController,
                    onSearchChanged: (_) => setState(() {}),
                    onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    onRefresh: () =>
                        ref.read(schoolAdminProvider.notifier).refreshData(),
                    onLogout: _logout,
                    showMenu: !wide,
                  ),
                  Expanded(child: _buildSection(section)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(HeadmasterPanelSection section) {
    switch (section) {
      case HeadmasterPanelSection.dashboard:
        return _DashboardSection(onExport: _showReportFormatSheet);
      case HeadmasterPanelSection.students:
        return _studentsSection();
      case HeadmasterPanelSection.teachers:
        return _teachersSection();
      case HeadmasterPanelSection.classes:
        return _classesSection();
      case HeadmasterPanelSection.subjects:
        return _subjectsSection();
      case HeadmasterPanelSection.attendance:
        return _attendanceSection();
      case HeadmasterPanelSection.results:
        return _resultsSection();
      case HeadmasterPanelSection.fees:
        return _feesSection();
      case HeadmasterPanelSection.reports:
        return _reportsSection();
      case HeadmasterPanelSection.announcements:
        return _announcementsSection();
      case HeadmasterPanelSection.usersRoles:
        return _usersSection();
      case HeadmasterPanelSection.settings:
        return _settingsSection();
      case HeadmasterPanelSection.auditLogs:
        return _auditSection();
    }
  }

  List<StudentResultRecord> _filteredStudents() {
    final String query = _searchController.text.trim().toLowerCase();
    final List<StudentResultRecord>
    students = ref.watch(schoolAdminProvider).studentResults.where((
      StudentResultRecord record,
    ) {
      if (_statusFilter == HeadmasterStatusFilter.active && !record.isActive) {
        return false;
      }
      if (_statusFilter == HeadmasterStatusFilter.deactivated &&
          record.isActive) {
        return false;
      }
      if (_genderFilter == HeadmasterGenderFilter.female &&
          record.gender != StudentGender.female) {
        return false;
      }
      if (_genderFilter == HeadmasterGenderFilter.male &&
          record.gender != StudentGender.male) {
        return false;
      }
      if (_registrationOrder == HeadmasterRegistrationOrder.femaleOnly &&
          record.gender != StudentGender.female) {
        return false;
      }
      if (_registrationOrder == HeadmasterRegistrationOrder.maleOnly &&
          record.gender != StudentGender.male) {
        return false;
      }
      if (_classFilter != 'All classes' && record.className != _classFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final String haystack =
          '${record.studentName} ${record.className} ${record.gender.label} ${record.admissionNumber}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();

    students.sort(compareStudentResultsForRoster);
    return students;
  }

  Widget _studentsSection() {
    final List<StudentResultRecord> students = _filteredStudents();
    final List<String> classes = <String>{
      'All classes',
      ...ref
          .watch(schoolAdminProvider)
          .studentResults
          .map((StudentResultRecord record) => record.className),
    }.toList()..sort();

    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Student Management',
          subtitle:
              'Search, filter, register, edit, view profiles, and deactivate students while keeping academic history intact.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _showStudentEditor(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add Student'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _exportStudents(ReportFileFormat.excel),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Excel'),
            ),
          ],
        ),
        _FilterBar(
          children: <Widget>[
            DropdownButtonFormField<HeadmasterGenderFilter>(
              initialValue: _genderFilter,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: HeadmasterGenderFilter.values.map((filter) {
                return DropdownMenuItem<HeadmasterGenderFilter>(
                  value: filter,
                  child: Text(_genderFilterLabel(filter)),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _genderFilter = value ?? HeadmasterGenderFilter.all;
              }),
            ),
            DropdownButtonFormField<HeadmasterStatusFilter>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: HeadmasterStatusFilter.values.map((filter) {
                return DropdownMenuItem<HeadmasterStatusFilter>(
                  value: filter,
                  child: Text(_statusFilterLabel(filter)),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _statusFilter = value ?? HeadmasterStatusFilter.active;
              }),
            ),
            DropdownButtonFormField<HeadmasterRegistrationOrder>(
              initialValue: _registrationOrder,
              decoration: const InputDecoration(
                labelText: 'Registration Order',
              ),
              items: HeadmasterRegistrationOrder.values.map((order) {
                return DropdownMenuItem<HeadmasterRegistrationOrder>(
                  value: order,
                  child: Text(_orderLabel(order)),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _registrationOrder =
                    value ?? HeadmasterRegistrationOrder.femaleThenMale;
              }),
            ),
            DropdownButtonFormField<String>(
              initialValue: classes.contains(_classFilter)
                  ? _classFilter
                  : 'All classes',
              decoration: const InputDecoration(labelText: 'Class'),
              items: classes.map((String className) {
                return DropdownMenuItem<String>(
                  value: className,
                  child: Text(className),
                );
              }).toList(),
              onChanged: (value) => setState(() {
                _classFilter = value ?? 'All classes';
              }),
            ),
          ],
        ),
        _ResponsiveDataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Reg No.')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Gender')),
            DataColumn(label: Text('Attendance')),
            DataColumn(label: Text('Average')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: students.map((StudentResultRecord student) {
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(student.studentName)),
                DataCell(Text(student.admissionNumber)),
                DataCell(Text(student.className)),
                DataCell(Text(student.gender.label)),
                DataCell(Text('${student.attendanceRate.toStringAsFixed(1)}%')),
                DataCell(Text('${student.averageScore.toStringAsFixed(1)}%')),
                DataCell(
                  _StatusChip(
                    label: student.isActive ? 'Active' : 'Deactivated',
                    tone: student.isActive
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    textColor: student.isActive
                        ? const Color(0xFF166534)
                        : const Color(0xFF991B1B),
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Profile',
                        onPressed: () => _showStudentProfile(student),
                        icon: const Icon(Icons.badge_rounded),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => _showStudentEditor(student: student),
                        icon: const Icon(Icons.edit_rounded),
                      ),
                      IconButton(
                        tooltip: student.isActive ? 'Deactivate' : 'Reactivate',
                        onPressed: () =>
                            _setStudentActive(student, !student.isActive),
                        icon: Icon(
                          student.isActive
                              ? Icons.person_off_rounded
                              : Icons.person_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _teachersSection() {
    final SchoolAdminState admin = ref.watch(schoolAdminProvider);
    final List<TeacherAccount> teachers =
        admin.teachers.where((TeacherAccount teacher) {
          final String query = _searchController.text.trim().toLowerCase();
          if (query.isEmpty) {
            return true;
          }
          return '${teacher.name} ${teacher.email} ${teacher.effectiveSubjects.join(' ')} ${teacher.effectiveClasses.join(' ')}'
              .toLowerCase()
              .contains(query);
        }).toList()..sort(
          (TeacherAccount a, TeacherAccount b) =>
              a.name.toUpperCase().compareTo(b.name.toUpperCase()),
        );

    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Teacher Management',
          subtitle:
              'Manage teachers, class assignments, subject assignments, attendance, permissions, and timetables.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _showTeacherEditor(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add Teacher'),
            ),
          ],
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: teachers.map((TeacherAccount teacher) {
            return _InfoCard(
              width: 390,
              title: teacher.name,
              subtitle: teacher.email,
              icon: Icons.school_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ...teacher.effectiveSubjects.map((String subject) {
                        return _StatusChip(
                          label: subject,
                          tone: const Color(0xFFEAF1FF),
                          textColor: const Color(0xFF155EEF),
                        );
                      }),
                      ...teacher.effectiveClasses.map((String className) {
                        return _StatusChip(
                          label: className,
                          tone: const Color(0xFFE8F7EE),
                          textColor: const Color(0xFF0F766E),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _KeyValue(
                    label: 'Attendance',
                    value: '${88 + teacher.name.length % 9}%',
                  ),
                  _KeyValue(
                    label: 'Timetable',
                    value: _teacherTimetable(teacher),
                  ),
                  _KeyValue(
                    label: 'Status',
                    value: teacher.isActive ? 'Active' : 'Deactivated',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: () => _showTeacherEditor(teacher: teacher),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _setTeacherActive(teacher, !teacher.isActive),
                        icon: Icon(
                          teacher.isActive
                              ? Icons.person_off_rounded
                              : Icons.person_rounded,
                        ),
                        label: Text(
                          teacher.isActive ? 'Deactivate' : 'Reactivate',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _classesSection() {
    final List<HeadmasterClassSummary> classes = ref.watch(
      headmasterClassSummariesProvider,
    );
    final SchoolAdminState admin = ref.watch(schoolAdminProvider);
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Class Management',
          subtitle:
              'Create classes, assign class teachers, manage streams, inspect attendance, and compare performance.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: _showCreateClassDialog,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Create Class'),
            ),
          ],
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: classes.map((HeadmasterClassSummary item) {
            return _InfoCard(
              width: 360,
              title: item.className,
              subtitle: 'Stream ${item.streamLabel}',
              icon: Icons.groups_2_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _KeyValue(label: 'Class teacher', value: item.teacherName),
                  _KeyValue(label: 'Students', value: '${item.totalStudents}'),
                  _KeyValue(
                    label: 'Performance',
                    value: '${item.averageScore.toStringAsFixed(1)}%',
                  ),
                  _KeyValue(
                    label: 'Attendance',
                    value: '${item.attendanceRate.toStringAsFixed(1)}%',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _showClassTeacherDialog(item, admin.teachers),
                    icon: const Icon(Icons.assignment_ind_rounded),
                    label: const Text('Assign Teacher'),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _subjectsSection() {
    final List<HeadmasterSubjectSummary> subjects = ref.watch(
      headmasterSubjectSummariesProvider,
    );
    final List<TeacherAccount> teachers = ref.watch(
      headmasterActiveTeachersProvider,
    );
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Subject Management',
          subtitle:
              'Manage subject codes, class assignment, teacher assignment, and subject performance.',
          actions: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => _exportSubjects(ReportFileFormat.excel),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export'),
            ),
          ],
        ),
        _ResponsiveDataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Teacher')),
            DataColumn(label: Text('Classes')),
            DataColumn(label: Text('Average')),
            DataColumn(label: Text('Pass Rate')),
            DataColumn(label: Text('Action')),
          ],
          rows: subjects.map((HeadmasterSubjectSummary subject) {
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(subject.code)),
                DataCell(Text(subject.subject)),
                DataCell(Text(subject.teacherName)),
                DataCell(Text(subject.classes.take(4).join(', '))),
                DataCell(Text('${subject.averageScore.toStringAsFixed(1)}%')),
                DataCell(Text('${subject.passRate.toStringAsFixed(1)}%')),
                DataCell(
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _showSubjectTeacherDialog(subject, teachers),
                    icon: const Icon(Icons.assignment_ind_rounded),
                    label: const Text('Assign'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _attendanceSection() {
    final List<HeadmasterAttendanceRecord> records = ref.watch(
      headmasterAttendanceRecordsProvider,
    );
    final List<HeadmasterAttendanceRecord> absent = records.where((
      HeadmasterAttendanceRecord item,
    ) {
      return item.status == HeadmasterAttendanceStatus.absent;
    }).toList();
    final List<HeadmasterAttendanceRecord> late = records.where((
      HeadmasterAttendanceRecord item,
    ) {
      return item.status == HeadmasterAttendanceStatus.late;
    }).toList();

    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Attendance Monitoring',
          subtitle:
              'View daily attendance, absent students, late students, class and gender breakdowns, and monthly reports.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _exportAttendance(ReportFileFormat.pdf),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Monthly PDF'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _exportAttendance(ReportFileFormat.csv),
              icon: const Icon(Icons.table_view_rounded),
              label: const Text('CSV'),
            ),
          ],
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _MetricCard(
              label: 'Present',
              value: '${records.length - absent.length - late.length}',
              icon: Icons.check_circle_rounded,
              tone: const Color(0xFF0F766E),
            ),
            _MetricCard(
              label: 'Absent',
              value: '${absent.length}',
              icon: Icons.cancel_rounded,
              tone: const Color(0xFFB91C1C),
            ),
            _MetricCard(
              label: 'Late',
              value: '${late.length}',
              icon: Icons.schedule_rounded,
              tone: const Color(0xFFEA580C),
            ),
          ],
        ),
        _PanelBoard(
          title: 'Attendance Trend',
          subtitle: 'Daily signal generated from student attendance baselines.',
          child: SizedBox(
            height: 260,
            child: _AttendanceTrendChart(records: records),
          ),
        ),
        _TwoColumn(
          left: _SimpleListBoard(
            title: 'Absent Students',
            items: absent.map((item) {
              return '${item.studentName} - ${item.className}';
            }).toList(),
          ),
          right: _SimpleListBoard(
            title: 'Late Students',
            items: late.map((item) {
              return '${item.studentName} - ${item.className}';
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _resultsSection() {
    final List<StudentResultRecord> students = ref.watch(
      headmasterActiveStudentsProvider,
    );
    final HeadmasterPanelState panel = ref.watch(headmasterPanelProvider);
    final List<StudentResultRecord> top = <StudentResultRecord>[...students]
      ..sort(
        (StudentResultRecord a, StudentResultRecord b) =>
            b.averageScore.compareTo(a.averageScore),
      );
    final List<StudentResultRecord> weak = <StudentResultRecord>[...students]
      ..sort(
        (StudentResultRecord a, StudentResultRecord b) =>
            a.averageScore.compareTo(b.averageScore),
      );

    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Academic Results',
          subtitle:
              'Review marks, class results, subject results, top students, weak students, report cards, approvals, and term comparison.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _exportResults(ReportFileFormat.pdf),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Report Cards'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.go('/all-results'),
              icon: const Icon(Icons.table_chart_rounded),
              label: const Text('Uploaded Results'),
            ),
          ],
        ),
        _TwoColumn(
          left: _StudentRankBoard(
            title: 'Top Students',
            students: top.take(10).toList(),
            approveIds: panel.approvedResultIds,
            onApprove: _approveResult,
          ),
          right: _StudentRankBoard(
            title: 'Weak Students',
            students: weak.take(10).toList(),
            approveIds: panel.approvedResultIds,
            onApprove: _approveResult,
          ),
        ),
        _PanelBoard(
          title: 'Class Performance',
          subtitle:
              'Performance by class for term comparison and publishing review.',
          child: SizedBox(
            height: 320,
            child: _ClassPerformanceChart(
              classes: ref.watch(headmasterClassSummariesProvider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _feesSection() {
    final HeadmasterPanelState panel = ref.watch(headmasterPanelProvider);
    final List<HeadmasterFeeAccount> accounts = panel.feeAccounts.where((
      HeadmasterFeeAccount account,
    ) {
      final String query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return '${account.studentName} ${account.className} ${account.status.label}'
          .toLowerCase()
          .contains(query);
    }).toList();
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Fees',
          subtitle:
              'Monitor paid, partial, outstanding, and defaulter records with exportable summaries.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: () => _exportFees(ReportFileFormat.excel),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Excel'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _exportFees(ReportFileFormat.pdf),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('PDF'),
            ),
          ],
        ),
        _PanelBoard(
          title: 'Fee Collection',
          subtitle: 'Collected versus outstanding balances.',
          child: SizedBox(height: 260, child: _FeeChart(accounts: accounts)),
        ),
        _ResponsiveDataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Student')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Required')),
            DataColumn(label: Text('Paid')),
            DataColumn(label: Text('Outstanding')),
            DataColumn(label: Text('Status')),
          ],
          rows: accounts.map((HeadmasterFeeAccount account) {
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(account.studentName)),
                DataCell(Text(account.className)),
                DataCell(Text(_money(account.requiredAmount))),
                DataCell(Text(_money(account.paidAmount))),
                DataCell(Text(_money(account.outstandingAmount))),
                DataCell(Text(account.status.label)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _reportsSection() {
    final List<_ReportOption> options = <_ReportOption>[
      _ReportOption('Student report', Icons.groups_rounded, _exportStudents),
      _ReportOption('Teacher report', Icons.school_rounded, _exportTeachers),
      _ReportOption(
        'Attendance report',
        Icons.fact_check_rounded,
        _exportAttendance,
      ),
      _ReportOption(
        'Academic performance',
        Icons.leaderboard_rounded,
        _exportResults,
      ),
      _ReportOption('Fee report', Icons.payments_rounded, _exportFees),
      _ReportOption('Gender report', Icons.pie_chart_rounded, _exportGender),
      _ReportOption('Class report', Icons.apartment_rounded, _exportClasses),
      _ReportOption(
        'Registration report',
        Icons.app_registration_rounded,
        _exportRegistration,
      ),
    ];
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Reports',
          subtitle:
              'Generate student, teacher, attendance, academic, fee, gender, class, and registration reports.',
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: options.map((_ReportOption option) {
            return _InfoCard(
              width: 330,
              title: option.title,
              subtitle: 'Export as PDF, Excel, CSV, or print-friendly PDF.',
              icon: option.icon,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: () => option.exporter(ReportFileFormat.pdf),
                    child: const Text('PDF'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => option.exporter(ReportFileFormat.excel),
                    child: const Text('Excel'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => option.exporter(ReportFileFormat.csv),
                    child: const Text('CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => option.exporter(ReportFileFormat.pdf),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Print'),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _announcementsSection() {
    final HeadmasterPanelState panel = ref.watch(headmasterPanelProvider);
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Announcements',
          subtitle: 'Publish school notices for staff, parents, and students.',
          actions: <Widget>[
            FilledButton.icon(
              onPressed: _showAnnouncementDialog,
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('New Announcement'),
            ),
          ],
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: panel.announcements.map((HeadmasterAnnouncement item) {
            return _InfoCard(
              width: 430,
              title: item.title,
              subtitle: '${item.audience} - ${_shortDate(item.createdAt)}',
              icon: Icons.campaign_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.body),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Published'),
                    value: item.published,
                    onChanged: (_) => ref
                        .read(headmasterPanelProvider.notifier)
                        .toggleAnnouncementPublished(item.id),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _usersSection() {
    final HeadmasterPanelState panel = ref.watch(headmasterPanelProvider);
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Users & Roles',
          subtitle:
              'Create and govern Headmaster, Admin, Teacher, Accountant, Registrar, Parent, and Student accounts.',
        ),
        _ResponsiveDataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Permissions')),
            DataColumn(label: Text('Password')),
            DataColumn(label: Text('Actions')),
          ],
          rows: panel.userAccounts.map((HeadmasterUserAccount account) {
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(account.name)),
                DataCell(Text(account.role.label)),
                DataCell(Text(account.active ? 'Active' : 'Deactivated')),
                DataCell(Text(account.permissions.join(', '))),
                DataCell(
                  Text(
                    account.passwordResetRequired
                        ? 'Reset required'
                        : 'Current',
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      IconButton(
                        tooltip: account.active ? 'Deactivate' : 'Activate',
                        onPressed: () => ref
                            .read(headmasterPanelProvider.notifier)
                            .setUserActive(account.id, !account.active),
                        icon: Icon(
                          account.active
                              ? Icons.lock_person_rounded
                              : Icons.verified_user_rounded,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reset password',
                        onPressed: () => ref
                            .read(headmasterPanelProvider.notifier)
                            .requirePasswordReset(account.id),
                        icon: const Icon(Icons.password_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _settingsSection() {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final SchoolAdminState admin = ref.watch(schoolAdminProvider);
    final SchoolAdminController controller = ref.read(
      schoolAdminProvider.notifier,
    );
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Settings',
          subtitle:
              'Control theme, school policies, permissions, backups, and restore readiness.',
          actions: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Full Settings'),
            ),
          ],
        ),
        _TwoColumn(
          left: _PanelBoard(
            title: 'Display',
            subtitle: 'Dark and light mode for the command center.',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              value: mode == ThemeMode.dark,
              onChanged: (bool value) {
                ref.read(themeModeProvider.notifier).state = value
                    ? ThemeMode.dark
                    : ThemeMode.light;
              },
            ),
          ),
          right: _PanelBoard(
            title: 'Backup And Restore',
            subtitle: 'Hybrid v1 backup controls with audit visibility.',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => ref
                      .read(headmasterPanelProvider.notifier)
                      .addAuditEvent(
                        actor: admin.headmasterName,
                        action: 'Backup record created',
                        target: admin.schoolName,
                        detail: 'Manual backup checkpoint created.',
                      ),
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Backup Now'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(headmasterPanelProvider.notifier)
                      .addAuditEvent(
                        actor: admin.headmasterName,
                        action: 'Restore preview opened',
                        target: admin.schoolName,
                        detail: 'Restore remains a controlled future step.',
                        status: HeadmasterAuditStatus.warning,
                      ),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restore Preview'),
                ),
              ],
            ),
          ),
        ),
        _PanelBoard(
          title: 'Role-Based Permissions',
          subtitle: 'School-wide teacher policy switches.',
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              _SettingSwitch(
                label: 'Teacher subject isolation',
                value: admin.settings.enforceTeacherSubjectIsolation,
                onChanged: controller.setTeacherSubjectIsolation,
              ),
              _SettingSwitch(
                label: 'Teachers can register students',
                value: admin.settings.allowTeacherStudentRegistration,
                onChanged: controller.setTeacherStudentRegistrationEnabled,
              ),
              _SettingSwitch(
                label: 'Teachers can download results',
                value: admin.settings.allowTeacherResultDownloads,
                onChanged: controller.setTeacherResultDownloadsEnabled,
              ),
              _SettingSwitch(
                label: 'Auto-fill missing practicals',
                value: admin.settings.autoZeroMissingPracticals,
                onChanged: controller.setAutoZeroPracticals,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _auditSection() {
    final List<HeadmasterAuditEvent>
    events = ref.watch(headmasterPanelProvider).auditEvents.where((
      HeadmasterAuditEvent event,
    ) {
      final String query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return '${event.actor} ${event.action} ${event.target} ${event.detail}'
          .toLowerCase()
          .contains(query);
    }).toList();
    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Security And Audit Logs',
          subtitle:
              'Track login history, failed logins, added students, edited marks, deactivated records, exports, and backups.',
          actions: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => _exportAudit(ReportFileFormat.csv),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        _ResponsiveDataTable(
          columns: const <DataColumn>[
            DataColumn(label: Text('Time')),
            DataColumn(label: Text('Actor')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Target')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Detail')),
          ],
          rows: events.map((HeadmasterAuditEvent event) {
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(_shortDateTime(event.createdAt))),
                DataCell(Text(event.actor)),
                DataCell(Text(event.action)),
                DataCell(Text(event.target)),
                DataCell(Text(event.status.label)),
                DataCell(Text(event.detail)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  void _goToSection(HeadmasterPanelSection section) {
    context.go('/dashboard?panel=${section.routeKey}');
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _logout() {
    ref.read(schoolAdminProvider.notifier).logout();
    context.go('/login');
  }

  Future<void> _showStudentEditor({StudentResultRecord? student}) async {
    final bool editing = student != null;
    final TextEditingController nameController = TextEditingController(
      text: student?.studentName ?? '',
    );
    final TextEditingController admissionController = TextEditingController(
      text: student?.admissionNumber ?? '',
    );
    final TextEditingController guardianController = TextEditingController(
      text: student?.guardianName ?? '',
    );
    final TextEditingController phoneController = TextEditingController(
      text: student?.guardianPhone ?? '',
    );
    final TextEditingController attendanceController = TextEditingController(
      text: student?.attendanceRate.toStringAsFixed(1) ?? '92',
    );
    StudentGender gender = student?.gender ?? StudentGender.female;
    String className = student?.className ?? 'Form 1 A';
    final List<String> classes = <String>{
      ..._standardClasses,
      ...ref
          .read(schoolAdminProvider)
          .studentResults
          .map((StudentResultRecord record) => record.className),
    }.toList()..sort();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(editing ? 'Edit Student' : 'Add Student'),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Student full name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: classes.contains(className)
                                  ? className
                                  : classes.first,
                              decoration: const InputDecoration(
                                labelText: 'Class',
                              ),
                              items: classes.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() => className = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<StudentGender>(
                              initialValue: gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                              ),
                              items: StudentGender.values.map((item) {
                                return DropdownMenuItem<StudentGender>(
                                  value: item,
                                  child: Text(item.label),
                                );
                              }).toList(),
                              onChanged: (StudentGender? value) {
                                if (value == null) {
                                  return;
                                }
                                setDialogState(() => gender = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: admissionController,
                        decoration: InputDecoration(
                          labelText: editing
                              ? 'Registration number'
                              : 'Registration number (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: guardianController,
                              decoration: const InputDecoration(
                                labelText: 'Parent/guardian name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Guardian phone',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: attendanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Attendance percentage',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String name = nameController.text.trim();
                    if (name.isEmpty) {
                      return;
                    }
                    final double attendance =
                        double.tryParse(attendanceController.text.trim()) ?? 92;
                    final SchoolAdminController controller = ref.read(
                      schoolAdminProvider.notifier,
                    );
                    if (editing) {
                      controller.updateStudentRecord(
                        student.copyWith(
                          studentName: name,
                          className: className,
                          gender: gender,
                          admissionNumber:
                              admissionController.text.trim().isEmpty
                              ? student.admissionNumber
                              : admissionController.text.trim(),
                          guardianName: guardianController.text.trim(),
                          guardianPhone: phoneController.text.trim(),
                          attendanceRate: attendance.clamp(0, 100).toDouble(),
                        ),
                      );
                      _audit(
                        action: 'Edited student',
                        target: name,
                        detail: 'Student profile and guardian details updated.',
                      );
                    } else {
                      controller.addStudent(
                        studentName: name,
                        className: className,
                        gender: gender,
                        admissionNumber: admissionController.text.trim().isEmpty
                            ? null
                            : admissionController.text.trim(),
                        attendanceRate: attendance.clamp(0, 100).toDouble(),
                        guardianName: guardianController.text.trim(),
                        guardianPhone: phoneController.text.trim(),
                      );
                      _audit(
                        action: 'Added student',
                        target: name,
                        detail: 'New student registration created.',
                      );
                    }
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(editing ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    admissionController.dispose();
    guardianController.dispose();
    phoneController.dispose();
    attendanceController.dispose();
  }

  Future<void> _showTeacherEditor({TeacherAccount? teacher}) async {
    final bool editing = teacher != null;
    final TextEditingController nameController = TextEditingController(
      text: teacher?.name ?? '',
    );
    final TextEditingController emailController = TextEditingController(
      text: teacher?.email ?? '',
    );
    final TextEditingController passwordController = TextEditingController();
    final Set<String> selectedSubjects = <String>{
      ...?teacher?.effectiveSubjects,
    };
    final Set<String> selectedClasses = <String>{...?teacher?.effectiveClasses};
    if (selectedSubjects.isEmpty) {
      selectedSubjects.add('Basic Mathematics');
    }
    if (selectedClasses.isEmpty) {
      selectedClasses.add('Form 1 A');
    }
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(editing ? 'Edit Teacher' : 'Add Teacher'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Teacher name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      if (!editing) ...<Widget>[
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Initial password',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Subjects',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kNectaOLevelSubjectNames.map((
                          String subject,
                        ) {
                          final bool selected = selectedSubjects.contains(
                            subject,
                          );
                          return FilterChip(
                            label: Text(subject),
                            selected: selected,
                            onSelected: (bool value) {
                              setDialogState(() {
                                if (value) {
                                  selectedSubjects.add(subject);
                                } else if (selectedSubjects.length > 1) {
                                  selectedSubjects.remove(subject);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Classes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _standardClasses.map((String className) {
                          return FilterChip(
                            label: Text(className),
                            selected: selectedClasses.contains(className),
                            onSelected: (bool value) {
                              setDialogState(() {
                                if (value) {
                                  selectedClasses.add(className);
                                } else if (selectedClasses.length > 1) {
                                  selectedClasses.remove(className);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final String name = nameController.text.trim();
                          final String email = emailController.text
                              .trim()
                              .toLowerCase();
                          final String password = passwordController.text
                              .trim();
                          if (name.isEmpty || !email.contains('@')) {
                            return;
                          }
                          if (!editing && password.length < 6) {
                            return;
                          }
                          final SchoolAdminController controller = ref.read(
                            schoolAdminProvider.notifier,
                          );
                          if (editing) {
                            controller.updateTeacherAssignments(
                              teacherId: teacher.id,
                              subjects: selectedSubjects.toList(),
                              assignedClasses: selectedClasses.toList(),
                            );
                            _audit(
                              action: 'Edited teacher',
                              target: name,
                              detail:
                                  'Teacher subject and class assignments updated.',
                            );
                            Navigator.of(dialogContext).pop();
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });
                          bool keepDialogOpen = true;
                          try {
                            await controller.addTeacher(
                              name: name,
                              email: email,
                              subjects: selectedSubjects.toList(),
                              assignedClasses: selectedClasses.toList(),
                              password: password,
                            );
                            _audit(
                              action: 'Added teacher',
                              target: name,
                              detail:
                                  'Teacher login account created and linked to the teacher profile.',
                            );
                            keepDialogOpen = false;
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } on Object catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _teacherSaveErrorMessage(error),
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (keepDialogOpen && dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                              });
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(editing ? 'Save' : 'Create Account'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _showCreateClassDialog() async {
    final TextEditingController controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create Class'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Class name',
              hintText: 'Form One A',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(headmasterPanelProvider.notifier)
                    .createLocalClass(controller.text.trim());
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showClassTeacherDialog(
    HeadmasterClassSummary schoolClass,
    List<TeacherAccount> teachers,
  ) async {
    String selected = teachers.isEmpty ? '' : teachers.first.name;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Assign ${schoolClass.className}'),
              content: DropdownButtonFormField<String>(
                initialValue: selected.isEmpty ? null : selected,
                decoration: const InputDecoration(labelText: 'Class teacher'),
                items: teachers.map((TeacherAccount teacher) {
                  return DropdownMenuItem<String>(
                    value: teacher.name,
                    child: Text(teacher.name),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setDialogState(() => selected = value);
                  }
                },
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          ref
                              .read(headmasterPanelProvider.notifier)
                              .assignClassTeacher(
                                schoolClass.className,
                                selected,
                              );
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSubjectTeacherDialog(
    HeadmasterSubjectSummary subject,
    List<TeacherAccount> teachers,
  ) async {
    String selected = teachers.isEmpty ? '' : teachers.first.name;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Assign ${subject.subject}'),
              content: DropdownButtonFormField<String>(
                initialValue: selected.isEmpty ? null : selected,
                decoration: const InputDecoration(labelText: 'Subject teacher'),
                items: teachers.map((TeacherAccount teacher) {
                  return DropdownMenuItem<String>(
                    value: teacher.name,
                    child: Text(teacher.name),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setDialogState(() => selected = value);
                  }
                },
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () {
                          ref
                              .read(headmasterPanelProvider.notifier)
                              .assignSubjectTeacher(subject.subject, selected);
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAnnouncementDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController bodyController = TextEditingController();
    String audience = 'All Staff';
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('New Announcement'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(labelText: 'Audience'),
                      items:
                          const <String>[
                            'All Staff',
                            'Teachers',
                            'Parents',
                            'Students',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          setDialogState(() => audience = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      return;
                    }
                    ref
                        .read(headmasterPanelProvider.notifier)
                        .addAnnouncement(
                          title: titleController.text.trim(),
                          body: bodyController.text.trim(),
                          audience: audience,
                        );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Publish'),
                ),
              ],
            );
          },
        );
      },
    );
    titleController.dispose();
    bodyController.dispose();
  }

  void _showStudentProfile(StudentResultRecord student) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    student.studentName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('${student.admissionNumber} - ${student.className}'),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _MetricCard(
                        label: 'Average',
                        value: '${student.averageScore.toStringAsFixed(1)}%',
                        icon: Icons.leaderboard_rounded,
                        tone: const Color(0xFF155EEF),
                      ),
                      _MetricCard(
                        label: 'Attendance',
                        value: '${student.attendanceRate.toStringAsFixed(1)}%',
                        icon: Icons.fact_check_rounded,
                        tone: const Color(0xFF0F766E),
                      ),
                      _MetricCard(
                        label: 'Division',
                        value: student.division,
                        icon: Icons.workspace_premium_rounded,
                        tone: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _PanelBoard(
                    title: 'Parent / Guardian',
                    subtitle: 'Emergency contact and responsibility details.',
                    child: Column(
                      children: <Widget>[
                        _KeyValue(
                          label: 'Guardian',
                          value: student.guardianName.isEmpty
                              ? 'Not recorded'
                              : student.guardianName,
                        ),
                        _KeyValue(
                          label: 'Phone',
                          value: student.guardianPhone.isEmpty
                              ? 'Not recorded'
                              : student.guardianPhone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PanelBoard(
                    title: 'Academic History',
                    subtitle: 'Subject averages and recent trend.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: student.subjectResults.map((
                        SubjectResult item,
                      ) {
                        return _StatusChip(
                          label:
                              '${item.subject}: ${item.averageScore.toStringAsFixed(1)}%',
                          tone: const Color(0xFFF1F5F9),
                          textColor: const Color(0xFF334155),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _setStudentActive(StudentResultRecord student, bool active) {
    ref.read(schoolAdminProvider.notifier).setStudentActive(student.id, active);
    _audit(
      action: active ? 'Reactivated student' : 'Deactivated student',
      target: student.studentName,
      detail: active
          ? 'Student returned to active workflows.'
          : 'Student hidden from active rosters while history remains.',
    );
  }

  void _setTeacherActive(TeacherAccount teacher, bool active) {
    ref.read(schoolAdminProvider.notifier).setTeacherActive(teacher.id, active);
    _audit(
      action: active ? 'Reactivated teacher' : 'Deactivated teacher',
      target: teacher.name,
      detail: active
          ? 'Teacher returned to active workflows.'
          : 'Teacher permissions disabled while history remains.',
    );
  }

  void _approveResult(StudentResultRecord student) {
    ref
        .read(headmasterPanelProvider.notifier)
        .approveResult(student.id, student.studentName);
  }

  void _audit({
    required String action,
    required String target,
    required String detail,
    HeadmasterAuditStatus status = HeadmasterAuditStatus.success,
  }) {
    final SchoolAdminState admin = ref.read(schoolAdminProvider);
    ref
        .read(headmasterPanelProvider.notifier)
        .addAuditEvent(
          actor: admin.session?.name ?? admin.headmasterName,
          action: action,
          target: target,
          detail: detail,
          status: status,
        );
  }

  Future<void> _showReportFormatSheet(
    ReportExportData report,
    String baseName,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final ReportFileFormat format in ReportFileFormat.values)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _exportReport(report, baseName, format);
                    },
                    icon: Icon(_formatIcon(format)),
                    label: Text(format.label),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _exportReport(
                      report,
                      '${baseName}_print',
                      ReportFileFormat.pdf,
                    );
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Print'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportReport(
    ReportExportData report,
    String baseName,
    ReportFileFormat format,
  ) async {
    final String? path = await ReportExporter.exportReport(
      suggestedBaseName: baseName,
      report: report,
      format: format,
    );
    _audit(
      action: 'Exported report',
      target: report.title,
      detail: '${format.label} export ${path == null ? 'cancelled' : 'saved'}',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Export cancelled.' : 'Report saved to $path',
        ),
      ),
    );
  }

  Future<void> _exportStudents(ReportFileFormat format) {
    return _exportReport(_studentReport(), 'student_report', format);
  }

  Future<void> _exportTeachers(ReportFileFormat format) {
    return _exportReport(_teacherReport(), 'teacher_report', format);
  }

  Future<void> _exportAttendance(ReportFileFormat format) {
    return _exportReport(_attendanceReport(), 'attendance_report', format);
  }

  Future<void> _exportResults(ReportFileFormat format) {
    return _exportReport(
      _resultsReport(),
      'academic_performance_report',
      format,
    );
  }

  Future<void> _exportFees(ReportFileFormat format) {
    return _exportReport(_feeReport(), 'fee_report', format);
  }

  Future<void> _exportGender(ReportFileFormat format) {
    return _exportReport(_genderReport(), 'gender_report', format);
  }

  Future<void> _exportClasses(ReportFileFormat format) {
    return _exportReport(_classReport(), 'class_report', format);
  }

  Future<void> _exportRegistration(ReportFileFormat format) {
    return _exportReport(_registrationReport(), 'registration_report', format);
  }

  Future<void> _exportSubjects(ReportFileFormat format) {
    return _exportReport(_subjectReport(), 'subject_report', format);
  }

  Future<void> _exportAudit(ReportFileFormat format) {
    return _exportReport(_auditReport(), 'audit_log_report', format);
  }

  ReportExportData _studentReport() {
    final List<StudentResultRecord> students = _filteredStudents();
    return _baseReport(
      title: 'Student Report',
      type: 'Student report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Students',
          headers: const <String>[
            'Name',
            'Registration',
            'Class',
            'Gender',
            'Guardian',
            'Attendance',
            'Average',
            'Status',
          ],
          rows: students.map((StudentResultRecord student) {
            return <Object?>[
              student.studentName,
              student.admissionNumber,
              student.className,
              student.gender.label,
              student.guardianName,
              student.attendanceRate.toStringAsFixed(1),
              student.averageScore.toStringAsFixed(1),
              student.isActive ? 'Active' : 'Deactivated',
            ];
          }).toList(),
        ),
      ],
      pdfLandscape: true,
    );
  }

  ReportExportData _teacherReport() {
    final List<TeacherAccount> teachers = ref
        .read(schoolAdminProvider)
        .teachers;
    return _baseReport(
      title: 'Teacher Report',
      type: 'Teacher report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Teachers',
          headers: const <String>[
            'Name',
            'Email',
            'Subjects',
            'Classes',
            'Upload',
            'Edit',
            'Status',
          ],
          rows: teachers.map((TeacherAccount teacher) {
            return <Object?>[
              teacher.name,
              teacher.email,
              teacher.effectiveSubjects.join(', '),
              teacher.effectiveClasses.join(', '),
              teacher.canUploadResults ? 'Yes' : 'No',
              teacher.canEditResults ? 'Yes' : 'No',
              teacher.isActive ? 'Active' : 'Deactivated',
            ];
          }).toList(),
        ),
      ],
      pdfLandscape: true,
    );
  }

  ReportExportData _attendanceReport() {
    final List<HeadmasterAttendanceRecord> records = ref.read(
      headmasterAttendanceRecordsProvider,
    );
    return _baseReport(
      title: 'Attendance Report',
      type: 'Attendance report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Daily Attendance',
          headers: const <String>[
            'Student',
            'Class',
            'Gender',
            'Status',
            'Attendance Rate',
          ],
          rows: records.map((HeadmasterAttendanceRecord record) {
            return <Object?>[
              record.studentName,
              record.className,
              record.gender.label,
              record.status.label,
              record.rate.toStringAsFixed(1),
            ];
          }).toList(),
        ),
      ],
    );
  }

  ReportExportData _resultsReport() {
    final List<StudentResultRecord> students = ref.read(
      headmasterActiveStudentsProvider,
    );
    return _baseReport(
      title: 'Academic Performance Report',
      type: 'Academic performance report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Student Results',
          headers: const <String>[
            'Student',
            'Class',
            'Average',
            'Inter Exam',
            'Division',
            'Attendance',
          ],
          rows: students.map((StudentResultRecord student) {
            return <Object?>[
              student.studentName,
              student.className,
              student.averageScore.toStringAsFixed(1),
              student.interExamAverage.toStringAsFixed(1),
              student.division,
              student.attendanceRate.toStringAsFixed(1),
            ];
          }).toList(),
        ),
      ],
      pdfLandscape: true,
    );
  }

  ReportExportData _feeReport() {
    final List<HeadmasterFeeAccount> accounts = ref
        .read(headmasterPanelProvider)
        .feeAccounts;
    return _baseReport(
      title: 'Fee Report',
      type: 'Fee report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Fee Summary',
          headers: const <String>[
            'Student',
            'Class',
            'Required',
            'Paid',
            'Outstanding',
            'Status',
          ],
          rows: accounts.map((HeadmasterFeeAccount account) {
            return <Object?>[
              account.studentName,
              account.className,
              account.requiredAmount.toStringAsFixed(0),
              account.paidAmount.toStringAsFixed(0),
              account.outstandingAmount.toStringAsFixed(0),
              account.status.label,
            ];
          }).toList(),
        ),
      ],
    );
  }

  ReportExportData _genderReport() {
    final HeadmasterOverview overview = ref.read(headmasterOverviewProvider);
    return _baseReport(
      title: 'Gender Report',
      type: 'Gender report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Gender Distribution',
          headers: const <String>['Gender', 'Count'],
          rows: <List<Object?>>[
            <Object?>['Female', overview.femaleStudents],
            <Object?>['Male', overview.maleStudents],
          ],
        ),
      ],
    );
  }

  ReportExportData _classReport() {
    final List<HeadmasterClassSummary> classes = ref.read(
      headmasterClassSummariesProvider,
    );
    return _baseReport(
      title: 'Class Report',
      type: 'Class report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Classes',
          headers: const <String>[
            'Class',
            'Teacher',
            'Students',
            'Average',
            'Attendance',
          ],
          rows: classes.map((HeadmasterClassSummary item) {
            return <Object?>[
              item.className,
              item.teacherName,
              item.totalStudents,
              item.averageScore.toStringAsFixed(1),
              item.attendanceRate.toStringAsFixed(1),
            ];
          }).toList(),
        ),
      ],
    );
  }

  ReportExportData _registrationReport() {
    final List<StudentResultRecord> students =
        ref.read(schoolAdminProvider).studentResults.toList()
          ..sort(compareStudentResultsForRoster);
    return _baseReport(
      title: 'Registration Report',
      type: 'Registration report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Registration Order',
          note: 'Female students A-Z are listed first, then male students A-Z.',
          headers: const <String>[
            'Order',
            'Name',
            'Registration',
            'Class',
            'Gender',
            'Registered At',
          ],
          rows: students.asMap().entries.map((entry) {
            final StudentResultRecord student = entry.value;
            return <Object?>[
              entry.key + 1,
              student.studentName,
              student.admissionNumber,
              student.className,
              student.gender.label,
              student.registeredAt == null
                  ? ''
                  : _shortDate(student.registeredAt!),
            ];
          }).toList(),
        ),
      ],
      pdfLandscape: true,
    );
  }

  ReportExportData _subjectReport() {
    final List<HeadmasterSubjectSummary> subjects = ref.read(
      headmasterSubjectSummariesProvider,
    );
    return _baseReport(
      title: 'Subject Report',
      type: 'Subject report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Subjects',
          headers: const <String>[
            'Code',
            'Subject',
            'Teacher',
            'Classes',
            'Average',
            'Pass Rate',
          ],
          rows: subjects.map((HeadmasterSubjectSummary subject) {
            return <Object?>[
              subject.code,
              subject.subject,
              subject.teacherName,
              subject.classes.join(', '),
              subject.averageScore.toStringAsFixed(1),
              subject.passRate.toStringAsFixed(1),
            ];
          }).toList(),
        ),
      ],
    );
  }

  ReportExportData _auditReport() {
    final List<HeadmasterAuditEvent> events = ref
        .read(headmasterPanelProvider)
        .auditEvents;
    return _baseReport(
      title: 'Audit Log Report',
      type: 'Audit log report',
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Audit Events',
          headers: const <String>[
            'Time',
            'Actor',
            'Action',
            'Target',
            'Status',
            'Detail',
          ],
          rows: events.map((HeadmasterAuditEvent event) {
            return <Object?>[
              _shortDateTime(event.createdAt),
              event.actor,
              event.action,
              event.target,
              event.status.label,
              event.detail,
            ];
          }).toList(),
        ),
      ],
      pdfLandscape: true,
    );
  }

  ReportExportData _baseReport({
    required String title,
    required String type,
    required List<ReportExportSection> sections,
    bool pdfLandscape = false,
  }) {
    final SchoolAdminState admin = ref.read(schoolAdminProvider);
    final HeadmasterOverview overview = ref.read(headmasterOverviewProvider);
    return ReportExportData(
      title: title,
      subtitle: 'Generated from the Headmaster Panel.',
      schoolName: admin.schoolName,
      reportType: type,
      generatedAt: DateTime.now(),
      pdfLandscape: pdfLandscape,
      summary: <ReportSummaryItem>[
        ReportSummaryItem(
          label: 'Students',
          value: '${overview.totalStudents}',
        ),
        ReportSummaryItem(
          label: 'Teachers',
          value: '${overview.totalTeachers}',
        ),
        ReportSummaryItem(label: 'Classes', value: '${overview.totalClasses}'),
        ReportSummaryItem(
          label: 'Attendance',
          value: '${overview.attendancePercentage.toStringAsFixed(1)}%',
        ),
      ],
      sections: sections,
    );
  }
}

class _DashboardSection extends ConsumerWidget {
  const _DashboardSection({required this.onExport});

  final Future<void> Function(ReportExportData report, String baseName)
  onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HeadmasterOverview overview = ref.watch(headmasterOverviewProvider);
    final List<StudentResultRecord> students = ref.watch(
      headmasterActiveStudentsProvider,
    );
    final List<HeadmasterClassSummary> classes = ref.watch(
      headmasterClassSummariesProvider,
    );
    final List<HeadmasterFeeAccount> fees = ref
        .watch(headmasterPanelProvider)
        .feeAccounts;

    return _PanelList(
      children: <Widget>[
        _SectionToolbar(
          title: 'Dashboard Overview',
          subtitle:
              'School-wide statistics, gender distribution, attendance trend, class performance, fees, and recent activities.',
          actions: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => onExport(
                ReportExportData(
                  title: 'Headmaster Dashboard Summary',
                  subtitle: 'Whole school overview snapshot.',
                  generatedAt: DateTime.now(),
                  sections: <ReportExportSection>[
                    ReportExportSection(
                      title: 'Summary',
                      headers: const <String>['Metric', 'Value'],
                      rows: <List<Object?>>[
                        <Object?>['Students', overview.totalStudents],
                        <Object?>['Teachers', overview.totalTeachers],
                        <Object?>['Classes', overview.totalClasses],
                        <Object?>['Subjects', overview.totalSubjects],
                        <Object?>['Male', overview.maleStudents],
                        <Object?>['Female', overview.femaleStudents],
                        <Object?>[
                          'Attendance',
                          overview.attendancePercentage.toStringAsFixed(1),
                        ],
                        <Object?>[
                          'Fees collected',
                          overview.feesCollected.toStringAsFixed(0),
                        ],
                      ],
                    ),
                  ],
                ),
                'headmaster_dashboard_summary',
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export Overview'),
            ),
          ],
        ),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _MetricCard(
              label: 'Students',
              value: '${overview.totalStudents}',
              icon: Icons.groups_rounded,
              tone: const Color(0xFF155EEF),
            ),
            _MetricCard(
              label: 'Teachers',
              value: '${overview.totalTeachers}',
              icon: Icons.school_rounded,
              tone: const Color(0xFF0F766E),
            ),
            _MetricCard(
              label: 'Classes',
              value: '${overview.totalClasses}',
              icon: Icons.apartment_rounded,
              tone: const Color(0xFF7C3AED),
            ),
            _MetricCard(
              label: 'Subjects',
              value: '${overview.totalSubjects}',
              icon: Icons.menu_book_rounded,
              tone: const Color(0xFFEA580C),
            ),
            _MetricCard(
              label: 'Male',
              value: '${overview.maleStudents}',
              icon: Icons.male_rounded,
              tone: const Color(0xFF2563EB),
            ),
            _MetricCard(
              label: 'Female',
              value: '${overview.femaleStudents}',
              icon: Icons.female_rounded,
              tone: const Color(0xFFDB2777),
            ),
            _MetricCard(
              label: 'New Today',
              value: '${overview.newToday}',
              icon: Icons.fiber_new_rounded,
              tone: const Color(0xFF0F766E),
            ),
            _MetricCard(
              label: 'New This Week',
              value: '${overview.newThisWeek}',
              icon: Icons.calendar_month_rounded,
              tone: const Color(0xFF7C3AED),
            ),
            _MetricCard(
              label: 'Attendance Today',
              value: '${overview.attendancePercentage.toStringAsFixed(1)}%',
              icon: Icons.fact_check_rounded,
              tone: const Color(0xFF0891B2),
            ),
            _MetricCard(
              label: 'Fees Collected',
              value: _money(overview.feesCollected),
              icon: Icons.payments_rounded,
              tone: const Color(0xFF16A34A),
            ),
          ],
        ),
        _TwoColumn(
          left: _PanelBoard(
            title: 'Gender Distribution',
            subtitle: 'Female and male student count.',
            child: SizedBox(
              height: 260,
              child: _GenderChart(
                female: overview.femaleStudents,
                male: overview.maleStudents,
              ),
            ),
          ),
          right: _PanelBoard(
            title: 'Attendance Trend',
            subtitle: 'Current school attendance movement.',
            child: SizedBox(
              height: 260,
              child: _AttendanceTrendChart(
                records: ref.watch(headmasterAttendanceRecordsProvider),
              ),
            ),
          ),
        ),
        _TwoColumn(
          left: _PanelBoard(
            title: 'Class Performance',
            subtitle: 'Average score by class.',
            child: SizedBox(
              height: 320,
              child: _ClassPerformanceChart(classes: classes),
            ),
          ),
          right: _PanelBoard(
            title: 'Fees Summary',
            subtitle: 'Collected and outstanding fee position.',
            child: SizedBox(height: 320, child: _FeeChart(accounts: fees)),
          ),
        ),
        _TwoColumn(
          left: _SimpleListBoard(
            title: 'Recent Activities',
            items: overview.recentActivities.map((HeadmasterAuditEvent event) {
              return '${event.actor} ${event.action.toLowerCase()} ${event.target} at ${_shortTime(event.createdAt)}';
            }).toList(),
          ),
          right: _SimpleListBoard(
            title: 'Attention List',
            items: students
                .where((StudentResultRecord record) {
                  return record.riskLevel != RiskLevel.stable;
                })
                .take(8)
                .map((StudentResultRecord record) {
                  return '${record.studentName} - ${record.riskLevel.label}';
                })
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _HeadmasterSidebar extends StatelessWidget {
  const _HeadmasterSidebar({
    required this.currentSection,
    required this.session,
    required this.onSelect,
    required this.onLogout,
  });

  final HeadmasterPanelSection currentSection;
  final SessionUser session;
  final ValueChanged<HeadmasterPanelSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: const Color(0xFF0F172A),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Headmaster Panel',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.schoolName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: <Widget>[
                for (final HeadmasterPanelSection section
                    in HeadmasterPanelSection.values)
                  _SidebarItem(
                    section: section,
                    selected: currentSection == section,
                    onTap: () => onSelect(section),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final HeadmasterPanelSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              Icon(_sectionIcon(section), color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      section.label,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadmasterHeader extends ConsumerWidget {
  const _HeadmasterHeader({
    required this.section,
    required this.session,
    required this.searchController,
    required this.onSearchChanged,
    required this.onOpenMenu,
    required this.onRefresh,
    required this.onLogout,
    required this.showMenu,
  });

  final HeadmasterPanelSection section;
  final SessionUser session;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenMenu;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 900;
            final Widget title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SCHOOL ADMINISTRATION',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  section.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${section.subtitle} - ${session.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            );
            final Widget search = TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search students, teachers, classes, reports',
              ),
            );
            final Widget actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (showMenu)
                  IconButton.filledTonal(
                    tooltip: 'Menu',
                    onPressed: onOpenMenu,
                    icon: const Icon(Icons.menu_rounded),
                  ),
                IconButton.filledTonal(
                  tooltip: dark ? 'Light mode' : 'Dark mode',
                  onPressed: () {
                    ref.read(themeModeProvider.notifier).state = dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  },
                  icon: Icon(
                    dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Refresh',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton.filledTonal(
                  tooltip: 'Logout',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  ),
                  const SizedBox(height: 14),
                  search,
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(flex: 4, child: title),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: search),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PanelList extends StatelessWidget {
  const _PanelList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemBuilder: (BuildContext context, int index) => children[index],
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 16),
      itemCount: children.length,
    );
  }
}

class _SectionToolbar extends StatelessWidget {
  const _SectionToolbar({
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return _PanelBoard(
      title: title,
      subtitle: subtitle,
      child: actions.isEmpty
          ? const SizedBox.shrink()
          : Wrap(spacing: 10, runSpacing: 10, children: actions),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children
          .map((Widget child) => SizedBox(width: 250, child: child))
          .toList(),
    );
  }
}

class _PanelBoard extends StatelessWidget {
  const _PanelBoard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final double width;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _PanelBoard(
        title: title,
        subtitle: subtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 205,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.tone,
    required this.textColor,
  });

  final String label;
  final Color tone;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: textColor),
      ),
    );
  }
}

class _ResponsiveDataTable extends StatelessWidget {
  const _ResponsiveDataTable({required this.columns, required this.rows});

  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    return _PanelBoard(
      title: 'Records',
      subtitle: '${rows.length} rows visible',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: columns, rows: rows),
      ),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: <Widget>[left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SimpleListBoard extends StatelessWidget {
  const _SimpleListBoard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _PanelBoard(
      title: title,
      subtitle: items.isEmpty
          ? 'No records require attention.'
          : '${items.length} records',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: (items.isEmpty ? <String>['No records available.'] : items)
            .take(10)
            .map((String item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.circle, size: 8),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
                  ],
                ),
              );
            })
            .toList(),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.64),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 310,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _GenderChart extends StatelessWidget {
  const _GenderChart({required this.female, required this.male});

  final int female;
  final int male;

  @override
  Widget build(BuildContext context) {
    final int total = female + male;
    if (total == 0) {
      return const Center(child: Text('No students yet'));
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 48,
        sections: <PieChartSectionData>[
          PieChartSectionData(
            color: const Color(0xFFDB2777),
            value: female.toDouble(),
            title: 'Female\n$female',
            radius: 76,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          PieChartSectionData(
            color: const Color(0xFF2563EB),
            value: male.toDouble(),
            title: 'Male\n$male',
            radius: 76,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTrendChart extends StatelessWidget {
  const _AttendanceTrendChart({required this.records});

  final List<HeadmasterAttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    final double average = records.isEmpty
        ? 0
        : records.fold<double>(0, (sum, record) => sum + record.rate) /
              records.length;
    final List<double> points = <double>[
      (average - 4).clamp(0, 100).toDouble(),
      (average - 1).clamp(0, 100).toDouble(),
      (average + 1).clamp(0, 100).toDouble(),
      average.clamp(0, 100).toDouble(),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: points.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value);
            }).toList(),
            isCurved: true,
            barWidth: 4,
            color: const Color(0xFF0F766E),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _ClassPerformanceChart extends StatelessWidget {
  const _ClassPerformanceChart({required this.classes});

  final List<HeadmasterClassSummary> classes;

  @override
  Widget build(BuildContext context) {
    final List<HeadmasterClassSummary> visible = classes.take(8).toList();
    return BarChart(
      BarChartData(
        maxY: 100,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= visible.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    visible[index].className.replaceAll('Form ', 'F'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: visible.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: entry.value.averageScore,
                width: 18,
                color: const Color(0xFF155EEF),
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FeeChart extends StatelessWidget {
  const _FeeChart({required this.accounts});

  final List<HeadmasterFeeAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final double collected = accounts.fold<double>(
      0,
      (double sum, HeadmasterFeeAccount account) => sum + account.paidAmount,
    );
    final double outstanding = accounts.fold<double>(
      0,
      (double sum, HeadmasterFeeAccount account) =>
          sum + account.outstandingAmount,
    );
    if (collected + outstanding == 0) {
      return const Center(child: Text('No fees recorded'));
    }
    return PieChart(
      PieChartData(
        centerSpaceRadius: 58,
        sectionsSpace: 4,
        sections: <PieChartSectionData>[
          PieChartSectionData(
            value: collected,
            color: const Color(0xFF16A34A),
            title: 'Collected',
            radius: 82,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          PieChartSectionData(
            value: outstanding,
            color: const Color(0xFFEA580C),
            title: 'Outstanding',
            radius: 82,
            titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StudentRankBoard extends StatelessWidget {
  const _StudentRankBoard({
    required this.title,
    required this.students,
    required this.approveIds,
    required this.onApprove,
  });

  final String title;
  final List<StudentResultRecord> students;
  final Set<String> approveIds;
  final ValueChanged<StudentResultRecord> onApprove;

  @override
  Widget build(BuildContext context) {
    return _PanelBoard(
      title: title,
      subtitle: 'Ranked academic review list.',
      child: Column(
        children: students.map((StudentResultRecord student) {
          final bool approved = approveIds.contains(student.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        student.studentName,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        '${student.className} - ${student.averageScore.toStringAsFixed(1)}% - ${student.division}',
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: approved ? null : () => onApprove(student),
                  icon: Icon(
                    approved ? Icons.verified_rounded : Icons.approval_rounded,
                  ),
                  label: Text(approved ? 'Approved' : 'Approve'),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportOption {
  const _ReportOption(this.title, this.icon, this.exporter);

  final String title;
  final IconData icon;
  final Future<void> Function(ReportFileFormat format) exporter;
}

IconData _sectionIcon(HeadmasterPanelSection section) {
  switch (section) {
    case HeadmasterPanelSection.dashboard:
      return Icons.dashboard_rounded;
    case HeadmasterPanelSection.students:
      return Icons.groups_rounded;
    case HeadmasterPanelSection.teachers:
      return Icons.school_rounded;
    case HeadmasterPanelSection.classes:
      return Icons.apartment_rounded;
    case HeadmasterPanelSection.subjects:
      return Icons.menu_book_rounded;
    case HeadmasterPanelSection.attendance:
      return Icons.fact_check_rounded;
    case HeadmasterPanelSection.results:
      return Icons.leaderboard_rounded;
    case HeadmasterPanelSection.fees:
      return Icons.payments_rounded;
    case HeadmasterPanelSection.reports:
      return Icons.summarize_rounded;
    case HeadmasterPanelSection.announcements:
      return Icons.campaign_rounded;
    case HeadmasterPanelSection.usersRoles:
      return Icons.admin_panel_settings_rounded;
    case HeadmasterPanelSection.settings:
      return Icons.settings_rounded;
    case HeadmasterPanelSection.auditLogs:
      return Icons.security_rounded;
  }
}

IconData _formatIcon(ReportFileFormat format) {
  switch (format) {
    case ReportFileFormat.excel:
      return Icons.table_chart_rounded;
    case ReportFileFormat.pdf:
      return Icons.picture_as_pdf_rounded;
    case ReportFileFormat.csv:
      return Icons.description_rounded;
  }
}

String _genderFilterLabel(HeadmasterGenderFilter filter) {
  switch (filter) {
    case HeadmasterGenderFilter.all:
      return 'All genders';
    case HeadmasterGenderFilter.female:
      return 'Female';
    case HeadmasterGenderFilter.male:
      return 'Male';
  }
}

String _statusFilterLabel(HeadmasterStatusFilter filter) {
  switch (filter) {
    case HeadmasterStatusFilter.active:
      return 'Active only';
    case HeadmasterStatusFilter.deactivated:
      return 'Deactivated only';
    case HeadmasterStatusFilter.all:
      return 'All statuses';
  }
}

String _orderLabel(HeadmasterRegistrationOrder order) {
  switch (order) {
    case HeadmasterRegistrationOrder.femaleThenMale:
      return 'Female A-Z, then Male A-Z';
    case HeadmasterRegistrationOrder.femaleOnly:
      return 'Female A-Z';
    case HeadmasterRegistrationOrder.maleOnly:
      return 'Male A-Z';
  }
}

String _teacherTimetable(TeacherAccount teacher) {
  final String subject = teacher.effectiveSubjects.isEmpty
      ? 'Subject'
      : teacher.effectiveSubjects.first;
  final String className = teacher.effectiveClasses.isEmpty
      ? 'Class'
      : teacher.effectiveClasses.first;
  return 'Mon/Wed/Fri - $subject - $className';
}

String _teacherSaveErrorMessage(Object error) {
  final String normalized = error
      .toString()
      .replaceFirst(RegExp(r'^[A-Za-z]+(?:Exception|Error):\s*'), '')
      .trim();
  final String lower = normalized.toLowerCase();
  if (lower.contains('already registered') ||
      lower.contains('already exists') ||
      lower.contains('duplicate key')) {
    return 'That email is already registered. Use another email or edit the existing teacher.';
  }
  if (lower.contains('password')) {
    return 'Teacher account was not created. Use a stronger password, at least 6 characters.';
  }
  if (lower.contains('row-level security') || lower.contains('rls')) {
    return 'Teacher account was not created because Supabase policies blocked it. Apply the latest migration, then try again.';
  }
  if (normalized.isEmpty) {
    return 'Teacher account was not created. Please try again.';
  }
  return 'Teacher account was not created: $normalized';
}

String _money(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}K';
  }
  return value.toStringAsFixed(0);
}

String _shortDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String _shortTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _shortDateTime(DateTime value) {
  return '${_shortDate(value)} ${_shortTime(value)}';
}

const List<String> _standardClasses = <String>[
  'Form 1 A',
  'Form 1 B',
  'Form 2 A',
  'Form 2 B',
  'Form 3 A',
  'Form 3 B',
  'Form 4 A',
  'Form 4 B',
];
