import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../utils/exam_mark_reporting.dart';
import '../widgets/workspace_shell.dart';

class AllResultsScreen extends ConsumerStatefulWidget {
  const AllResultsScreen({super.key, this.initialForm});

  final String? initialForm;

  @override
  ConsumerState<AllResultsScreen> createState() => _AllResultsScreenState();
}

class _AllResultsScreenState extends ConsumerState<AllResultsScreen> {
  String? _selectedForm;
  String? _highlightSubject;

  @override
  void initState() {
    super.initState();
    _selectedForm = widget.initialForm;
  }

  @override
  void didUpdateWidget(covariant AllResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialForm != widget.initialForm) {
      _selectedForm = widget.initialForm;
    }
  }

  @override
  Widget build(BuildContext context) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final TeacherAccount? teacher = ref.watch(currentTeacherProvider);
    final SessionUser? session = adminState.session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to open all uploaded results'),
          ),
        ),
      );
    }

    final List<String> forms =
        overview.studentResults
            .map(
              (StudentResultRecord record) => _formLabelFor(record.className),
            )
            .toSet()
            .toList()
          ..sort(_sortForms);
    if (_selectedForm == null && forms.isNotEmpty) {
      _selectedForm = forms.first;
    }
    if (_selectedForm != null && !forms.contains(_selectedForm)) {
      _selectedForm = forms.isEmpty ? null : forms.first;
    }

    final Set<String> allSubjects = overview.studentResults
        .expand((StudentResultRecord record) => record.subjectResults)
        .map((SubjectResult subject) => subject.subject)
        .toSet();
    final List<String> visibleSubjects = teacher == null
        ? (allSubjects.toList()..sort())
        : teacher.effectiveSubjects
              .where((String subject) => allSubjects.contains(subject))
              .toList();
    if (_highlightSubject == null && visibleSubjects.isNotEmpty) {
      _highlightSubject = teacher?.effectiveSubjects.firstWhere(
        (String subject) => visibleSubjects.contains(subject),
        orElse: () => visibleSubjects.first,
      );
    }
    if (_highlightSubject != null &&
        !visibleSubjects.contains(_highlightSubject)) {
      _highlightSubject = visibleSubjects.isEmpty
          ? null
          : visibleSubjects.first;
    }

    final List<StudentResultRecord> formResults = _selectedForm == null
        ? <StudentResultRecord>[]
        : (overview.studentResults
              .where(
                (StudentResultRecord record) =>
                    _formLabelFor(record.className) == _selectedForm,
              )
              .toList()
            ..sort(
              (StudentResultRecord a, StudentResultRecord b) =>
                  a.studentName.compareTo(b.studentName),
            ));
    final List<String> matrixSubjects =
        formResults
            .expand((StudentResultRecord record) => record.subjectResults)
            // Only include subjects that have marks entered (not empty)
            .where((SubjectResult subject) => subject.examMarks.isNotEmpty)
            .map((SubjectResult subject) => subject.subject)
            .toSet()
            .toList()
          ..sort();
    final Set<String> classesMerged = formResults
        .map((StudentResultRecord record) => record.className)
        .toSet();
    final double averageScore = formResults.isEmpty
        ? 0
        : formResults.fold<double>(
                0,
                (double sum, StudentResultRecord record) =>
                    sum + record.averageScore,
              ) /
              formResults.length;
    final int examRows = formResults.fold<int>(
      0,
      (int total, StudentResultRecord record) =>
          total +
          record.subjectResults.fold<int>(
            0,
            (int sum, SubjectResult subject) => sum + subject.examMarks.length,
          ),
    );

    return WorkspaceShell(
      currentSection: WorkspaceSection.allResults,
      session: session,
      title: 'Uploaded Results',
      subtitle:
          'Review one full form at a time with all class sections merged together, subject rows, student columns, and teacher subject highlighting when needed.',
      breadcrumbs: <Map<String, String>>[
        const <String, String>{'label': 'Dashboard', 'route': '/dashboard'},
        const <String, String>{
          'label': 'Uploaded Results',
          'route': '/all-results',
        },
        if (_selectedForm != null) <String, String>{'label': _selectedForm!},
      ],
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: _selectedForm == null
              ? null
              : () => context.go('/results'),
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Class Results'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          _AllResultsHero(
            schoolName: overview.schoolName,
            selectedForm: _selectedForm,
            studentCount: formResults.length,
            classCount: classesMerged.length,
            averageScore: averageScore,
            examRows: examRows,
          ),
          const SizedBox(height: 18),
          _AllResultsFilters(
            forms: forms,
            selectedForm: _selectedForm,
            availableSubjects: visibleSubjects,
            highlightSubject: _highlightSubject,
            onFormSelected: (String form) {
              setState(() {
                _selectedForm = form;
              });
            },
            onHighlightSelected: (String? subject) {
              setState(() {
                _highlightSubject = subject;
              });
            },
          ),
          const SizedBox(height: 18),
          if (_selectedForm == null)
            const _AllResultsEmptyState(
              title: 'No forms available yet',
              subtitle:
                  'Uploaded results will appear here after the school starts saving learner subject scores.',
            )
          else ...<Widget>[
            _AllResultsSummaryBar(
              formLabel: _selectedForm!,
              classes: classesMerged.toList()..sort(),
              highlightSubject: _highlightSubject,
            ),
            const SizedBox(height: 18),
            if (formResults.isEmpty)
              const _AllResultsEmptyState(
                title: 'No uploaded results for this form',
                subtitle:
                    'Choose another form or upload learner scores first from the result-entry page.',
              )
            else
              _AllResultsMatrixBoard(
                records: formResults,
                subjects: matrixSubjects,
                highlightSubject: _highlightSubject,
              ),
          ],
        ],
      ),
    );
  }

  int _sortForms(String a, String b) {
    final int? aNumber = int.tryParse(a.replaceAll('Form', '').trim());
    final int? bNumber = int.tryParse(b.replaceAll('Form', '').trim());
    if (aNumber == null || bNumber == null) {
      return a.compareTo(b);
    }
    return aNumber.compareTo(bNumber);
  }
}

