import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final TeacherAccount? currentTeacher = ref.watch(currentTeacherProvider);
    final SessionUser? session = adminState.session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_outline_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Login required',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose Teacher or Headmaster before opening the dashboard.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool canUploadScores =
        session.role == UserRole.headOfSchool ||
        (currentTeacher?.canUploadResults ?? false);
    final List<StudentResultRecord> watchlist = overview.studentResults
        .where(
          (StudentResultRecord record) => record.riskLevel != RiskLevel.stable,
        )
        .take(4)
        .toList();
    final List<StudentResultRecord> topStudents = overview.studentResults
        .take(5)
        .toList();

    return WorkspaceShell(
      currentSection: WorkspaceSection.dashboard,
      session: session,
      title: session.role == UserRole.headOfSchool
          ? 'Headmaster Dashboard'
          : 'Teacher Dashboard',
      subtitle: session.role == UserRole.headOfSchool
          ? 'See the school pulse, result window status, staff permissions, and intervention pressure from one command surface.'
          : 'Track your class, your subject, and your result-entry workload in a stronger day-to-day workspace.',
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => context.go('/manage?tab=students'),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Student'),
        ),
        FilledButton.tonalIcon(
          onPressed: canUploadScores
              ? () => context.go('/manage?tab=results')
              : null,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Update Results'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/records'),
          icon: const Icon(Icons.history_edu_rounded),
          label: const Text('Historical Records'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/profiles'),
          icon: const Icon(Icons.perm_media_rounded),
          label: const Text('Profiles'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(schoolAdminProvider.notifier).logout();
            context.go('/login');
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Logout'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          RevealMotion(
            child: _DashboardHero(
              session: session,
              overview: overview,
              resultWindow: adminState.resultWindow,
            ),
          ),
          const SizedBox(height: 18),
          RevealMotion(
            delay: const Duration(milliseconds: 70),
            child: _MetricsRail(
              overview: overview,
              session: session,
              currentTeacher: currentTeacher,
            ),
          ),
          const SizedBox(height: 18),
          RevealMotion(
            delay: const Duration(milliseconds: 140),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 1220;
                final Widget leftColumn = Column(
                  children: <Widget>[
                    _SurfaceBoard(
                      tone: const Color(0xFF155EEF),
                      title: 'School Momentum',
                      subtitle:
                          'Term movement and inter-exam progression framed like a real performance board, not a placeholder chart block.',
                      header: _BoardBadge(
                        label:
                            '${overview.averageScore.toStringAsFixed(1)}% live average',
                        tone: const Color(0xFFEAF1FF),
                        textColor: const Color(0xFF155EEF),
                      ),
                      child: Column(
                        children: <Widget>[
                          SizedBox(
                            height: 280,
                            child: _TrendChart(points: overview.systemTrend),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              _InsightChip(
                                title: 'Inter Exam',
                                value:
                                    '${overview.averageInterExamScore.toStringAsFixed(1)}%',
                                tone: const Color(0xFFEAF1FF),
                              ),
                              _InsightChip(
                                title: 'Pass Rate',
                                value:
                                    '${overview.passRate.toStringAsFixed(1)}%',
                                tone: const Color(0xFFE8F7EE),
                              ),
                              _InsightChip(
                                title: 'Division I',
                                value:
                                    '${overview.divisionDistribution['Division I'] ?? 0}',
                                tone: const Color(0xFFF4EBFF),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SurfaceBoard(
                      tone: const Color(0xFF0F766E),
                      title: 'Division Landscape',
                      subtitle:
                          'Shows how learners are distributed across divisions so leadership can see outcome quality at a glance.',
                      header: _BoardBadge(
                        label: '${overview.totalStudents} learner records',
                        tone: const Color(0xFFE8F7EE),
                        textColor: const Color(0xFF0F766E),
                      ),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final bool compact = constraints.maxWidth < 860;
                              final Widget chart = SizedBox(
                                height: 240,
                                child: _DivisionChart(
                                  distribution: overview.divisionDistribution,
                                ),
                              );
                              final Widget breakdown = Column(
                                children: overview.divisionDistribution.entries
                                    .map((MapEntry<String, int> entry) {
                                      final double ratio =
                                          overview.totalStudents == 0
                                          ? 0
                                          : entry.value /
                                                overview.totalStudents;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _DivisionTile(
                                          label: entry.key,
                                          count: entry.value,
                                          ratio: ratio,
                                        ),
                                      );
                                    })
                                    .toList(),
                              );

                              if (compact) {
                                return Column(
                                  children: <Widget>[
                                    chart,
                                    const SizedBox(height: 18),
                                    breakdown,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(flex: 5, child: chart),
                                  const SizedBox(width: 18),
                                  Expanded(flex: 4, child: breakdown),
                                ],
                              );
                            },
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SurfaceBoard(
                      tone: const Color(0xFFEA580C),
                      title: 'Top Performers',
                      subtitle:
                          'Fast entry into detailed result sheets, with stronger presentation for the students driving the best outcomes.',
                      header: _BoardBadge(
                        label: 'Open detailed report',
                        tone: const Color(0xFFFFF4E8),
                        textColor: const Color(0xFFEA580C),
                      ),
                      child: Column(
                        children: topStudents.map((StudentResultRecord record) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TopStudentTile(record: record),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );

                final Widget rightColumn = session.role == UserRole.headOfSchool
                    ? Column(
                        children: <Widget>[
                          _LeadershipSnapshot(
                            overview: overview,
                            resultWindow: adminState.resultWindow,
                          ),
                          const SizedBox(height: 18),
                          _HeadmasterControls(state: adminState),
                          const SizedBox(height: 18),
                          _TeacherRosterPanel(
                            state: adminState,
                            studentResults: overview.studentResults,
                          ),
                          const SizedBox(height: 18),
                          _InterventionBoard(watchlist: watchlist),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          _TeacherIdentityBoard(
                            teacher: currentTeacher,
                            resultWindow: adminState.resultWindow,
                            overview: overview,
                          ),
                          const SizedBox(height: 18),
                          _TeacherPerformanceBoard(
                            teacher: currentTeacher,
                            subjectSummaries: overview.subjectPerformance,
                            classSummaries: overview.classPerformance,
                          ),
                          const SizedBox(height: 18),
                          _TeacherWorkflowBoard(
                            canUploadScores: canUploadScores,
                          ),
                        ],
                      );

                if (stacked) {
                  return Column(
                    children: <Widget>[
                      leftColumn,
                      const SizedBox(height: 18),
                      rightColumn,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 7, child: leftColumn),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: rightColumn),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.session,
    required this.overview,
    required this.resultWindow,
  });

  final SessionUser session;
  final SchoolOverview overview;
  final ResultWindowSettings resultWindow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF081423),
            Color(0xFF0F2D4A),
            Color(0xFF155EEF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stacked = constraints.maxWidth < 980;
          final Widget leftContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _BoardBadge(
                label: '${session.role.shortLabel} control active',
                tone: Colors.white.withValues(alpha: 0.12),
                textColor: Colors.white,
              ),
              const SizedBox(height: 18),
              Text(
                session.role == UserRole.headOfSchool
                    ? 'The school now reads like one coordinated operating system.'
                    : 'Your teaching workflow now sits inside the same command view as school performance.',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                '${overview.schoolName} • ${overview.districtName} • ${overview.totalClasses} active classes',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _BoardBadge(
                    label:
                        'Upload closes ${_dateLabel(resultWindow.uploadDeadline)}',
                    tone: Colors.white.withValues(alpha: 0.12),
                    textColor: Colors.white,
                  ),
                  _BoardBadge(
                    label:
                        'Edit closes ${_dateLabel(resultWindow.editDeadline)}',
                    tone: Colors.white.withValues(alpha: 0.12),
                    textColor: Colors.white,
                  ),
                  _BoardBadge(
                    label:
                        '${overview.divisionDistribution['Division I'] ?? 0} in Division I',
                    tone: Colors.white.withValues(alpha: 0.12),
                    textColor: Colors.white,
                  ),
                ],
              ),
            ],
          );

          final Widget rightContent = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Live window posture',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                _HeroInfoRow(
                  label: 'Editing',
                  value: resultWindow.editingLocked ? 'Locked' : 'Open',
                ),
                const SizedBox(height: 10),
                _HeroInfoRow(
                  label: 'Pass rate',
                  value: '${overview.passRate.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 10),
                _HeroInfoRow(
                  label: 'Inter exam',
                  value:
                      '${overview.averageInterExamScore.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 10),
                _HeroInfoRow(
                  label: 'Records ready',
                  value: '${overview.totalStudents}',
                ),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                leftContent,
                const SizedBox(height: 18),
                rightContent,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 6, child: leftContent),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: rightContent),
            ],
          );
        },
      ),
    );
  }

  static String _dateLabel(DateTime value) {
    return '${value.month}/${value.day}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _MetricsRail extends StatelessWidget {
  const _MetricsRail({
    required this.overview,
    required this.session,
    required this.currentTeacher,
  });

  final SchoolOverview overview;
  final SessionUser session;
  final TeacherAccount? currentTeacher;

  @override
  Widget build(BuildContext context) {
    final List<_MetricModel> metrics = <_MetricModel>[
      _MetricModel(
        title: 'Students',
        value: '${overview.totalStudents}',
        caption: 'Tracked records',
        tone: const Color(0xFF155EEF),
        icon: Icons.groups_rounded,
      ),
      _MetricModel(
        title: 'Teaching Staff',
        value: '${overview.totalTeachers}',
        caption: 'Accounted users',
        tone: const Color(0xFF0F766E),
        icon: Icons.badge_rounded,
      ),
      _MetricModel(
        title: 'Average Score',
        value: '${overview.averageScore.toStringAsFixed(1)}%',
        caption: 'Across seven subjects',
        tone: const Color(0xFF7C3AED),
        icon: Icons.timeline_rounded,
      ),
      _MetricModel(
        title: session.role == UserRole.headOfSchool ? 'Watchlist' : 'My Class',
        value: session.role == UserRole.headOfSchool
            ? '${overview.studentResults.where((StudentResultRecord item) => item.riskLevel != RiskLevel.stable).length}'
            : (currentTeacher?.assignedClass ?? 'Unset'),
        caption: session.role == UserRole.headOfSchool
            ? 'Intervention pressure'
            : 'Current teaching group',
        tone: const Color(0xFFEA580C),
        icon: session.role == UserRole.headOfSchool
            ? Icons.warning_amber_rounded
            : Icons.class_rounded,
      ),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: metrics.map((_MetricModel metric) {
        return _MetricStripCard(metric: metric);
      }).toList(),
    );
  }
}

