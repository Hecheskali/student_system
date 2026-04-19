import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

class HierarchyExplorerScreen extends ConsumerStatefulWidget {
  const HierarchyExplorerScreen({
    super.key,
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
  ConsumerState<HierarchyExplorerScreen> createState() =>
      _HierarchyExplorerScreenState();
}

class _HierarchyExplorerScreenState
    extends ConsumerState<HierarchyExplorerScreen> {
  String? _selectedDistrictId;
  String? _selectedSchoolId;
  String? _selectedClassId;
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _selectedDistrictId = widget.districtId;
    _selectedSchoolId = widget.schoolId;
    _selectedClassId = widget.classId;
    _selectedStudentId = widget.studentId;
  }

  @override
  void didUpdateWidget(covariant HierarchyExplorerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.districtId != oldWidget.districtId ||
        widget.schoolId != oldWidget.schoolId ||
        widget.classId != oldWidget.classId ||
        widget.studentId != oldWidget.studentId) {
      _selectedDistrictId = widget.districtId;
      _selectedSchoolId = widget.schoolId;
      _selectedClassId = widget.classId;
      _selectedStudentId = widget.studentId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionUser? session = ref.watch(schoolAdminProvider).session;
    final AsyncValue<List<District>> districtsAsync = ref.watch(
      districtsProvider,
    );
    final AsyncValue<List<School>> schoolsAsync = _selectedDistrictId == null
        ? const AsyncValue<List<School>>.data(<School>[])
        : ref.watch(schoolsProvider(_selectedDistrictId!));
    final AsyncValue<List<SchoolClass>> classesAsync = _selectedSchoolId == null
        ? const AsyncValue<List<SchoolClass>>.data(<SchoolClass>[])
        : ref.watch(classesProvider(_selectedSchoolId!));
    final AsyncValue<List<Student>> studentsAsync = _selectedClassId == null
        ? const AsyncValue<List<Student>>.data(<Student>[])
        : ref.watch(studentsProvider(_selectedClassId!));

    final ScopeRequest scopeRequest = ScopeRequest(
      districtId: _selectedDistrictId,
      schoolId: _selectedSchoolId,
      classId: _selectedClassId,
      studentId: _selectedStudentId,
    );
    final AsyncValue<ScopeSummary> scopeAsync = ref.watch(
      scopeSummaryProvider(scopeRequest),
    );

    return WorkspaceShell(
      currentSection: WorkspaceSection.explorer,
      session: session,
      title: 'Hierarchy Explorer',
      subtitle:
          'The explorer now shares the same design system as the rest of the product while keeping district-to-student drill-down intact.',
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: _resetAll,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reset Scope'),
        ),
      ],
      child: districtsAsync.when(
        data: (List<District> districts) {
          final District? selectedDistrict = _findById<District>(
            districts,
            _selectedDistrictId,
            (District item) => item.id,
          );
          final List<School> schools = schoolsAsync.value ?? <School>[];
          final School? selectedSchool = _findById<School>(
            schools,
            _selectedSchoolId,
            (School item) => item.id,
          );
          final List<SchoolClass> classes =
              classesAsync.value ?? <SchoolClass>[];
          final SchoolClass? selectedClass = _findById<SchoolClass>(
            classes,
            _selectedClassId,
            (SchoolClass item) => item.id,
          );
          final List<Student> students = studentsAsync.value ?? <Student>[];
          final Student? selectedStudent = _findById<Student>(
            students,
            _selectedStudentId,
            (Student item) => item.id,
          );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              RevealMotion(
                child: _ExplorerHero(
                  district: selectedDistrict,
                  school: selectedSchool,
                  schoolClass: selectedClass,
                  student: selectedStudent,
                  onReset: _resetAll,
                  onBackToDistrict: _selectedDistrictId == null
                      ? null
                      : () {
                          setState(() {
                            _selectedSchoolId = null;
                            _selectedClassId = null;
                            _selectedStudentId = null;
                          });
                        },
                  onBackToSchool: _selectedSchoolId == null
                      ? null
                      : () {
                          setState(() {
                            _selectedClassId = null;
                            _selectedStudentId = null;
                          });
                        },
                  onBackToClass: _selectedClassId == null
                      ? null
                      : () {
                          setState(() {
                            _selectedStudentId = null;
                          });
                        },
                ),
              ),
              const SizedBox(height: 18),
              scopeAsync.when(
                data: (ScopeSummary scope) => RevealMotion(
                  delay: const Duration(milliseconds: 80),
                  child: _ScopeBoard(scope: scope),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object error, StackTrace stackTrace) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Unable to load scope summary: $error'),
                ),
              ),
              const SizedBox(height: 18),
              RevealMotion(
                delay: const Duration(milliseconds: 120),
                child: _ExplorerSection<District>(
                  tone: const Color(0xFF155EEF),
                  title: 'Districts',
                  subtitle:
                      'Start at the top and narrow the scope with visible context.',
                  items: districts,
                  selectedId: _selectedDistrictId,
                  itemBuilder: (District district, bool selected) => _EntityTile(
                    selected: selected,
                    tone: const Color(0xFF155EEF),
                    icon: Icons.location_city_rounded,
                    title: district.name,
                    subtitle:
                        '${district.totalSchools} schools • ${district.totalStudents} learners',
                    stats: <String>[
                      'Attendance ${district.averageAttendance}%',
                      'Score ${district.averageScore}%',
                    ],
                    badgeLabel: district.focusArea,
                  ),
                  onTap: (District district) {
                    setState(() {
                      _selectedDistrictId = district.id;
                      _selectedSchoolId = null;
                      _selectedClassId = null;
                      _selectedStudentId = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              RevealMotion(
                delay: const Duration(milliseconds: 160),
                child: _ExplorerSection<School>(
                  tone: const Color(0xFF0F766E),
                  title: 'Schools',
                  subtitle: _selectedDistrictId == null
                      ? 'Choose a district to load schools.'
                      : 'Compare schools inside the selected district with the same layout language.',
                  items: schools,
                  selectedId: _selectedSchoolId,
                  loading: schoolsAsync.isLoading,
                  emptyMessage: _selectedDistrictId == null
                      ? 'Select a district first.'
                      : 'No schools found for this district.',
                  itemBuilder: (School school, bool selected) => _EntityTile(
                    selected: selected,
                    tone: const Color(0xFF0F766E),
                    icon: Icons.school_rounded,
                    title: school.name,
                    subtitle:
                        '${school.totalClasses} classes • ${school.totalStudents} learners',
                    stats: <String>[
                      'Attendance ${school.averageAttendance}%',
                      'Score ${school.averageScore}%',
                    ],
                    badgeLabel: school.principal,
                  ),
                  onTap: (School school) {
                    setState(() {
                      _selectedSchoolId = school.id;
                      _selectedClassId = null;
                      _selectedStudentId = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              RevealMotion(
                delay: const Duration(milliseconds: 200),
                child: _ExplorerSection<SchoolClass>(
                  tone: const Color(0xFF7C3AED),
                  title: 'Classes',
                  subtitle: _selectedSchoolId == null
                      ? 'Choose a school to load classes.'
                      : 'Inspect the classroom layer with stronger cards and clearer metrics.',
                  items: classes,
                  selectedId: _selectedClassId,
                  loading: classesAsync.isLoading,
                  emptyMessage: _selectedSchoolId == null
                      ? 'Select a school first.'
                      : 'No classes found for this school.',
                  itemBuilder: (SchoolClass schoolClass, bool selected) =>
                      _EntityTile(
                        selected: selected,
                        tone: const Color(0xFF7C3AED),
                        icon: Icons.meeting_room_rounded,
                        title: schoolClass.name,
                        subtitle:
                            '${schoolClass.totalStudents} learners • ${schoolClass.teacher}',
                        stats: <String>[
                          'Attendance ${schoolClass.averageAttendance}%',
                          'Score ${schoolClass.averageScore}%',
                        ],
                        badgeLabel: 'Teacher',
                      ),
                  onTap: (SchoolClass schoolClass) {
                    setState(() {
                      _selectedClassId = schoolClass.id;
                      _selectedStudentId = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              RevealMotion(
                delay: const Duration(milliseconds: 240),
                child: _ExplorerSection<Student>(
                  tone: const Color(0xFFEA580C),
                  title: 'Students',
                  subtitle: _selectedClassId == null
                      ? 'Choose a class to inspect learners.'
                      : 'Move from classroom summary into the learner profile without leaving the design system.',
                  items: students,
                  selectedId: _selectedStudentId,
                  loading: studentsAsync.isLoading,
                  emptyMessage: _selectedClassId == null
                      ? 'Select a class first.'
                      : 'No students found for this class.',
                  itemBuilder: (Student student, bool selected) => _EntityTile(
                    selected: selected,
                    tone: _riskColor(student.riskLevel),
                    icon: Icons.person_rounded,
                    title: student.fullName,
                    subtitle:
                        '${student.gradeLevel} • GPA ${student.gpa} • ${student.riskLevel.label}',
                    stats: <String>[
                      'Attendance ${student.attendanceRate}%',
                      'Score ${student.averageScore}%',
                    ],
                    badgeLabel: student.riskLevel.label,
                  ),
                  onTap: (Student student) {
                    setState(() {
                      _selectedStudentId = student.id;
                    });
                    context.go('/student/${student.id}');
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load explorer data: $error'),
          ),
        ),
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _selectedDistrictId = null;
      _selectedSchoolId = null;
      _selectedClassId = null;
      _selectedStudentId = null;
    });
  }

  T? _findById<T>(List<T> items, String? id, String Function(T item) selector) {
    if (id == null) {
      return null;
    }
    for (final T item in items) {
      if (selector(item) == id) {
        return item;
      }
    }
    return null;
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.stable:
        return const Color(0xFF0F766E);
      case RiskLevel.watch:
        return const Color(0xFFEA580C);
      case RiskLevel.urgent:
        return const Color(0xFFB91C1C);
    }
  }
}

class _ExplorerHero extends StatelessWidget {
  const _ExplorerHero({
    required this.district,
    required this.school,
    required this.schoolClass,
    required this.student,
    required this.onReset,
    required this.onBackToDistrict,
    required this.onBackToSchool,
    required this.onBackToClass,
  });

  final District? district;
  final School? school;
  final SchoolClass? schoolClass;
  final Student? student;
  final VoidCallback onReset;
  final VoidCallback? onBackToDistrict;
  final VoidCallback? onBackToSchool;
  final VoidCallback? onBackToClass;

  @override
  Widget build(BuildContext context) {
    final List<Widget> crumbs = <Widget>[
      _Crumb(label: 'All districts', onTap: onReset),
      if (district != null)
        _Crumb(label: district!.name, onTap: onBackToDistrict ?? onReset),
      if (school != null)
        _Crumb(label: school!.name, onTap: onBackToSchool ?? onReset),
      if (schoolClass != null)
        _Crumb(label: schoolClass!.name, onTap: onBackToClass ?? onReset),
      if (student != null) _Crumb(label: student!.fullName, onTap: onReset),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 560;
        return Container(
          padding: EdgeInsets.all(compact ? 20 : 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 28 : 34),
            gradient: const LinearGradient(
              colors: <Color>[
                Color(0xFF081423),
                Color(0xFF163255),
                Color(0xFF0F766E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _Badge(
                label: 'Hierarchy drill-down',
                tone: Colors.white24,
                textColor: Colors.white,
              ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                'Drill down, roll up, and keep context visible.',
                style:
                    (compact
                            ? Theme.of(context).textTheme.headlineSmall
                            : Theme.of(context).textTheme.headlineMedium)
                        ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Every selection layer now shares the same reporting visual system used across dashboard, analytics, and results.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                  height: compact ? 1.35 : 1.45,
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Wrap(spacing: 10, runSpacing: 10, children: crumbs),
            ],
          ),
        );
      },
    );
  }
}

class _ScopeBoard extends StatelessWidget {
  const _ScopeBoard({required this.scope});

  final ScopeSummary scope;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(30),
      shadowColor: const Color(0xFF155EEF),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 560;
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFF9FBFF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFDCE7FA)),
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 18 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    scope.title,
                    style: compact
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    scope.subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _MiniStat(
                        label: 'Learners',
                        value: '${scope.totalStudents}',
                        tone: const Color(0xFFEAF1FF),
                      ),
                      _MiniStat(
                        label: 'Attendance',
                        value: '${scope.averageAttendance}%',
                        tone: const Color(0xFFE8F7EE),
                      ),
                      _MiniStat(
                        label: 'Score',
                        value: '${scope.averageScore}%',
                        tone: const Color(0xFFF4EBFF),
                      ),
                      _MiniStat(
                        label: 'At risk',
                        value: '${scope.atRiskStudents}',
                        tone: const Color(0xFFFFF4E8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool stacked = constraints.maxWidth < 940;
                          final Widget trendPanel = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Performance trend',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: compact ? 190 : 220,
                                child: _ScopeTrendChart(points: scope.trend),
                              ),
                            ],
                          );
                          final Widget distributionPanel = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Intervention mix',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              ...scope.riskDistribution.entries.map((
                                MapEntry<String, int> entry,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _DistributionBar(
                                    label: entry.key,
                                    value: entry.value,
                                    max: scope.totalStudents == 0
                                        ? 1
                                        : scope.totalStudents,
                                    color: _distributionColor(entry.key),
                                  ),
                                );
                              }),
                              const SizedBox(height: 4),
                              _Badge(
                                label: 'Top performer: ${scope.topPerformer}',
                                tone: const Color(0xFFEAF1FF),
                                textColor: const Color(0xFF155EEF),
                              ),
                            ],
                          );

                          if (stacked) {
                            return Column(
                              children: <Widget>[
                                trendPanel,
                                const SizedBox(height: 18),
                                distributionPanel,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: trendPanel),
                              const SizedBox(width: 18),
                              Expanded(child: distributionPanel),
                            ],
                          );
                        },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _distributionColor(String label) {
    switch (label) {
      case 'Stable':
        return const Color(0xFF0F766E);
      case 'Watch':
        return const Color(0xFFEA580C);
      case 'Urgent':
        return const Color(0xFFB91C1C);
    }
    return Colors.grey;
  }
}

class _ExplorerSection<T> extends StatelessWidget {
  const _ExplorerSection({
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.selectedId,
    required this.itemBuilder,
    required this.onTap,
    this.loading = false,
    this.emptyMessage = 'Nothing to show yet.',
  });

  final Color tone;
  final String title;
  final String subtitle;
  final List<T> items;
  final String? selectedId;
  final bool loading;
  final String emptyMessage;
  final Widget Function(T item, bool selected) itemBuilder;
  final void Function(T item) onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(30),
      shadowColor: tone,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 560;
          final double tileWidth = constraints.maxWidth < 720
              ? constraints.maxWidth
              : 300;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[tone.withValues(alpha: 0.06), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: tone.withValues(alpha: 0.14)),
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 18 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: compact
                        ? Theme.of(context).textTheme.titleMedium
                        : Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (loading)
                    const Center(child: CircularProgressIndicator())
                  else if (items.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(emptyMessage),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: items.map((T item) {
                        final String id = _extractId(item);
                        return SizedBox(
                          width: tileWidth,
                          child: HoverLift(
                            borderRadius: BorderRadius.circular(22),
                            shadowColor: tone,
                            child: InkWell(
                              onTap: () => onTap(item),
                              borderRadius: BorderRadius.circular(22),
                              child: itemBuilder(item, id == selectedId),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _extractId(T item) {
    final dynamic dynamicItem = item;
    return dynamicItem.id as String;
  }
}

class _EntityTile extends StatelessWidget {
  const _EntityTile({
    required this.selected,
    required this.tone,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.stats,
    required this.badgeLabel,
  });

  final bool selected;
  final Color tone;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> stats;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 260;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.all(compact ? 16 : 18),
          decoration: BoxDecoration(
            color: selected ? tone.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? tone : const Color(0xFFE2E8F0),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: tone.withValues(alpha: selected ? 0.12 : 0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: tone),
                  ),
                  _Badge(
                    label: badgeLabel,
                    tone: tone.withValues(alpha: 0.1),
                    textColor: tone,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              ...stats.map((String stat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    stat,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white.withValues(alpha: 0.16),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: Colors.white),
      side: BorderSide.none,
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 170),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _ScopeTrendChart extends StatelessWidget {
  const _ScopeTrendChart({required this.points});

  final List<ScorePoint> points;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: const Color(0xFFE5ECF6), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 20,
              getTitlesWidget: (double value, TitleMeta meta) =>
                  Text(value.toInt().toString()),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(points[index].label),
                );
              },
            ),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: List<FlSpot>.generate(
              points.length,
              (int index) => FlSpot(index.toDouble(), points[index].value),
            ),
            isCurved: true,
            barWidth: 4,
            color: const Color(0xFF155EEF),
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF155EEF).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double ratio = max == 0 ? 0 : value / max;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[Text(label), Text('$value')],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: const Color(0xFFE6ECE8),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: textColor),
      ),
    );
  }
}
