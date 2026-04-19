import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../utils/exam_mark_reporting.dart';
import '../utils/report_exporter.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

Color _gradeTone(String grade) {
  switch (grade) {
    case 'A':
      return const Color(0xFF0F766E);
    case 'B':
      return const Color(0xFF155EEF);
    case 'C':
      return const Color(0xFF7C3AED);
    case 'D':
      return const Color(0xFFEA580C);
    default:
      return const Color(0xFFB91C1C);
  }
}

class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({
    super.key,
    required this.studentId,
    this.sourceClass,
  });

  final String studentId;
  final String? sourceClass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionUser? session = ref.watch(schoolAdminProvider).session;
    final StudentResultRecord? record = ref.watch(
      studentResultProvider(studentId),
    );

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to continue'),
          ),
        ),
      );
    }

    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Result record not found.')),
      );
    }

    // Only include subjects that have marks entered
    final List<SubjectResult> subjectsWithMarks = record.subjectResults
        .where((SubjectResult result) => result.examMarks.isNotEmpty)
        .toList();

    final List<SubjectResult> strongSubjects = subjectsWithMarks
        .where((SubjectResult result) => result.averageScore >= 65)
        .toList();
    final List<SubjectResult> weakSubjects = subjectsWithMarks
        .where((SubjectResult result) => result.averageScore < 50)
        .toList();
    final List<Map<String, String>> assessmentTimeline = subjectsWithMarks
        .expand((SubjectResult subject) {
          return subject.examMarks.map((ExamMark mark) {
            return <String, String>{
              'subject': subject.subject,
              'type': mark.type.label,
              'label': mark.label,
              'examDate': formatShortDate(mark.examDate),
              'uploadedAt': formatDateTimeStamp(mark.uploadedAt),
              'teacher': mark.teacherName ?? 'System',
            };
          });
        })
        .toList();

    return WorkspaceShell(
      currentSection: WorkspaceSection.results,
      session: session,
      title: '${record.studentName} Result Analysis',
      subtitle:
          'A redesigned learner report with stronger hierarchy for subject scores, division logic, and trend review.',
      breadcrumbs: <Map<String, String>>[
        const <String, String>{'label': 'Dashboard', 'route': '/dashboard'},
        <String, String>{
          'label': 'Results',
          'route': sourceClass == null
              ? '/results'
              : '/results?class=${Uri.encodeComponent(sourceClass!)}',
        },
        if (sourceClass != null) <String, String>{'label': sourceClass!},
        const <String, String>{'label': 'Student Result'},
      ],
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () =>
              _showStudentExportOptions(context, record, session.schoolName),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download Excel / PDF'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          _ResultHero(record: record),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              _MetricCard(
                label: 'Average',
                value: '${record.averageScore.toStringAsFixed(1)}%',
                detail: 'Overall subject average',
                tone: const Color(0xFF155EEF),
              ),
              _MetricCard(
                label: 'Inter Exam',
                value: '${record.interExamAverage.toStringAsFixed(1)}%',
                detail: 'Mid-cycle benchmark',
                tone: const Color(0xFF0F766E),
              ),
              _MetricCard(
                label: 'Division',
                value: record.division,
                detail: '${record.divisionPoints} aggregate points',
                tone: const Color(0xFF7C3AED),
              ),
              _MetricCard(
                label: 'Attendance',
                value: '${record.attendanceRate.toStringAsFixed(1)}%',
                detail: 'Participation signal',
                tone: const Color(0xFFEA580C),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 1180;
              final Widget leftColumn = Column(
                children: <Widget>[
                  _ResultBoard(
                    tone: const Color(0xFF155EEF),
                    title: 'Performance Trend',
                    subtitle:
                        'This learner trend is now framed like a report insight rather than a plain line chart block.',
                    child: SizedBox(
                      height: 280,
                      child: _TrendChart(points: record.performanceTrend),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ResultBoard(
                    tone: const Color(0xFF0F766E),
                    title: 'Subject Performance Table',
                    subtitle:
                        'Subject marks organized by exam type with averages and grades for clear performance analysis.',
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowColor: WidgetStatePropertyAll(
                          const Color(0xFFE8F7EE).withValues(alpha: 0.5),
                        ),
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Subject')),
                          DataColumn(label: Text('Mid-Term')),
                          DataColumn(label: Text('Annual')),
                          DataColumn(label: Text('Class Exam')),
                          DataColumn(label: Text('Teacher Named')),
                          DataColumn(label: Text('Average')),
                          DataColumn(label: Text('Grade')),
                        ],
                        rows: subjectsWithMarks.map((SubjectResult result) {
                          final double? midTermAvg = getAverageScoreForExamType(
                            result,
                            ExamType.midTerm,
                          );
                          final double? annualAvg = getAverageScoreForExamType(
                            result,
                            ExamType.annual,
                          );
                          final double? classExamAvg =
                              getAverageScoreForExamType(
                                result,
                                ExamType.classExam,
                              );
                          final double? teacherNamedAvg =
                              getAverageScoreForExamType(
                                result,
                                ExamType.teacherNamed,
                              );

                          return DataRow(
                            cells: <DataCell>[
                              DataCell(Text(result.subject)),
                              DataCell(
                                Text(midTermAvg?.toStringAsFixed(1) ?? '-'),
                              ),
                              DataCell(
                                Text(annualAvg?.toStringAsFixed(1) ?? '-'),
                              ),
                              DataCell(
                                Text(classExamAvg?.toStringAsFixed(1) ?? '-'),
                              ),
                              DataCell(
                                Text(
                                  teacherNamedAvg?.toStringAsFixed(1) ?? '-',
                                ),
                              ),
                              DataCell(
                                Text(result.averageScore.toStringAsFixed(1)),
                              ),
                              DataCell(
                                _InlineBadge(
                                  label: result.grade,
                                  tone: _gradeTone(result.grade),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );

              final Widget rightColumn = Column(
                children: <Widget>[
                  _ResultBoard(
                    tone: const Color(0xFF7C3AED),
                    title: 'Report Snapshot',
                    subtitle:
                        'High-level report state for quick reading before opening the full table.',
                    child: Column(
                      children: <Widget>[
                        _StatRow(
                          label: 'Admission',
                          value: record.admissionNumber,
                        ),
                        const SizedBox(height: 10),
                        _StatRow(label: 'Class', value: record.className),
                        const SizedBox(height: 10),
                        _StatRow(
                          label: 'Exams recorded',
                          value: '${record.examsConducted}',
                        ),
                        const SizedBox(height: 10),
                        _StatRow(label: 'Division', value: record.division),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ResultBoard(
                    tone: const Color(0xFFEA580C),
                    title: 'Performance Signals',
                    subtitle:
                        'Strong and weak subjects are separated visually so action can be planned quickly.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Strong subjects',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: strongSubjects.isEmpty
                              ? const <Widget>[
                                  Text('None above the current threshold.'),
                                ]
                              : strongSubjects.map((SubjectResult subject) {
                                  return _LabelChip(
                                    label:
                                        '${subject.subject} ${subject.grade}',
                                    tone: const Color(0xFFE8F7EE),
                                    textColor: const Color(0xFF0F766E),
                                  );
                                }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Needs support',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: weakSubjects.isEmpty
                              ? const <Widget>[
                                  Text(
                                    'No subject is below the current threshold.',
                                  ),
                                ]
                              : weakSubjects.map((SubjectResult subject) {
                                  return _LabelChip(
                                    label:
                                        '${subject.subject} ${subject.grade}',
                                    tone: const Color(0xFFFFE8E8),
                                    textColor: const Color(0xFFB91C1C),
                                  );
                                }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ResultBoard(
                    tone: const Color(0xFF155EEF),
                    title: 'Subject Result Table',
                    subtitle:
                        'The full table stays available, but now sits inside the same visual system as the rest of the page.',
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        headingRowColor: WidgetStatePropertyAll(
                          const Color(0xFFF3F7FF),
                        ),
                        columns: const <DataColumn>[
                          DataColumn(label: Text('Subject')),
                          DataColumn(label: Text('Mid-Term')),
                          DataColumn(label: Text('Annual')),
                          DataColumn(label: Text('Class Exam')),
                          DataColumn(label: Text('Teacher Named')),
                          DataColumn(label: Text('Average')),
                          DataColumn(label: Text('Grade')),
                        ],
                        rows: subjectsWithMarks.map((SubjectResult result) {
                          final double? midTermAvg = getAverageScoreForExamType(
                            result,
                            ExamType.midTerm,
                          );
                          final double? annualAvg = getAverageScoreForExamType(
                            result,
                            ExamType.annual,
                          );
                          final double? classExamAvg =
                              getAverageScoreForExamType(
                                result,
                                ExamType.classExam,
                              );
                          final double? teacherNamedAvg =
                              getAverageScoreForExamType(
                                result,
                                ExamType.teacherNamed,
                              );

                          return DataRow(
                            cells: <DataCell>[
                              DataCell(Text(result.subject)),
                              DataCell(
                                Text(midTermAvg?.toStringAsFixed(1) ?? '-'),
                              ),
                              DataCell(
                                Text(annualAvg?.toStringAsFixed(1) ?? '-'),
                              ),
                              DataCell(
                                Text(classExamAvg?.toStringAsFixed(1) ?? '-'),
                              ),
                              DataCell(
                                Text(
                                  teacherNamedAvg?.toStringAsFixed(1) ?? '-',
                                ),
                              ),
                              DataCell(
                                Text(result.averageScore.toStringAsFixed(1)),
                              ),
                              DataCell(Text(result.grade)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ResultBoard(
                    tone: const Color(0xFF0F766E),
                    title: 'Assessment Calendar',
                    subtitle:
                        'This makes it clear when each exam happened and when the result was uploaded.',
                    child: assessmentTimeline.isEmpty
                        ? const Text('No dated assessments recorded yet.')
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 16,
                              columns: const <DataColumn>[
                                DataColumn(label: Text('Subject')),
                                DataColumn(label: Text('Exam Type')),
                                DataColumn(label: Text('Exam Label')),
                                DataColumn(label: Text('Exam Date')),
                                DataColumn(label: Text('Uploaded On')),
                                DataColumn(label: Text('Teacher')),
                              ],
                              rows: assessmentTimeline.map((
                                Map<String, String> item,
                              ) {
                                return DataRow(
                                  cells: <DataCell>[
                                    DataCell(Text(item['subject']!)),
                                    DataCell(Text(item['type']!)),
                                    DataCell(Text(item['label']!)),
                                    DataCell(Text(item['examDate']!)),
                                    DataCell(Text(item['uploadedAt']!)),
                                    DataCell(Text(item['teacher']!)),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                ],
              );

              final Map<String, int> gradeDistribution = <String, int>{};
              for (final SubjectResult result in subjectsWithMarks) {
                gradeDistribution[result.grade] =
                    (gradeDistribution[result.grade] ?? 0) + 1;
              }

              final int excellentCount = subjectsWithMarks
                  .where((SubjectResult r) => r.averageScore >= 80)
                  .length;
              final int goodCount = subjectsWithMarks
                  .where(
                    (SubjectResult r) =>
                        r.averageScore >= 65 && r.averageScore < 80,
                  )
                  .length;
              final int averageCount = subjectsWithMarks
                  .where(
                    (SubjectResult r) =>
                        r.averageScore >= 50 && r.averageScore < 65,
                  )
                  .length;
              final int needsWorkCount = subjectsWithMarks
                  .where((SubjectResult r) => r.averageScore < 50)
                  .length;
              final int totalSubjects = subjectsWithMarks.length;

              final Widget analysisSection = Column(
                children: <Widget>[
                  _ResultBoard(
                    tone: const Color(0xFF7C3AED),
                    title: 'Performance Analysis',
                    subtitle:
                        'Comprehensive breakdown of subject performance distribution and grade composition.',
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool canFitTwoCharts = constraints.maxWidth > 700;
                        final List<Widget> charts = <Widget>[
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Grade Distribution',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 160,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 35,
                                      sections: <PieChartSectionData>[
                                        if (gradeDistribution.containsKey('A'))
                                          PieChartSectionData(
                                            value: gradeDistribution['A']!
                                                .toDouble(),
                                            title:
                                                '${((gradeDistribution['A']! / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFF0F766E),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        if (gradeDistribution.containsKey('B'))
                                          PieChartSectionData(
                                            value: gradeDistribution['B']!
                                                .toDouble(),
                                            title:
                                                '${((gradeDistribution['B']! / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFF155EEF),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        if (gradeDistribution.containsKey('C'))
                                          PieChartSectionData(
                                            value: gradeDistribution['C']!
                                                .toDouble(),
                                            title:
                                                '${((gradeDistribution['C']! / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFF7C3AED),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        if (gradeDistribution.containsKey('D'))
                                          PieChartSectionData(
                                            value: gradeDistribution['D']!
                                                .toDouble(),
                                            title:
                                                '${((gradeDistribution['D']! / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFFEA580C),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        if (gradeDistribution.containsKey('E'))
                                          PieChartSectionData(
                                            value: gradeDistribution['E']!
                                                .toDouble(),
                                            title:
                                                '${((gradeDistribution['E']! / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFFB91C1C),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: <Widget>[
                                    if (gradeDistribution.containsKey('A'))
                                      _LegendDot(
                                        label: 'A',
                                        color: const Color(0xFF0F766E),
                                      ),
                                    if (gradeDistribution.containsKey('B'))
                                      _LegendDot(
                                        label: 'B',
                                        color: const Color(0xFF155EEF),
                                      ),
                                    if (gradeDistribution.containsKey('C'))
                                      _LegendDot(
                                        label: 'C',
                                        color: const Color(0xFF7C3AED),
                                      ),
                                    if (gradeDistribution.containsKey('D'))
                                      _LegendDot(
                                        label: 'D',
                                        color: const Color(0xFFEA580C),
                                      ),
                                    if (gradeDistribution.containsKey('E'))
                                      _LegendDot(
                                        label: 'E',
                                        color: const Color(0xFFB91C1C),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Performance Levels',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 160,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 35,
                                      sections: <PieChartSectionData>[
                                        if (excellentCount > 0)
                                          PieChartSectionData(
                                            value: excellentCount.toDouble(),
                                            title:
                                                '${((excellentCount / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFF0F766E),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        if (goodCount > 0)
                                          PieChartSectionData(
                                            value: goodCount.toDouble(),
                                            title:
                                                '${((goodCount / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFF155EEF),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        if (averageCount > 0)
                                          PieChartSectionData(
                                            value: averageCount.toDouble(),
                                            title:
                                                '${((averageCount / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFF7C3AED),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        if (needsWorkCount > 0)
                                          PieChartSectionData(
                                            value: needsWorkCount.toDouble(),
                                            title:
                                                '${((needsWorkCount / totalSubjects) * 100).toStringAsFixed(0)}%',
                                            color: const Color(0xFFB91C1C),
                                            radius: 50,
                                            titleStyle: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: <Widget>[
                                    _LegendDot(
                                      label: 'Excellent (80%+)',
                                      color: const Color(0xFF0F766E),
                                    ),
                                    _LegendDot(
                                      label: 'Good (65-79%)',
                                      color: const Color(0xFF155EEF),
                                    ),
                                    _LegendDot(
                                      label: 'Average (50-64%)',
                                      color: const Color(0xFF7C3AED),
                                    ),
                                    _LegendDot(
                                      label: 'Needs Work (<50%)',
                                      color: const Color(0xFFB91C1C),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ];

                        return canFitTwoCharts
                            ? Row(children: charts)
                            : Column(children: charts);
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ResultBoard(
                    tone: const Color(0xFF155EEF),
                    title: 'Quick Stats',
                    subtitle: 'Performance metrics at a glance.',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        _StatCard(
                          value: excellentCount,
                          label: 'Excellent',
                          percentage: ((excellentCount / totalSubjects) * 100)
                              .toStringAsFixed(1),
                          color: const Color(0xFF0F766E),
                        ),
                        _StatCard(
                          value: goodCount,
                          label: 'Good',
                          percentage: ((goodCount / totalSubjects) * 100)
                              .toStringAsFixed(1),
                          color: const Color(0xFF155EEF),
                        ),
                        _StatCard(
                          value: averageCount,
                          label: 'Average',
                          percentage: ((averageCount / totalSubjects) * 100)
                              .toStringAsFixed(1),
                          color: const Color(0xFF7C3AED),
                        ),
                        _StatCard(
                          value: needsWorkCount,
                          label: 'Needs Work',
                          percentage: ((needsWorkCount / totalSubjects) * 100)
                              .toStringAsFixed(1),
                          color: const Color(0xFFB91C1C),
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
                    const SizedBox(height: 18),
                    analysisSection,
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 6, child: leftColumn),
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: rightColumn),
                      ],
                    ),
                    const SizedBox(height: 18),
                    analysisSection,
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showStudentExportOptions(
    BuildContext context,
    StudentResultRecord record,
    String schoolName,
  ) async {
    ExamType? selectedType;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: StatefulBuilder(
              builder:
                  (
                    BuildContext context,
                    void Function(void Function()) setState,
                  ) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Export Student Report',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Download the student report by learner with subject breakdown, labeled exam records, grades, and division.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            ChoiceChip(
                              label: const Text('All'),
                              selected: selectedType == null,
                              onSelected: (_) =>
                                  setState(() => selectedType = null),
                            ),
                            ...ExamType.values.map((ExamType type) {
                              return ChoiceChip(
                                label: Text(type.label),
                                selected: selectedType == type,
                                onSelected: (_) =>
                                    setState(() => selectedType = type),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _exportStudentReport(
                                  context,
                                  record,
                                  schoolName,
                                  ReportFileFormat.excel,
                                  selectedType,
                                );
                              },
                              icon: const Icon(Icons.table_chart_rounded),
                              label: const Text('Excel'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(sheetContext).pop();
                                _exportStudentReport(
                                  context,
                                  record,
                                  schoolName,
                                  ReportFileFormat.pdf,
                                  selectedType,
                                );
                              },
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              label: const Text('PDF'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportStudentReport(
    BuildContext context,
    StudentResultRecord record,
    String schoolName,
    ReportFileFormat format,
    ExamType? filterType,
  ) async {
    final List<StudentResultRecord> filteredRecords =
        filterStudentResultsByExamType(<StudentResultRecord>[
          record,
        ], filterType);
    if (filteredRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No ${examFilterLabel(filterType).toLowerCase()} marks have been uploaded for this student.',
          ),
        ),
      );
      return;
    }

    final StudentResultRecord filtered = filteredRecords.first;
    final ReportExportData report = ReportExportData(
      title: '${record.studentName} Student Report',
      subtitle:
          'Learner-level result report with labeled exam records, averages, grades, and division for ${examFilterLabel(filterType).toLowerCase()}.',
      schoolName: schoolName,
      reportType: filterType == null
          ? 'Student result report for all exams'
          : 'Student result report for ${filterType.label}',
      examWindowLabel: examDateRangeLabel(<StudentResultRecord>[filtered]),
      generatedAt: DateTime.now(),
      summary: <ReportSummaryItem>[
        ReportSummaryItem(label: 'Admission', value: filtered.admissionNumber),
        ReportSummaryItem(label: 'Class', value: filtered.className),
        ReportSummaryItem(
          label: 'Average',
          value: '${filtered.averageScore.toStringAsFixed(1)}%',
        ),
        ReportSummaryItem(label: 'Division', value: filtered.division),
        ReportSummaryItem(
          label: 'Exam Filter',
          value: examFilterLabel(filterType),
        ),
      ],
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Subject Breakdown',
          note: 'Available as Excel or PDF from the student result page.',
          headers: const <String>[
            'Subject',
            'Exam Records',
            'Latest Upload',
            'Average',
            'Grade',
            'Points',
          ],
          rows: filtered.subjectResults.map((SubjectResult subject) {
            return <Object?>[
              subject.subject,
              formatExamMarkList(subject.examMarks),
              formatDateTimeStamp(
                subject.examMarks
                    .map((ExamMark item) => item.uploadedAt)
                    .whereType<DateTime>()
                    .fold<DateTime?>(
                      null,
                      (DateTime? latest, DateTime item) =>
                          latest == null || item.isAfter(latest)
                          ? item
                          : latest,
                    ),
              ),
              subject.averageScore.toStringAsFixed(1),
              subject.grade,
              subject.gradePoint,
            ];
          }).toList(),
        ),
      ],
    );

    final String? path = await ReportExporter.exportReport(
      suggestedBaseName:
          '${record.studentName.toLowerCase().replaceAll(' ', '_')}_report',
      report: report,
      format: format,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Export cancelled.' : 'Student report saved to $path',
        ),
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  const _ResultHero({required this.record});

  final StudentResultRecord record;

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
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  record.studentName.substring(0, 1),
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
                      record.studentName,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${record.className} • ${record.admissionNumber} • ${record.division}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                      ),
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
                  'Quick report signals',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 14),
                _HeroInfo(
                  label: 'Average',
                  value: '${record.averageScore.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 10),
                _HeroInfo(
                  label: 'Inter exam',
                  value: '${record.interExamAverage.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 10),
                _HeroInfo(
                  label: 'Attendance',
                  value: '${record.attendanceRate.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 10),
                _HeroInfo(label: 'Points', value: '${record.divisionPoints}'),
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
}

class _ResultBoard extends StatelessWidget {
  const _ResultBoard({
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

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<ScorePoint> points;

  @override
  Widget build(BuildContext context) {
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
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 28),
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

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

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

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tone),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

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
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.percentage,
    required this.color,
  });

  final int value;
  final String label;
  final String percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$percentage%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
