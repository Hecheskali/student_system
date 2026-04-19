import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../utils/exam_mark_reporting.dart';
import '../utils/report_exporter.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

const List<String> _kDefaultResultsClasses = <String>[
  'Form 1 A',
  'Form 1 B',
  'Form 2 A',
  'Form 2 B',
  'Form 3 A',
  'Form 3 B',
  'Form 4 A',
  'Form 4 B',
];

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, this.initialClass});

  final String? initialClass;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  String? _selectedClass;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.initialClass;
  }

  @override
  void didUpdateWidget(covariant ResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialClass != widget.initialClass) {
      _selectedClass = widget.initialClass;
    }
  }

  List<String> get _availableClasses {
    final Set<String> classes = <String>{
      ..._kDefaultResultsClasses,
      ...ref
          .watch(schoolAdminProvider)
          .studentResults
          .map((StudentResultRecord record) => record.className),
    };
    return classes.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final SessionUser? session = adminState.session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to view results'),
          ),
        ),
      );
    }

    final List<StudentResultRecord> filteredResults = _selectedClass == null
        ? const <StudentResultRecord>[]
        : overview.studentResults
              .where(
                (StudentResultRecord record) =>
                    record.className == _selectedClass,
              )
              .toList();
    final List<StudentResultRecord> topResults = filteredResults
        .take(4)
        .toList();
    final List<StudentResultRecord> flagged = filteredResults
        .where(
          (StudentResultRecord record) => record.riskLevel != RiskLevel.stable,
        )
        .take(4)
        .toList();
    final Map<String, int> divisionDistribution = <String, int>{
      'Division I': 0,
      'Division II': 0,
      'Division III': 0,
      'Division IV': 0,
      'Division 0': 0,
    };
    for (final StudentResultRecord record in filteredResults) {
      divisionDistribution[record.division] =
          (divisionDistribution[record.division] ?? 0) + 1;
    }
    final double averageScore = filteredResults.isEmpty
        ? 0
        : filteredResults.fold<double>(
                0,
                (double sum, StudentResultRecord record) =>
                    sum + record.averageScore,
              ) /
              filteredResults.length;
    final double interExam = filteredResults.isEmpty
        ? 0
        : filteredResults.fold<double>(
                0,
                (double sum, StudentResultRecord record) =>
                    sum + record.interExamAverage,
              ) /
              filteredResults.length;
    final double passRate = filteredResults.isEmpty
        ? 0
        : filteredResults
                  .where(
                    (StudentResultRecord record) =>
                        record.division != 'Division 0',
                  )
                  .length /
              filteredResults.length *
              100;

    return WorkspaceShell(
      currentSection: WorkspaceSection.results,
      session: session,
      title: 'Results Center',
      subtitle:
          'Pick the class first, then open a clean result board for that class only.',
      breadcrumbs: <Map<String, String>>[
        const <String, String>{'label': 'Dashboard', 'route': '/dashboard'},
        const <String, String>{'label': 'Results', 'route': '/results'},
        if (_selectedClass != null) <String, String>{'label': _selectedClass!},
      ],
      actions: <Widget>[
        FilledButton.icon(
          onPressed: _selectedClass == null
              ? null
              : () => _showExportOptions(context, overview, _selectedClass!),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Download Reports'),
        ),
      ],
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          _ResultsClassSelector(
            schoolName: overview.schoolName,
            classes: _availableClasses,
            selectedClass: _selectedClass,
            onClassSelected: (String className) {
              setState(() {
                _selectedClass = className;
              });
            },
          ),
          const SizedBox(height: 18),
          if (_selectedClass == null)
            const _ResultsClassGate()
          else ...<Widget>[
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: <Widget>[
                _SignalCard(
                  label: 'Students',
                  value: '${filteredResults.length}',
                  detail: 'Registered in this class',
                  tone: const Color(0xFF0F766E),
                ),
                _SignalCard(
                  label: 'Average',
                  value: '${averageScore.toStringAsFixed(1)}%',
                  detail: 'Class average score',
                  tone: const Color(0xFF155EEF),
                ),
                _SignalCard(
                  label: 'Inter Exam',
                  value: '${interExam.toStringAsFixed(1)}%',
                  detail: 'Class benchmark',
                  tone: const Color(0xFF7C3AED),
                ),
                _SignalCard(
                  label: 'Pass Rate',
                  value: '${passRate.toStringAsFixed(1)}%',
                  detail: 'Division I to IV',
                  tone: const Color(0xFFEA580C),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 1220;
                final Widget leftColumn = Column(
                  children: <Widget>[
                    _ResultsBoard(
                      tone: const Color(0xFF155EEF),
                      title: '$_selectedClass Result Board',
                      subtitle:
                          'Only the selected class is visible here so result review stays focused and less error-prone.',
                      header: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          const _BoardBadge(
                            label: 'Class first',
                            tone: Color(0xFFEAF1FF),
                            textColor: Color(0xFF155EEF),
                          ),
                          const _BoardBadge(
                            label: 'Excel / PDF',
                            tone: Color(0xFFF3F7FF),
                            textColor: Color(0xFF155EEF),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _showExportOptions(
                              context,
                              overview,
                              _selectedClass!,
                            ),
                            icon: const Icon(Icons.download_rounded),
                            label: const Text('Export'),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 22,
                          headingRowColor: const WidgetStatePropertyAll(
                            Color(0xFFF3F7FF),
                          ),
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Student')),
                            DataColumn(label: Text('Admission')),
                            DataColumn(label: Text('Exams')),
                            DataColumn(label: Text('Average')),
                            DataColumn(label: Text('Inter')),
                            DataColumn(label: Text('Division')),
                            DataColumn(label: Text('Grades')),
                            DataColumn(label: Text('Open')),
                          ],
                          rows: filteredResults.map((
                            StudentResultRecord record,
                          ) {
                            final String grades = record.subjectResults
                                .map(
                                  (SubjectResult subject) =>
                                      '${subject.subject.substring(0, 3)}:${subject.grade}',
                                )
                                .join('  ');
                            return DataRow(
                              cells: <DataCell>[
                                DataCell(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(record.studentName),
                                      Text(
                                        record.admissionNumber,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF64748B),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(record.admissionNumber)),
                                DataCell(Text('${record.examsConducted}')),
                                DataCell(
                                  Text(
                                    '${record.averageScore.toStringAsFixed(1)}%',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${record.interExamAverage.toStringAsFixed(1)}%',
                                  ),
                                ),
                                DataCell(
                                  _InlineBadge(
                                    label: record.division,
                                    tone: _divisionTone(record.division),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(width: 290, child: Text(grades)),
                                ),
                                DataCell(
                                  FilledButton.tonal(
                                    onPressed: () => context.go(
                                      '/results/${record.id}?class=${Uri.encodeComponent(record.className)}',
                                    ),
                                    child: const Text('Open'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ResultsBoard(
                      tone: const Color(0xFF0F766E),
                      title: 'Highest Performers',
                      subtitle:
                          'Best learners from the selected class, ready for quick drill-down.',
                      child: Column(
                        children: topResults.map((StudentResultRecord record) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StudentResultTile(record: record),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );

                final Widget rightColumn = Column(
                  children: <Widget>[
                    _ResultsBoard(
                      tone: const Color(0xFF7C3AED),
                      title: 'Division Summary',
                      subtitle: 'Division spread for the selected class only.',
                      child: Column(
                        children: divisionDistribution.entries.map((
                          MapEntry<String, int> entry,
                        ) {
                          final double ratio = filteredResults.isEmpty
                              ? 0
                              : entry.value / filteredResults.length;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DivisionTile(
                              label: entry.key,
                              count: entry.value,
                              ratio: ratio,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ResultsBoard(
                      tone: const Color(0xFFEA580C),
                      title: 'Needs Attention',
                      subtitle: 'Flagged learners in the selected class.',
                      child: flagged.isEmpty
                          ? const Text('No flagged students in this class.')
                          : Column(
                              children: flagged.map((
                                StudentResultRecord record,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _FlaggedTile(record: record),
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
                    Expanded(flex: 7, child: leftColumn),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: rightColumn),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showExportOptions(
    BuildContext context,
    SchoolOverview overview,
    String className,
  ) async {
    ExamType? selectedType;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (BuildContext context, void Function(void Function()) setState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Export Result Reports',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Download school-wide result boards or exam-level sheets as Excel or PDF, filtered by exam type when needed.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
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
                    _ExportOptionCard(
                      title: 'General School Result',
                      description:
                          'Whole-school learner result table with division, attendance, and average score.',
                      onExcel: () {
                        Navigator.of(sheetContext).pop();
                        _exportGeneralResults(
                          context,
                          overview,
                          className,
                          ReportFileFormat.excel,
                          selectedType,
                        );
                      },
                      onPdf: () {
                        Navigator.of(sheetContext).pop();
                        _exportGeneralResults(
                          context,
                          overview,
                          className,
                          ReportFileFormat.pdf,
                          selectedType,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _ExportOptionCard(
                      title: 'Exam Ledger',
                      description:
                          'Labeled exam-by-exam subject report with exam type, exam name, score, grade, and points.',
                      onExcel: () {
                        Navigator.of(sheetContext).pop();
                        _exportExamLedger(
                          context,
                          overview,
                          className,
                          ReportFileFormat.excel,
                          selectedType,
                        );
                      },
                      onPdf: () {
                        Navigator.of(sheetContext).pop();
                        _exportExamLedger(
                          context,
                          overview,
                          className,
                          ReportFileFormat.pdf,
                          selectedType,
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _exportGeneralResults(
    BuildContext context,
    SchoolOverview overview,
    String className,
    ReportFileFormat format,
    ExamType? filterType,
  ) async {
    final List<StudentResultRecord> filteredRecords =
        filterStudentResultsByExamType(
          overview.studentResults.where(
            (StudentResultRecord record) => record.className == className,
          ),
          filterType,
        );
    final double averageScore = filteredRecords.isEmpty
        ? 0
        : filteredRecords
                  .map((StudentResultRecord record) => record.averageScore)
                  .reduce((double a, double b) => a + b) /
              filteredRecords.length;
    final double passRate = filteredRecords.isEmpty
        ? 0
        : filteredRecords
                  .where(
                    (StudentResultRecord record) =>
                        record.division != 'Division 0',
                  )
                  .length /
              filteredRecords.length *
              100;
    final ReportExportData report = ReportExportData(
      title: '${overview.schoolName} General School Result',
      subtitle:
          'Class-based learner performance board for $className with divisions, averages, and attendance for ${examFilterLabel(filterType).toLowerCase()}.',
      schoolName: overview.schoolName,
      reportType: filterType == null
          ? 'All core exams general result'
          : '${filterType.label} general result',
      examWindowLabel: examDateRangeLabel(filteredRecords),
      generatedAt: DateTime.now(),
      summary: <ReportSummaryItem>[
        ReportSummaryItem(label: 'District', value: overview.districtName),
        ReportSummaryItem(label: 'School', value: overview.schoolName),
        ReportSummaryItem(label: 'Class', value: className),
        ReportSummaryItem(
          label: 'Students',
          value: '${filteredRecords.length}',
        ),
        ReportSummaryItem(
          label: 'Average Score',
          value: '${averageScore.toStringAsFixed(1)}%',
        ),
        ReportSummaryItem(
          label: 'Pass Rate',
          value: '${passRate.toStringAsFixed(1)}%',
        ),
        ReportSummaryItem(
          label: 'Exam Filter',
          value: examFilterLabel(filterType),
        ),
      ],
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Student Results',
          note:
              'Division is calculated from the best seven O-Level subjects together with the recorded inter-exam averages.',
          headers: const <String>[
            'Student',
            'Admission',
            'Class',
            'Average',
            'Inter Exam',
            'Division',
            'Division Points',
            'Attendance',
            'Exams Conducted',
          ],
          rows: filteredRecords.map((StudentResultRecord record) {
            return <Object?>[
              record.studentName,
              record.admissionNumber,
              record.className,
              record.averageScore.toStringAsFixed(1),
              record.interExamAverage.toStringAsFixed(1),
              record.division,
              record.divisionPoints,
              record.attendanceRate.toStringAsFixed(1),
              record.examsConducted,
            ];
          }).toList(),
        ),
      ],
      footnote:
          'Generated from the live results center. Export formats available: Excel and PDF.',
    );

    final String? path = await ReportExporter.exportReport(
      suggestedBaseName: 'general_school_result',
      report: report,
      format: format,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null
              ? 'Export cancelled.'
              : 'General school result saved to $path',
        ),
      ),
    );
  }

  Future<void> _exportExamLedger(
    BuildContext context,
    SchoolOverview overview,
    String className,
    ReportFileFormat format,
    ExamType? filterType,
  ) async {
    final List<StudentResultRecord> filteredRecords =
        filterStudentResultsByExamType(
          overview.studentResults.where(
            (StudentResultRecord record) => record.className == className,
          ),
          filterType,
        );
    final List<String> headers = <String>[
      'Student',
      'Admission',
      'Class',
      'Subject',
      'Exam Type',
      'Exam Label',
      'Exam Date',
      'Uploaded On',
      'Uploaded By',
      'Score',
      'Subject Average',
      'Grade',
      'Points',
    ];

    final List<List<Object?>> rows = <List<Object?>>[];
    for (final StudentResultRecord record in filteredRecords) {
      for (final SubjectResult subject in record.subjectResults) {
        for (final ExamMark mark in subject.examMarks) {
          rows.add(<Object?>[
            record.studentName,
            record.admissionNumber,
            record.className,
            subject.subject,
            mark.type.label,
            mark.label,
            formatShortDate(mark.examDate),
            formatDateTimeStamp(mark.uploadedAt),
            mark.teacherName ?? 'System',
            mark.score.toStringAsFixed(1),
            subject.averageScore.toStringAsFixed(1),
            subject.grade,
            subject.gradePoint,
          ]);
        }
      }
    }

    final ReportExportData report = ReportExportData(
      title: '${overview.schoolName} Exam Ledger',
      subtitle:
          'Subject-by-subject exam sheet for $className with labeled exam records filtered by ${examFilterLabel(filterType).toLowerCase()}.',
      schoolName: overview.schoolName,
      reportType: filterType == null
          ? 'All exams ledger'
          : '${filterType.label} exam ledger',
      examWindowLabel: examDateRangeLabel(filteredRecords),
      generatedAt: DateTime.now(),
      summary: <ReportSummaryItem>[
        ReportSummaryItem(label: 'District', value: overview.districtName),
        ReportSummaryItem(label: 'School', value: overview.schoolName),
        ReportSummaryItem(label: 'Class', value: className),
        ReportSummaryItem(
          label: 'Students',
          value: '${filteredRecords.length}',
        ),
        ReportSummaryItem(
          label: 'Exam Filter',
          value: examFilterLabel(filterType),
        ),
      ],
      sections: <ReportExportSection>[
        ReportExportSection(
          title: 'Exam Ledger',
          note:
              'Rows are grouped by learner and subject so teachers and leadership can audit each exam conducted.',
          headers: headers,
          rows: rows,
        ),
      ],
      footnote:
          'Generated from the live board. Export formats available: Excel and PDF.',
    );

    final String? path = await ReportExporter.exportReport(
      suggestedBaseName: 'exam_ledger_report',
      report: report,
      format: format,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? 'Export cancelled.' : 'Exam ledger saved to $path',
        ),
      ),
    );
  }

  Color _divisionTone(String division) {
    switch (division) {
      case 'Division I':
        return const Color(0xFF0F766E);
      case 'Division II':
        return const Color(0xFF155EEF);
      case 'Division III':
        return const Color(0xFF7C3AED);
      case 'Division IV':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFB91C1C);
    }
  }
}

class _ResultsClassSelector extends StatelessWidget {
  const _ResultsClassSelector({
    required this.schoolName,
    required this.classes,
    required this.selectedClass,
    required this.onClassSelected,
  });

  final String schoolName;
  final List<String> classes;
  final String? selectedClass;
  final ValueChanged<String> onClassSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Choose class before viewing results',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color.fromARGB(255, 11, 189, 168),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Professional result review starts with the class, not with a mixed school-wide table. Select the class first, then open its result board.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: classes.map((String className) {
              final bool active = className == selectedClass;
              return ChoiceChip(
                label: Text(className),
                selected: active,
                onSelected: (_) => onClassSelected(className),
                labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active
                      ? const Color.fromARGB(255, 218, 222, 230)
                      : const Color.fromARGB(255, 13, 41, 128),
                ),
                selectedColor: const Color.fromARGB(255, 6, 20, 218),
                backgroundColor: const Color.fromARGB(
                  255,
                  34,
                  234,
                  221,
                ).withValues(alpha: 0.12),
                side: BorderSide(
                  color: active
                      ? const Color.fromARGB(255, 80, 207, 235)
                      : const Color.fromARGB(
                          255,
                          207,
                          11,
                          125,
                        ).withValues(alpha: 0.18),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            selectedClass == null
                ? 'School: $schoolName'
                : 'Working class: $selectedClass',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color.fromARGB(
                255,
                36,
                14,
                14,
              ).withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsClassGate extends StatelessWidget {
  const _ResultsClassGate();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Result viewing is class-first',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'Select a class above to open its result table, student divisions, and export options. This keeps result review focused and prevents mixing different classes together.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOptionCard extends StatelessWidget {
  const _ExportOptionCard({
    required this.title,
    required this.description,
    required this.onExcel,
    required this.onPdf,
  });

  final String title;
  final String description;
  final VoidCallback onExcel;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: onExcel,
                icon: const Icon(Icons.table_chart_rounded),
                label: const Text('Excel'),
              ),
              FilledButton.tonalIcon(
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultsBoard extends StatelessWidget {
  const _ResultsBoard({
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
              _BoardBadge(
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

class _StudentResultTile extends StatelessWidget {
  const _StudentResultTile({required this.record});

  final StudentResultRecord record;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => context.go(
          '/results/${record.id}?class=${Uri.encodeComponent(record.className)}',
        ),
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFF155EEF), Color(0xFF0F766E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
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

class _FlaggedTile extends StatelessWidget {
  const _FlaggedTile({required this.record});

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
        onTap: () => context.go(
          '/results/${record.id}?class=${Uri.encodeComponent(record.className)}',
        ),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tone.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: tone),
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
                Color(0xFF155EEF),
              ),
            ),
          ),
        ],
      ),
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