class _LeadershipSnapshot extends StatelessWidget {
  const _LeadershipSnapshot({
    required this.overview,
    required this.resultWindow,
  });

  final SchoolOverview overview;
  final ResultWindowSettings resultWindow;

  @override
  Widget build(BuildContext context) {
    return _SurfaceBoard(
      tone: const Color(0xFF7C3AED),
      title: 'Leadership Snapshot',
      subtitle:
          'A compact command card for the headmaster that keeps deadlines, quality, and intervention pressure in one place.',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _ScoreTile(
                  title: 'Upload Window',
                  value: resultWindow.editingLocked ? 'Closing' : 'Active',
                  tone: const Color(0xFFEAF1FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreTile(
                  title: 'Division I',
                  value: '${overview.divisionDistribution['Division I'] ?? 0}',
                  tone: const Color(0xFFF4EBFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _ScoreTile(
                  title: 'Pass Rate',
                  value: '${overview.passRate.toStringAsFixed(1)}%',
                  tone: const Color(0xFFE8F7EE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreTile(
                  title: 'Inter Exam',
                  value:
                      '${overview.averageInterExamScore.toStringAsFixed(1)}%',
                  tone: const Color(0xFFFFF4E8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherIdentityBoard extends StatelessWidget {
  const _TeacherIdentityBoard({
    required this.teacher,
    required this.resultWindow,
    required this.overview,
  });

  final TeacherAccount? teacher;
  final ResultWindowSettings resultWindow;
  final SchoolOverview overview;

  @override
  Widget build(BuildContext context) {
    return _SurfaceBoard(
      tone: const Color(0xFF0F766E),
      title: 'Teacher Access',
      subtitle:
          'A cleaner identity and permission card with context about class assignment and the live reporting window.',
      child: teacher == null
          ? const Text('No teacher profile was found for this session.')
          : Column(
              children: <Widget>[
                _ScoreTile(
                  title: teacher!.name,
                  value: '${teacher!.subject} • ${teacher!.assignedClass}',
                  tone: const Color(0xFFEAF1FF),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ScoreTile(
                        title: 'Upload',
                        value: teacher!.canUploadResults
                            ? 'Allowed'
                            : 'Blocked',
                        tone: teacher!.canUploadResults
                            ? const Color(0xFFE8F7EE)
                            : const Color(0xFFFFE8E8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ScoreTile(
                        title: 'Edit',
                        value:
                            !resultWindow.editingLocked &&
                                teacher!.canEditResults
                            ? 'Allowed'
                            : 'Blocked',
                        tone:
                            !resultWindow.editingLocked &&
                                teacher!.canEditResults
                            ? const Color(0xFFF4EBFF)
                            : const Color(0xFFFFF4E8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ScoreTile(
                  title: 'School average',
                  value: '${overview.averageScore.toStringAsFixed(1)}%',
                  tone: const Color(0xFFF8FAFC),
                ),
              ],
            ),
    );
  }
}

class _TeacherPerformanceBoard extends StatelessWidget {
  const _TeacherPerformanceBoard({
    required this.teacher,
    required this.subjectSummaries,
    required this.classSummaries,
  });

  final TeacherAccount? teacher;
  final List<SubjectPerformanceSummary> subjectSummaries;
  final List<ClassPerformanceSummary> classSummaries;

  @override
  Widget build(BuildContext context) {
    if (teacher == null) {
      return const SizedBox.shrink();
    }

    if (subjectSummaries.isEmpty || classSummaries.isEmpty) {
      return _SurfaceBoard(
        tone: const Color(0xFF155EEF),
        title: 'My Performance Snapshot',
        subtitle:
            'Subject and class performance will appear after result uploads exist for registered students.',
        child: const Text(
          'No uploaded result data yet. Use Manage Result Upload after students are registered.',
        ),
      );
    }

    final SubjectPerformanceSummary subjectSummary = subjectSummaries
        .firstWhere(
          (SubjectPerformanceSummary item) => item.subject == teacher!.subject,
          orElse: () => subjectSummaries.first,
        );
    final ClassPerformanceSummary classSummary = classSummaries.firstWhere(
      (ClassPerformanceSummary item) =>
          item.className == teacher!.assignedClass,
      orElse: () => classSummaries.first,
    );

    return _SurfaceBoard(
      tone: const Color(0xFF155EEF),
      title: 'My Performance Snapshot',
      subtitle:
          'Subject performance and assigned class are presented as one connected teaching story instead of separate small utility boxes.',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _ScoreTile(
                  title: teacher!.subject,
                  value: '${subjectSummary.averageScore.toStringAsFixed(1)}%',
                  tone: const Color(0xFFEAF1FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreTile(
                  title: 'Pass Rate',
                  value: '${subjectSummary.passRate.toStringAsFixed(1)}%',
                  tone: const Color(0xFFE8F7EE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _ScoreTile(
                  title: classSummary.className,
                  value: '${classSummary.averageScore.toStringAsFixed(1)}%',
                  tone: const Color(0xFFF4EBFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreTile(
                  title: 'Top Student',
                  value: classSummary.topStudent,
                  tone: const Color(0xFFFFF4E8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherWorkflowBoard extends StatelessWidget {
  const _TeacherWorkflowBoard({required this.canUploadScores});

  final bool canUploadScores;

  @override
  Widget build(BuildContext context) {
    return _SurfaceBoard(
      tone: const Color(0xFFEA580C),
      title: 'Teacher Workflow',
      subtitle:
          'Stronger visual guidance for the daily routine so action order feels deliberate and professional.',
      child: Column(
        children: <Widget>[
          _WorkflowTile(
            icon: Icons.playlist_add_rounded,
            title: '1. Select class first',
            description:
                'Move into the management workspace and start from form and class so result entry stays accurate.',
          ),
          const SizedBox(height: 12),
          _WorkflowTile(
            icon: Icons.edit_note_rounded,
            title: '2. Enter boxed subject scores',
            description:
                'Use the dedicated subject card with separate exam rows and inter exam score, not manual comma entry.',
          ),
          const SizedBox(height: 12),
          _WorkflowTile(
            icon: canUploadScores
                ? Icons.check_circle_rounded
                : Icons.lock_clock_rounded,
            title: '3. Save within active window',
            description: canUploadScores
                ? 'You currently have permission to update result sections.'
                : 'Your upload access is currently blocked by the control window.',
          ),
        ],
      ),
    );
  }
}

class _InterventionBoard extends StatelessWidget {
  const _InterventionBoard({required this.watchlist});

  final List<StudentResultRecord> watchlist;

  @override
  Widget build(BuildContext context) {
    return _SurfaceBoard(
      tone: const Color(0xFFB91C1C),
      title: 'Intervention Watchlist',
      subtitle:
          'A redesigned risk board for students that need leadership attention right now.',
      child: watchlist.isEmpty
          ? const Text('No students are currently flagged for intervention.')
          : Column(
              children: watchlist.map((StudentResultRecord record) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WatchTile(record: record),
                );
              }).toList(),
            ),
    );
  }
}

class _HeadmasterControls extends ConsumerWidget {
  const _HeadmasterControls({required this.state});

  final SchoolAdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminController controller = ref.read(
      schoolAdminProvider.notifier,
    );
    return _SurfaceBoard(
      tone: const Color(0xFF0F766E),
      title: 'Result Window Controls',
      subtitle:
          'The control board is now framed as an operational console instead of a plain settings list.',
      child: Column(
        children: <Widget>[
          _ControlTile(
            label: 'Upload deadline',
            value: _DashboardHero._dateLabel(state.resultWindow.uploadDeadline),
            action: FilledButton.tonal(
              onPressed: () =>
                  controller.extendUploadDeadline(const Duration(days: 1)),
              child: const Text('+1 day'),
            ),
          ),
          const SizedBox(height: 12),
          _ControlTile(
            label: 'Edit deadline',
            value: _DashboardHero._dateLabel(state.resultWindow.editDeadline),
            action: FilledButton.tonal(
              onPressed: () =>
                  controller.extendEditDeadline(const Duration(days: 1)),
              child: const Text('+1 day'),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Edit lock'),
                      SizedBox(height: 6),
                      Text(
                        'Lock or unlock result corrections after submission.',
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.resultWindow.editingLocked,
                  onChanged: controller.setEditingLocked,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherRosterPanel extends ConsumerWidget {
  const _TeacherRosterPanel({
    required this.state,
    required this.studentResults,
  });

  final SchoolAdminState state;
  final List<StudentResultRecord> studentResults;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminController controller = ref.read(
      schoolAdminProvider.notifier,
    );
    return _SurfaceBoard(
      tone: const Color(0xFF155EEF),
      title: 'Teacher Control Board',
      subtitle:
          'Permission toggles now sit inside a stronger staff board with clear assignment context.',
      child: Column(
        children: state.teachers.map((TeacherAccount teacher) {
          final int classSize = studentResults
              .where(
                (StudentResultRecord record) =>
                    record.className == teacher.assignedClass,
              )
              .length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
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
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEAF1FF),
                        child: Text(teacher.name.substring(0, 1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              teacher.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${teacher.subject} • ${teacher.assignedClass} • $classSize students',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ToggleTile(
                          label: 'Upload',
                          value: teacher.canUploadResults,
                          onChanged: (_) =>
                              controller.toggleTeacherUpload(teacher.id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ToggleTile(
                          label: 'Edit',
                          value: teacher.canEditResults,
                          onChanged: (_) =>
                              controller.toggleTeacherEdit(teacher.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SurfaceBoard extends StatelessWidget {
  const _SurfaceBoard({
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.child,
    this.header,
  });

  final Color tone;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[tone.withValues(alpha: 0.06), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: tone.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                  if (header != null) ...<Widget>[
                    const SizedBox(width: 12),
                    header!,
                  ],
                ],
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricStripCard extends StatelessWidget {
  const _MetricStripCard({required this.metric});

  final _MetricModel metric;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        width: 255,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: metric.tone.withValues(alpha: 0.14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: metric.tone.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: metric.tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(metric.icon, color: metric.tone),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _BoardBadge(
                          label: metric.caption,
                          tone: metric.tone.withValues(alpha: 0.08),
                          textColor: metric.tone,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                metric.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                metric.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DivisionTile extends StatelessWidget {
  const _DivisionTile({
    required this.label,
    required this.count,
    required this.ratio,
  });

  final String label;
  final int count;
  final double ratio;

  @override
  Widget build(BuildContext context) {
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
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('$count', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0F766E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStudentTile extends StatelessWidget {
  const _TopStudentTile({required this.record});

  final StudentResultRecord record;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => context.go('/results/${record.id}'),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF155EEF), Color(0xFF0F766E)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  record.studentName.substring(0, 1),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.studentName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('${record.className} • ${record.division}'),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${record.averageScore.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.arrow_outward_rounded, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchTile extends StatelessWidget {
  const _WatchTile({required this.record});

  final StudentResultRecord record;

  @override
  Widget build(BuildContext context) {
    final Color tone = record.riskLevel == RiskLevel.urgent
        ? const Color(0xFFB91C1C)
        : const Color(0xFFEA580C);
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: tone,
      child: InkWell(
        onTap: () => context.go('/results/${record.id}'),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tone.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.warning_amber_rounded, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.studentName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.className} • ${record.averageScore.toStringAsFixed(1)}% • ${record.riskLevel.label}',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

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
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
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
            isCurved: true,
            barWidth: 5,
            color: const Color(0xFF155EEF),
            dotData: FlDotData(
              show: true,
              getDotPainter:
                  (
                    FlSpot spot,
                    double percent,
                    LineChartBarData bar,
                    int index,
                  ) {
                    return FlDotCirclePainter(
                      radius: 4.5,
                      color: Colors.white,
                      strokeColor: const Color(0xFF155EEF),
                      strokeWidth: 3,
                    );
                  },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFF155EEF).withValues(alpha: 0.22),
                  const Color(0xFF155EEF).withValues(alpha: 0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            spots: points.asMap().entries.map((
              MapEntry<int, ScorePoint> entry,
            ) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DivisionChart extends StatelessWidget {
  const _DivisionChart({required this.distribution});

  final Map<String, int> distribution;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> entries = distribution.entries.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: const Color(0xFFE5ECF6), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(entries[index].key.replaceAll('Division ', 'D')),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
        ),
        barGroups: entries.asMap().entries.map((
          MapEntry<int, MapEntry<String, int>> entry,
        ) {
          final Color color = switch (entry.key) {
            0 => const Color(0xFF0F766E),
            1 => const Color(0xFF155EEF),
            2 => const Color(0xFF7C3AED),
            3 => const Color(0xFFEA580C),
            _ => const Color(0xFFB91C1C),
          };
          return BarChartGroupData(
            x: entry.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: entry.value.value.toDouble(),
                color: color,
                width: 24,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.label,
    required this.value,
    required this.action,
  });

  final String label;
  final String value;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: const Color(0xFF0F766E),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(value),
                ],
              ),
            ),
            const SizedBox(width: 12),
            action,
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(18),
      shadowColor: const Color(0xFF155EEF),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _WorkflowTile extends StatelessWidget {
  const _WorkflowTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(20),
      shadowColor: const Color(0xFFEA580C),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF5DEC6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFEA580C)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({
    required this.title,
    required this.value,
    required this.tone,
  });

  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(20),
      shadowColor: const Color(0xFF0F172A),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.title,
    required this.value,
    required this.tone,
  });

  final String title;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: const Color(0xFF0F172A),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _BoardBadge extends StatelessWidget {
  const _BoardBadge({
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

class _HeroInfoRow extends StatelessWidget {
  const _HeroInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _MetricModel {
  const _MetricModel({
    required this.title,
    required this.value,
    required this.caption,
    required this.tone,
    required this.icon,
  });

  final String title;
  final String value;
  final String caption;
  final Color tone;
  final IconData icon;
}