String _formLabelFor(String className) {
  final List<String> parts = className.split(' ');
  if (parts.length >= 2) {
    return '${parts[0]} ${parts[1]}';
  }
  return className;
}

class _AllResultsHero extends StatelessWidget {
  const _AllResultsHero({
    required this.schoolName,
    required this.selectedForm,
    required this.studentCount,
    required this.classCount,
    required this.averageScore,
    required this.examRows,
  });

  final String schoolName;
  final String? selectedForm;
  final int studentCount;
  final int classCount;
  final double averageScore;
  final int examRows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF08111F),
            Color(0xFF163C69),
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
            selectedForm == null
                ? 'Form-wide uploaded results board'
                : '$selectedForm uploaded results board',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'Every class section inside the selected form is merged here, so $schoolName can review full-form uploaded results without splitting learners into A, B, or C pages.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _HeroInfoChip(label: 'Students', value: '$studentCount'),
              _HeroInfoChip(label: 'Classes merged', value: '$classCount'),
              _HeroInfoChip(
                label: 'Average',
                value: '${averageScore.toStringAsFixed(1)}%',
              ),
              _HeroInfoChip(label: 'Exam rows', value: '$examRows'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _AllResultsFilters extends StatelessWidget {
  const _AllResultsFilters({
    required this.forms,
    required this.selectedForm,
    required this.availableSubjects,
    required this.highlightSubject,
    required this.onFormSelected,
    required this.onHighlightSelected,
  });

  final List<String> forms;
  final String? selectedForm;
  final List<String> availableSubjects;
  final String? highlightSubject;
  final ValueChanged<String> onFormSelected;
  final ValueChanged<String?> onHighlightSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Choose form', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: forms.map((String form) {
              return ChoiceChip(
                label: Text(form),
                selected: selectedForm == form,
                onSelected: (_) => onFormSelected(form),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Highlight subject',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ChoiceChip(
                label: const Text('Show all subjects'),
                selected: highlightSubject == null,
                onSelected: (_) => onHighlightSelected(null),
              ),
              ...availableSubjects.map((String subject) {
                return ChoiceChip(
                  label: Text(subject),
                  selected: highlightSubject == subject,
                  onSelected: (_) => onHighlightSelected(subject),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllResultsSummaryBar extends StatelessWidget {
  const _AllResultsSummaryBar({
    required this.formLabel,
    required this.classes,
    required this.highlightSubject,
  });

  final String formLabel;
  final List<String> classes;
  final String? highlightSubject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          _SummaryBadge(label: '$formLabel merged board'),
          _SummaryBadge(label: '${classes.length} class sections included'),
          if (highlightSubject != null)
            _SummaryBadge(label: 'Highlighted subject: $highlightSubject'),
          ...classes.take(6).map((String className) {
            return _SummaryBadge(label: className);
          }),
        ],
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.label});

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
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: const Color(0xFF334155)),
      ),
    );
  }
}

class _AllResultsMatrixBoard extends StatelessWidget {
  const _AllResultsMatrixBoard({
    required this.records,
    required this.subjects,
    required this.highlightSubject,
  });

