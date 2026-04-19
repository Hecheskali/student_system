import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

class StudentDetailScreen extends ConsumerWidget {
  const StudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(schoolAdminProvider).session;
    final AsyncValue<Student?> studentAsync = ref.watch(
      studentProvider(studentId),
    );

    return studentAsync.when(
      data: (Student? student) {
        if (student == null) {
          return const Scaffold(
            body: Center(child: Text('Student not found.')),
          );
        }

        return WorkspaceShell(
          currentSection: WorkspaceSection.explorer,
          session: session,
          title: '${student.fullName} Profile',
          subtitle:
              'The student lens now shares the same design system as results, analytics, and the explorer path.',
          actions: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => context.go(
                '/explorer?districtId=${student.districtId}&schoolId=${student.schoolId}&classId=${student.classId}&studentId=${student.id}',
              ),
              icon: const Icon(Icons.account_tree_rounded),
              label: const Text('Back to Explorer Context'),
            ),
          ],
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: <Widget>[
              RevealMotion(child: _StudentHero(student: student)),
              const SizedBox(height: 18),
              RevealMotion(
                delay: const Duration(milliseconds: 70),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: <Widget>[
                    _MetricCard(
                      label: 'Average Score',
                      value: '${student.averageScore}%',
                      detail: 'Current academic level',
                      tone: const Color(0xFF0F766E),
                    ),
                    _MetricCard(
                      label: 'Attendance',
                      value: '${student.attendanceRate}%',
                      detail: 'Participation signal',
                      tone: const Color(0xFF155EEF),
                    ),
                    _MetricCard(
                      label: 'GPA',
                      value: '${student.gpa}',
                      detail: 'Weighted score marker',
                      tone: const Color(0xFF7C3AED),
                    ),
                    _MetricCard(
                      label: 'Risk',
                      value: student.riskLevel.label,
                      detail: 'Intervention band',
                      tone: _riskColor(student.riskLevel),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              RevealMotion(
                delay: const Duration(milliseconds: 140),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = constraints.maxWidth < 1180;
                    final Widget leftColumn = Column(
                      children: <Widget>[
                        _StudentBoard(
                          tone: const Color(0xFF155EEF),
                          title: 'Performance Trend',
                          subtitle:
                              'The learner trend is now framed like a real insight board instead of a generic chart panel.',
                          child: SizedBox(
                            height: 280,
                            child: _StudentTrendChart(student: student),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _StudentBoard(
                          tone: const Color(0xFF0F766E),
                          title: 'Subject Profile',
                          subtitle:
                              'Subject results are presented as richer cards with clear strength and weakness cues.',
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: student.subjectScores.entries.map((
                              MapEntry<String, double> entry,
                            ) {
                              return _SubjectCard(
                                label: entry.key,
                                value: entry.value,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );

                    final Widget rightColumn = Column(
                      children: <Widget>[
                        _StudentBoard(
                          tone: const Color(0xFF7C3AED),
                          title: 'Student Snapshot',
                          subtitle:
                              'A cleaner summary card for the most important profile details.',
                          child: Column(
                            children: <Widget>[
                              _StatRow(
                                label: 'Grade level',
                                value: student.gradeLevel,
                              ),
                              const SizedBox(height: 10),
                              _StatRow(label: 'Class', value: student.classId),
                              const SizedBox(height: 10),
                              _StatRow(
                                label: 'School',
                                value: student.schoolId,
                              ),
                              const SizedBox(height: 10),
                              _StatRow(
                                label: 'District',
                                value: student.districtId,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _StudentBoard(
                          tone: const Color(0xFFEA580C),
                          title: 'Context Navigation',
                          subtitle:
                              'Jump back up the hierarchy without breaking the visual flow of the product.',
                          child: Column(
                            children: <Widget>[
                              _JumpTile(
                                title: 'Class context',
                                description:
                                    'Return to the selected class level in explorer.',
                                onTap: () => context.go(
                                  '/explorer?districtId=${student.districtId}&schoolId=${student.schoolId}&classId=${student.classId}&studentId=${student.id}',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _JumpTile(
                                title: 'School context',
                                description:
                                    'Roll up to the school layer and compare class performance.',
                                onTap: () => context.go(
                                  '/explorer?districtId=${student.districtId}&schoolId=${student.schoolId}',
                                ),
                              ),
                              const SizedBox(height: 12),
                              _JumpTile(
                                title: 'District context',
                                description:
                                    'Return to the district view for broader monitoring.',
                                onTap: () => context.go(
                                  '/explorer?districtId=${student.districtId}',
                                ),
                              ),
                            ],
                          ),
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
                        Expanded(flex: 6, child: leftColumn),
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: rightColumn),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load student profile: $error'),
          ),
        ),
      ),
    );
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

class _StudentHero extends StatelessWidget {
  const _StudentHero({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final Color riskColor = _resolveRiskColor(student.riskLevel);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF081423),
            Color(0xFF17335A),
            Color(0xFF155EEF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stacked = constraints.maxWidth < 980;
          final Widget leftContent = Row(
            children: <Widget>[
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  student.fullName.substring(0, 1),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      student.fullName,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${student.gradeLevel} • ${student.classId}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RiskBadge(
                      label: '${student.riskLevel.label} intervention band',
                      tone: riskColor,
                    ),
                  ],
                ),
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
                  'Live learner signals',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                _HeroInfo(label: 'Average', value: '${student.averageScore}%'),
                const SizedBox(height: 10),
                _HeroInfo(
                  label: 'Attendance',
                  value: '${student.attendanceRate}%',
                ),
                const SizedBox(height: 10),
                _HeroInfo(label: 'GPA', value: '${student.gpa}'),
                const SizedBox(height: 10),
                _HeroInfo(
                  label: 'Subjects',
                  value: '${student.subjectScores.length}',
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

  Color _resolveRiskColor(RiskLevel level) {
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

class _StudentBoard extends StatelessWidget {
  const _StudentBoard({
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final Color tone;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(30),
      shadowColor: tone,
      child: Container(
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
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(26),
      shadowColor: tone,
      child: SizedBox(
        width: 250,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: tone.withValues(alpha: 0.14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: tone.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LabelChip(
                label: label,
                tone: tone.withValues(alpha: 0.1),
                textColor: tone,
              ),
              const SizedBox(height: 16),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final Color tone = value >= 85
        ? const Color(0xFF0F766E)
        : value >= 75
        ? const Color(0xFF155EEF)
        : value >= 60
        ? const Color(0xFFEA580C)
        : const Color(0xFFB91C1C);

    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: tone,
      child: SizedBox(
        width: 250,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tone.withValues(alpha: 0.14)),
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
                  _LabelChip(
                    label: '${value.toStringAsFixed(1)}%',
                    tone: tone.withValues(alpha: 0.1),
                    textColor: tone,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(tone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentTrendChart extends StatelessWidget {
  const _StudentTrendChart({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'Sep',
      'Oct',
      'Nov',
      'Dec',
      'Jan',
      'Feb',
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: const Color(0xFFE5ECF6), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(labels[index]);
              },
            ),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: List<FlSpot>.generate(
              student.monthlyPerformance.length,
              (int index) =>
                  FlSpot(index.toDouble(), student.monthlyPerformance[index]),
            ),
            isCurved: true,
            barWidth: 5,
            color: const Color(0xFF155EEF),
            dotData: const FlDotData(show: true),
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
          ),
        ],
      ),
    );
  }
}

class _JumpTile extends StatelessWidget {
  const _JumpTile({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: const Color(0xFFEA580C),
      child: InkWell(
        onTap: onTap,
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
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
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

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({required this.label, required this.value});

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
