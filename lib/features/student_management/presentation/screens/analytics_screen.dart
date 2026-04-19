import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/entities/school_records_entities.dart';
import '../providers/school_records_providers.dart';
import '../providers/student_management_providers.dart';
import '../utils/exam_mark_reporting.dart';
import '../utils/report_exporter.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final SessionUser? session = adminState.session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to view analytics'),
          ),
        ),
      );
    }

    final bool hasAnalyticsData =
        overview.studentResults.isNotEmpty &&
        overview.subjectPerformance.isNotEmpty &&
        overview.classPerformance.isNotEmpty;
    if (!hasAnalyticsData) {
      return WorkspaceShell(
        currentSection: WorkspaceSection.analytics,
        session: session,
        title: 'Analytics',
        subtitle:
            'Analytics will appear after registered students have uploaded result records.',
        actions: <Widget>[
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download Subject Report'),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: const <Widget>[_AnalyticsEmptyState()],
        ),
      );
    }

    final SubjectPerformanceSummary topSubject =
        overview.subjectPerformance.first;
    final SubjectPerformanceSummary weakestSubject =
        overview.subjectPerformance.last;
    final ClassPerformanceSummary strongestClass =
        overview.classPerformance.first;
    final List<StudentPrediction> predictions = ref.watch(
      studentPredictionsProvider,
    );
    final List<TeacherProjection> teacherProjections = ref.watch(
      teacherProjectionsProvider,
    );
    final List<RecommendationInsight> recommendations = ref.watch(
      recommendationInsightsProvider,
    );

    return WorkspaceShell(
      currentSection: WorkspaceSection.analytics,
      session: session,
      title: 'Analytics',
      subtitle:
          'A redesigned intelligence surface for subject quality, class strength, and trend direction across the school.',
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => _showSubjectExportOptions(
            context,
            overview.subjectPerformance,
            adminState.schoolName,
            adminState.studentResults,
          ),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download Subject Report'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          RevealMotion(
            child: _AnalyticsHero(
              overview: overview,
              topSubject: topSubject,
              strongestClass: strongestClass,
            ),
          ),
          const SizedBox(height: 18),
          RevealMotion(
            delay: const Duration(milliseconds: 70),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                _SignalCard(
                  label: 'Top Subject',
                  value: topSubject.subject,
                  detail:
                      '${topSubject.averageScore.toStringAsFixed(1)}% average',
                  tone: const Color(0xFF155EEF),
                ),
                _SignalCard(
                  label: 'Weakest Subject',
                  value: weakestSubject.subject,
                  detail:
                      '${weakestSubject.averageScore.toStringAsFixed(1)}% average',
                  tone: const Color(0xFFB91C1C),
                ),
                _SignalCard(
                  label: 'Strongest Class',
                  value: strongestClass.className,
                  detail:
                      '${strongestClass.averageScore.toStringAsFixed(1)}% average',
                  tone: const Color(0xFF0F766E),
                ),
                _SignalCard(
                  label: 'Inter Exam',
                  value:
                      '${overview.averageInterExamScore.toStringAsFixed(1)}%',
                  detail: 'School-wide live benchmark',
                  tone: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          RevealMotion(
            delay: const Duration(milliseconds: 120),
            child: _AnalyticsBoard(
              tone: const Color(0xFF155EEF),
              title: 'Subject Comparison',
              subtitle:
                  'Average score and inter exam score are now framed together in a denser, cleaner comparison board.',
              header: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const <Widget>[
                  _LegendTag(label: 'Average Score', color: Color(0xFF155EEF)),
                  _LegendTag(label: 'Inter Exam', color: Color(0xFF0F766E)),
                ],
              ),
              child: SizedBox(
                height: 320,
                child: _SubjectBarChart(subjects: overview.subjectPerformance),
              ),
            ),
          ),
          const SizedBox(height: 18),
          RevealMotion(
            delay: const Duration(milliseconds: 170),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 1180;
                final Widget leftColumn = Column(
                  children: <Widget>[
                    _AnalyticsBoard(
                      tone: const Color(0xFF0F766E),
                      title: 'Subject Intelligence',
                      subtitle:
                          'Each subject card now reads like an analysis module with performance, pass rate, and leader context.',
                      child: Column(
                        children: overview.subjectPerformance.map((
                          SubjectPerformanceSummary subject,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SubjectTile(subject: subject),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AnalyticsBoard(
                      tone: const Color(0xFFEA580C),
                      title: 'Trend Focus',
                      subtitle:
                          'Spot the strongest subject trend and the area needing attention through compact line views instead of plain text.',
                      child: Column(
                        children: <Widget>[
                          _TrendFocusTile(
                            title: 'Best current subject',
                            subject: topSubject,
                            tone: const Color(0xFF155EEF),
                          ),
                          const SizedBox(height: 12),
                          _TrendFocusTile(
                            title: 'Needs attention',
                            subject: weakestSubject,
                            tone: const Color(0xFFB91C1C),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final Widget rightColumn = Column(
                  children: <Widget>[
                    _AnalyticsBoard(
                      tone: const Color(0xFF7C3AED),
                      title: 'Class Intelligence',
                      subtitle:
                          'Classes now read as ranked operating groups with student volume, pass rate, and top-student signals.',
                      header: FilledButton.tonalIcon(
                        onPressed: () => _showClassExportOptions(
                          context,
                          overview.classPerformance,
                          adminState.schoolName,
                          adminState.studentResults,
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Excel / PDF'),
                      ),
                      child: Column(
                        children: overview.classPerformance.map((
                          ClassPerformanceSummary schoolClass,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ClassTile(schoolClass: schoolClass),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AnalyticsBoard(
                      tone: const Color(0xFF155EEF),
                      title: 'Class Trend Board',
                      subtitle:
                          'A visual comparison of class progression so leadership can judge movement, not just current averages.',
                      child: SizedBox(
                        height: 320,
                        child: _ClassTrendChart(
                          classes: overview.classPerformance,
                        ),
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
                    Expanded(flex: 5, child: leftColumn),
                    const SizedBox(width: 18),
                    Expanded(flex: 5, child: rightColumn),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          RevealMotion(
            delay: const Duration(milliseconds: 220),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 1180;
                final Widget leftColumn = _AnalyticsBoard(
                  tone: const Color(0xFF155EEF),
                  title: 'Student Forecast Board',
                  subtitle:
                      'Forecast each learner against the archived exam history so intervention can happen before the next formal session.',
                  child: Column(
                    children: predictions.take(4).map((StudentPrediction item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StudentPredictionTile(prediction: item),
                      );
                    }).toList(),
                  ),
                );
                final Widget rightColumn = Column(
                  children: <Widget>[
                    _AnalyticsBoard(
                      tone: const Color(0xFF0F766E),
                      title: 'Teacher Next Move',
                      subtitle:
                          'Use current class performance and historical subject movement to guide each teacher toward the next best action.',
                      child: Column(
                        children: teacherProjections.take(4).map((
                          TeacherProjection item,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TeacherProjectionTile(projection: item),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AnalyticsBoard(
                      tone: const Color(0xFFEA580C),
                      title: 'Recommendation Board',
                      subtitle:
                          'The archive now feeds school, teacher, and learner actions instead of only showing descriptive charts.',
                      child: Column(
                        children: recommendations.map((
                          RecommendationInsight item,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecommendationTile(item: item),
                          );
                        }).toList(),
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
                    Expanded(flex: 5, child: leftColumn),
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

  Future<void> _showSubjectExportOptions(
    BuildContext context,
    List<SubjectPerformanceSummary> subjects,
    String schoolName,
    List<StudentResultRecord> studentResults,
  ) async {
    await _showFormatSheet(
      context: context,
      title: 'Export Subject Report',
      description:
          'Download performance by subject with average score, inter exam, pass rate, and top student.',
      onFormatSelected: (ReportFileFormat format) {
        _exportSubjectReport(
          context,
          subjects,
          schoolName,
          studentResults,
          format,
        );
      },
    );
  }

  Future<void> _exportSubjectReport(
    BuildContext context,
    List<SubjectPerformanceSummary> subjects,
    String schoolName,
    List<StudentResultRecord> studentResults,
    ReportFileFormat format,
  ) async {
    final ReportExportData report = ReportExportData(
      title: 'Subject Performance Report',
      subtitle:
          'Performance by subject across the school, including inter exam and pass-rate signals.',
      schoolName: schoolName,
      reportType: 'Subject analytics report',
      examWindowLabel: examDateRangeLabel(studentResults),
      generatedAt: DateTime.now(),
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Subject Summary',
          note: 'Available from analytics boards as Excel or PDF.',
          headers: const <String>[
            'Subject',
            'Average Score',
            'Inter Exam Average',
            'Pass Rate',
            'Top Student',
          ],
          rows: subjects.map((SubjectPerformanceSummary subject) {
            return <Object?>[
              subject.subject,
              subject.averageScore.toStringAsFixed(1),
              subject.interExamAverage.toStringAsFixed(1),
              subject.passRate.toStringAsFixed(1),
              subject.topStudent,
            ];
          }).toList(),
        ),
      ],
    );

    final String? path = await ReportExporter.exportReport(
      suggestedBaseName: 'subject_performance_report',
      report: report,
      format: format,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Export cancelled.' : 'Subject report saved to $path',
        ),
      ),
    );
  }

  Future<void> _showClassExportOptions(
    BuildContext context,
    List<ClassPerformanceSummary> classes,
    String schoolName,
    List<StudentResultRecord> studentResults,
  ) async {
    await _showFormatSheet(
      context: context,
      title: 'Export Class Report',
      description:
          'Download ranked class performance with volume, averages, pass rate, and top student.',
      onFormatSelected: (ReportFileFormat format) {
        _exportClassReport(
          context,
          classes,
          schoolName,
          studentResults,
          format,
        );
      },
    );
  }

  Future<void> _exportClassReport(
    BuildContext context,
    List<ClassPerformanceSummary> classes,
    String schoolName,
    List<StudentResultRecord> studentResults,
    ReportFileFormat format,
  ) async {
    final ReportExportData report = ReportExportData(
      title: 'Class Performance Report',
      subtitle:
          'Class-by-class ranking with averages, inter exam movement, and top performer context.',
      schoolName: schoolName,
      reportType: 'Class analytics report',
      examWindowLabel: examDateRangeLabel(studentResults),
      generatedAt: DateTime.now(),
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Class Summary',
          note: 'Available from analytics boards as Excel or PDF.',
          headers: const <String>[
            'Class',
            'Students',
            'Average Score',
            'Inter Exam Average',
            'Pass Rate',
            'Top Student',
          ],
          rows: classes.map((ClassPerformanceSummary schoolClass) {
            return <Object?>[
              schoolClass.className,
              schoolClass.totalStudents,
              schoolClass.averageScore.toStringAsFixed(1),
              schoolClass.interExamAverage.toStringAsFixed(1),
              schoolClass.passRate.toStringAsFixed(1),
              schoolClass.topStudent,
            ];
          }).toList(),
        ),
      ],
    );

    final String? path = await ReportExporter.exportReport(
      suggestedBaseName: 'class_performance_report',
      report: report,
      format: format,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Export cancelled.' : 'Class report saved to $path',
        ),
      ),
    );
  }

  Future<void> _showFormatSheet({
    required BuildContext context,
    required String title,
    required String description,
    required ValueChanged<ReportFileFormat> onFormatSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onFormatSelected(ReportFileFormat.excel);
                      },
                      icon: const Icon(Icons.table_chart_rounded),
                      label: const Text('Excel'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onFormatSelected(ReportFileFormat.pdf);
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('PDF'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.analytics_outlined, size: 44, color: Colors.grey.shade500),
          const SizedBox(height: 14),
          Text(
            'No analytics data yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Register students and upload marks first. This page will then calculate subject quality, class strength, trends, and recommendations from real school data.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsHero extends StatelessWidget {
  const _AnalyticsHero({
    required this.overview,
    required this.topSubject,
    required this.strongestClass,
  });

  final SchoolOverview overview;
  final SubjectPerformanceSummary topSubject;
  final ClassPerformanceSummary strongestClass;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF081423),
            Color(0xFF17335A),
            Color(0xFF0F766E),
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
              const _LegendBadge(
                label: 'Performance intelligence',
                tone: Colors.white24,
                textColor: Colors.white,
              ),
              const SizedBox(height: 18),
              Text(
                'Analytics now looks like a real reporting intelligence layer.',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Follow subject strength, class movement, and inter-exam pressure through a clearer visual system.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _LegendBadge(
                    label: '${topSubject.subject} leads subjects',
                    tone: Colors.white24,
                    textColor: Colors.white,
                  ),
                  _LegendBadge(
                    label: '${strongestClass.className} leads classes',
                    tone: Colors.white24,
                    textColor: Colors.white,
                  ),
                  _LegendBadge(
                    label: '${overview.passRate.toStringAsFixed(1)}% pass rate',
                    tone: Colors.white24,
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
                  'Current signals',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                _HeroSignal(
                  label: 'Average score',
                  value: '${overview.averageScore.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 10),
                _HeroSignal(
                  label: 'Inter exam',
                  value:
                      '${overview.averageInterExamScore.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 10),
                _HeroSignal(
                  label: 'Subjects tracked',
                  value: '${overview.subjectPerformance.length}',
                ),
                const SizedBox(height: 10),
                _HeroSignal(
                  label: 'Classes tracked',
                  value: '${overview.classPerformance.length}',
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
}

class _AnalyticsBoard extends StatelessWidget {
  const _AnalyticsBoard({
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

class _SignalCard extends StatelessWidget {
  const _SignalCard({
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
              _LegendBadge(
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

class _SubjectBarChart extends StatelessWidget {
  const _SubjectBarChart({required this.subjects});

  final List<SubjectPerformanceSummary> subjects;

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
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
                if (index < 0 || index >= subjects.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(subjects[index].subject.substring(0, 3)),
                );
              },
            ),
          ),
        ),
        barGroups: subjects.asMap().entries.map((
          MapEntry<int, SubjectPerformanceSummary> entry,
        ) {
          return BarChartGroupData(
            x: entry.key,
            barsSpace: 6,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: entry.value.averageScore,
                width: 14,
                color: const Color(0xFF155EEF),
                borderRadius: BorderRadius.circular(6),
              ),
              BarChartRodData(
                toY: entry.value.interExamAverage,
                width: 14,
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ClassTrendChart extends StatelessWidget {
  const _ClassTrendChart({required this.classes});

  final List<ClassPerformanceSummary> classes;

  @override
  Widget build(BuildContext context) {
    final List<Color> palette = <Color>[
      const Color(0xFF155EEF),
      const Color(0xFF0F766E),
      const Color(0xFF7C3AED),
      const Color(0xFFEA580C),
      const Color(0xFFB91C1C),
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
                const List<String> labels = <String>[
                  'T1',
                  'Inter',
                  'T2',
                  'Now',
                ];
                final int index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(labels[index]);
              },
            ),
          ),
        ),
        lineBarsData: classes.asMap().entries.map((
          MapEntry<int, ClassPerformanceSummary> entry,
        ) {
          final Color color = palette[entry.key % palette.length];
          return LineChartBarData(
            isCurved: true,
            barWidth: 3,
            color: color,
            dotData: const FlDotData(show: false),
            spots: entry.value.trend.asMap().entries.map((
              MapEntry<int, ScorePoint> trendEntry,
            ) {
              return FlSpot(trendEntry.key.toDouble(), trendEntry.value.value);
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject});

  final SubjectPerformanceSummary subject;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    subject.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _LegendBadge(
                  label: '${subject.averageScore.toStringAsFixed(1)}%',
                  tone: const Color(0xFFEAF1FF),
                  textColor: const Color(0xFF155EEF),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _DataTag(
                  label:
                      'Inter ${subject.interExamAverage.toStringAsFixed(1)}%',
                ),
                _DataTag(label: 'Pass ${subject.passRate.toStringAsFixed(1)}%'),
                _DataTag(label: 'Top ${subject.topStudent}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.schoolClass});

  final ClassPerformanceSummary schoolClass;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: const Color(0xFF7C3AED),
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
                Expanded(
                  child: Text(
                    schoolClass.className,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _LegendBadge(
                  label: '${schoolClass.averageScore.toStringAsFixed(1)}%',
                  tone: const Color(0xFFF4EBFF),
                  textColor: const Color(0xFF7C3AED),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _DataTag(label: '${schoolClass.totalStudents} students'),
                _DataTag(
                  label: 'Pass ${schoolClass.passRate.toStringAsFixed(1)}%',
                ),
                _DataTag(label: 'Top ${schoolClass.topStudent}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendFocusTile extends StatelessWidget {
  const _TrendFocusTile({
    required this.title,
    required this.subject,
    required this.tone,
  });

  final String title;
  final SubjectPerformanceSummary subject;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: tone,
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _LegendBadge(
                  label: subject.subject,
                  tone: tone.withValues(alpha: 0.1),
                  textColor: tone,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 140,
              child: _SingleTrendChart(points: subject.trend, color: tone),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleTrendChart extends StatelessWidget {
  const _SingleTrendChart({required this.points, required this.color});

  final List<ScorePoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Text(points[index].label);
              },
            ),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            isCurved: true,
            barWidth: 4,
            color: color,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
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

class _LegendTag extends StatelessWidget {
  const _LegendTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _LegendBadge extends StatelessWidget {
  const _LegendBadge({
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

class _DataTag extends StatelessWidget {
  const _DataTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(label),
    );
  }
}

class _HeroSignal extends StatelessWidget {
  const _HeroSignal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _StudentPredictionTile extends StatelessWidget {
  const _StudentPredictionTile({required this.prediction});

  final StudentPrediction prediction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  prediction.studentName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _LegendBadge(
                label: prediction.predictedDivision,
                tone: const Color(0xFFEAF1FF),
                textColor: const Color(0xFF155EEF),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${prediction.className} • ${prediction.confidenceLabel}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _DataTag(
                label:
                    'Current ${prediction.currentAverage.toStringAsFixed(1)}%',
              ),
              _DataTag(
                label:
                    'Forecast ${prediction.predictedAverage.toStringAsFixed(1)}%',
              ),
              _DataTag(label: prediction.focusSubjects.join(' • ')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeacherProjectionTile extends StatelessWidget {
  const _TeacherProjectionTile({required this.projection});

  final TeacherProjection projection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            projection.teacherName,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${projection.subject} • ${projection.assignedClass}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _DataTag(
                label:
                    'Current ${projection.currentAverage.toStringAsFixed(1)}%',
              ),
              _DataTag(
                label:
                    'Projected ${projection.projectedAverage.toStringAsFixed(1)}%',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            projection.recommendation,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.item});

  final RecommendationInsight item;

  @override
  Widget build(BuildContext context) {
    final Color tone = switch (item.priority) {
      RecommendationPriority.high => const Color(0xFFB91C1C),
      RecommendationPriority.medium => const Color(0xFFEA580C),
      RecommendationPriority.monitor => const Color(0xFF155EEF),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _LegendBadge(
                label: item.priority.label,
                tone: tone.withValues(alpha: 0.14),
                textColor: tone,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${item.target.label} • ${item.targetName}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Text(
            item.detail,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          _DataTag(label: '${item.metricLabel}: ${item.metricValue}'),
        ],
      ),
    );
  }
}