  final List<StudentResultRecord> records;
  final List<String> subjects;
  final String? highlightSubject;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Form result matrix',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Subjects run down the rows, student names run across the columns, and each cell lists the uploaded exam types with the marks that learner scored.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _MatrixCornerHeader(),
                    ...records.map((StudentResultRecord record) {
                      return _MatrixStudentHeader(record: record);
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                ...subjects.map((String subjectName) {
                  final bool highlighted = highlightSubject == subjectName;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _MatrixSubjectHeader(
                          subjectName: subjectName,
                          highlighted: highlighted,
                        ),
                        ...records.map((StudentResultRecord record) {
                          return _MatrixStudentSubjectCell(
                            record: record,
                            subjectName: subjectName,
                            highlighted: highlighted,
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixCornerHeader extends StatelessWidget {
  const _MatrixCornerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Subjects',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Rows',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixStudentHeader extends StatelessWidget {
  const _MatrixStudentHeader({required this.record});

  final StudentResultRecord record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go(
          '/results/${record.id}?class=${Uri.encodeComponent(record.className)}',
        ),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                record.studentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '${record.className} • ${record.admissionNumber}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _MatrixHeaderBadge(label: record.division),
                  _MatrixHeaderBadge(
                    label: '${record.averageScore.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatrixHeaderBadge extends StatelessWidget {
  const _MatrixHeaderBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _MatrixSubjectHeader extends StatelessWidget {
  const _MatrixSubjectHeader({
    required this.subjectName,
    required this.highlighted,
  });

  final String subjectName;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      constraints: const BoxConstraints(minHeight: 152),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFE0EAFF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF155EEF)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            subjectName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: highlighted
                  ? const Color(0xFF155EEF)
                  : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            highlighted ? 'Highlighted teacher subject' : 'Subject row',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: highlighted
                  ? const Color(0xFF155EEF)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixStudentSubjectCell extends StatelessWidget {
  const _MatrixStudentSubjectCell({
    required this.record,
    required this.subjectName,
    required this.highlighted,
  });

  final StudentResultRecord record;
  final String subjectName;
  final bool highlighted;

  SubjectResult? get _subjectResult {
    for (final SubjectResult result in record.subjectResults) {
      if (result.subject == subjectName) {
        return result;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final SubjectResult? subject = _subjectResult;
    final List<_ExamTypeSummary> examTypeRows = subject == null
        ? const <_ExamTypeSummary>[]
        : _examTypeSummaries(subject);

    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Container(
        width: 260,
        constraints: const BoxConstraints(minHeight: 152),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFEEF4FF) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: highlighted
                ? const Color(0xFFBFDBFE)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: subject == null
            ? Center(
                child: Text(
                  'No uploaded marks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${subject.averageScore.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: highlighted
                                    ? const Color(0xFF155EEF)
                                    : const Color(0xFF0F172A),
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: highlighted
                              ? const Color(0xFFDCE8FF)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          subject.grade,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: highlighted
                                    ? const Color(0xFF155EEF)
                                    : const Color(0xFF334155),
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${subject.examMarks.length} uploaded records',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (examTypeRows.isEmpty)
                    Text(
                      'No exam-type entries',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF94A3B8),
                      ),
                    )
                  else
                    ...examTypeRows.map((_ExamTypeSummary summary) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MatrixExamTypeLine(summary: summary),
                      );
                    }),
                ],
              ),
      ),
    );
  }
}

class _MatrixExamTypeLine extends StatelessWidget {
  const _MatrixExamTypeLine({required this.summary});

  final _ExamTypeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  summary.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                '${summary.average.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary.markBreakdown,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _ExamTypeSummary {
  const _ExamTypeSummary({
    required this.label,
    required this.average,
    required this.markBreakdown,
  });

  final String label;
  final double average;
  final String markBreakdown;
}

List<_ExamTypeSummary> _examTypeSummaries(SubjectResult subject) {
  return ExamType.values
      .map((ExamType examType) => _examTypeSummaryFor(subject, examType))
      .whereType<_ExamTypeSummary>()
      .toList(growable: false);
}

_ExamTypeSummary? _examTypeSummaryFor(
  SubjectResult subject,
  ExamType examType,
) {
  final List<ExamMark> marks = subject.examMarks
      .where((ExamMark mark) => mark.type == examType)
      .toList();
  if (marks.isEmpty) {
    return null;
  }

  return _ExamTypeSummary(
    label: examType.label,
    average: getAverageScoreForExamType(subject, examType) ?? 0,
    markBreakdown: _formatExamTypeMarks(marks),
  );
}

String _formatExamTypeMarks(List<ExamMark> marks) {
  final Map<String, List<ExamMark>> grouped = <String, List<ExamMark>>{};
  for (final ExamMark mark in marks) {
    final String key = mark.sessionKey ?? mark.id;
    grouped.putIfAbsent(key, () => <ExamMark>[]).add(mark);
  }

  return grouped.values
      .map((List<ExamMark> group) {
        final String label = group.first.label;
        if (group.length == 1 &&
            group.first.component == ExamComponent.overall) {
          return '$label: ${group.first.score.toStringAsFixed(1)}';
        }

        final String components = group
            .map((ExamMark mark) {
              return '${mark.component.label} ${mark.score.toStringAsFixed(1)}';
            })
            .join(', ');
        return '$label: $components';
      })
      .join(' | ');
}

class _AllResultsEmptyState extends StatelessWidget {
  const _AllResultsEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}
