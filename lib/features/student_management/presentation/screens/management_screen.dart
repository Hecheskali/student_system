import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/services/necta_olevel_calculator.dart';
import '../../domain/services/necta_olevel_subjects.dart';
import '../providers/student_management_providers.dart';
import '../utils/exam_mark_reporting.dart';
import '../utils/form_validators.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({super.key, this.initialTab = 'students'});

  final String initialTab;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        final SessionUser? session = ref.watch(schoolAdminProvider).session;
        if (session == null) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Login to manage'),
              ),
            ),
          );
        }

        switch (session.role) {
          case UserRole.headOfSchool:
            return const HeadmasterManagementScreen();
          case UserRole.academicMaster:
            return const AcademicMasterManagementScreen();
          case UserRole.teacher:
            return const TeacherManagementScreen();
        }
      },
    );
  }
}

// ignore: unused_element
class _ManagementView extends ConsumerWidget {
  const _ManagementView({required this.initialTab});

  final String initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final TeacherAccount? teacher = ref.watch(currentTeacherProvider);
    final SessionUser? session = adminState.session;

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to manage students'),
          ),
        ),
      );
    }

    return WorkspaceShell(
      currentSection: WorkspaceSection.operations,
      session: session,
      title: 'Student Management',
      subtitle:
          'Use a class-first workflow to add students and enter subject results without popups or comma-separated score fields.',
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => context.go('/results'),
          icon: const Icon(Icons.table_view_rounded),
          label: const Text('Open Results Table'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/records'),
          icon: const Icon(Icons.history_edu_rounded),
          label: const Text('Records'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/profiles'),
          icon: const Icon(Icons.perm_media_rounded),
          label: const Text('Profiles'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/manage?tab=students'),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Students'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/manage?tab=results'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Results'),
        ),
      ],
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compactViewport =
              constraints.maxHeight < 820 || constraints.maxWidth < 960;
          final bool veryCompact =
              constraints.maxHeight < 720 || constraints.maxWidth < 760;
          final double gap = compactViewport ? 12 : 18;
          final double horizontalPadding = compactViewport ? 16 : 20;
          final double bottomPadding = compactViewport ? 18 : 24;
          final double shellRadius = compactViewport ? 24 : 28;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              compactViewport ? 4 : 8,
              horizontalPadding,
              bottomPadding,
            ),
            child: Column(
              children: <Widget>[
                RevealMotion(
                  child: _ManagementHero(
                    overview: overview,
                    session: session,
                    teacher: teacher,
                    compact: compactViewport,
                  ),
                ),
                SizedBox(height: gap),
                Expanded(
                  child: RevealMotion(
                    delay: const Duration(milliseconds: 90),
                    child: HoverLift(
                      borderRadius: BorderRadius.circular(shellRadius),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(shellRadius),
                          border: Border.all(color: const Color(0xFFE7EBF3)),
                        ),
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                compactViewport ? 16 : 20,
                                compactViewport ? 14 : 18,
                                compactViewport ? 16 : 20,
                                0,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TabBar(
                                  isScrollable: true,
                                  dividerColor: Colors.transparent,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: const Color(0xFF475569),
                                  labelPadding: EdgeInsets.symmetric(
                                    horizontal: compactViewport ? 10 : 16,
                                  ),
                                  indicator: BoxDecoration(
                                    color: const Color(0xFF155EEF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  indicatorPadding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  tabs: const <Widget>[
                                    Tab(text: 'Add Students'),
                                    Tab(text: 'Update Results'),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: veryCompact ? 8 : 12),
                            Expanded(
                              child: TabBarView(
                                children: <Widget>[
                                  AddStudentWorkspace(overview: overview),
                                  ResultEntryWorkspace(
                                    overview: overview,
                                    session: session,
                                    teacher: teacher,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AddStudentWorkspace extends ConsumerStatefulWidget {
  const AddStudentWorkspace({super.key, required this.overview});

  final SchoolOverview overview;

  @override
  ConsumerState<AddStudentWorkspace> createState() =>
      _AddStudentWorkspaceState();
}

class _AddStudentWorkspaceState extends ConsumerState<AddStudentWorkspace> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _selectedClass = kClassCatalog.first.classNames.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String formLabel = _selectedClass.split(' ').take(2).join(' ');
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final double sectionGap = compact ? 14 : 18;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 8 : 12,
        compact ? 16 : 20,
        compact ? 16 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const RevealMotion(
            child: _SectionIntro(
              title: 'Student intake',
              subtitle:
                  'Start by choosing the form and class. Then complete the student card below instead of using a temporary popup.',
            ),
          ),
          SizedBox(height: sectionGap),
          RevealMotion(
            delay: const Duration(milliseconds: 70),
            child: _ClassFormSelector(
              selectedClass: _selectedClass,
              onClassSelected: (String value) {
                setState(() {
                  _selectedClass = value;
                });
              },
            ),
          ),
          SizedBox(height: sectionGap),
          RevealMotion(
            delay: const Duration(milliseconds: 140),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 980;
                final Widget intakeCard = _PanelCard(
                  title: 'Student profile card',
                  subtitle:
                      'The class has already been selected, so intake stays focused and consistent.',
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _StaticInfoRow(
                          label: 'Selected form',
                          value: formLabel,
                        ),
                        const SizedBox(height: 10),
                        _StaticInfoRow(
                          label: 'Selected class',
                          value: _selectedClass,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Student Full Name',
                            hintText:
                                'e.g. JOHN PAUL SMITH (minimum 3 names, CAPITALS)',
                            helperText:
                                'Names must be in CAPITAL LETTERS with at least 3 parts',
                          ),
                          validator: FormValidators.validateStudentFullName,
                          onChanged: (value) {
                            // Optional: auto-format to uppercase as user types
                          },
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Admission setup',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Admission number is generated automatically after save so intake stays fast and consistent.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: const Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _saveStudent,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Create Student Record'),
                        ),
                      ],
                    ),
                  ),
                );

                final int classCount = widget.overview.studentResults
                    .where(
                      (StudentResultRecord record) =>
                          record.className == _selectedClass,
                    )
                    .length;
                final Widget summaryCard = _PanelCard(
                  title: 'Class intake summary',
                  subtitle:
                      'Helps you confirm where the learner will land before saving.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SummaryPill(
                        label: formLabel,
                        tone: const Color(0xFFE4ECFF),
                      ),
                      const SizedBox(height: 12),
                      _StaticInfoRow(label: 'Class', value: _selectedClass),
                      const SizedBox(height: 10),
                      _StaticInfoRow(
                        label: 'Students currently in class',
                        value: '$classCount',
                      ),
                      const SizedBox(height: 10),
                      _StaticInfoRow(
                        label: 'Workflow',
                        value: 'Class first, student next',
                      ),
                    ],
                  ),
                );

                if (stacked) {
                  return Column(
                    children: <Widget>[
                      intakeCard,
                      const SizedBox(height: 18),
                      summaryCard,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 7, child: intakeCard),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: summaryCard),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _saveStudent() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Format student name to proper uppercase
    final String formattedName = FormValidators.formatStudentName(
      _nameController.text.trim(),
    );

    ref
        .read(schoolAdminProvider.notifier)
        .addStudent(studentName: formattedName, className: _selectedClass);

    _nameController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $formattedName added to $_selectedClass'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class ResultEntryWorkspace extends ConsumerStatefulWidget {
  const ResultEntryWorkspace({
    super.key,
    required this.overview,
    required this.session,
    required this.teacher,
  });

  final SchoolOverview overview;
  final SessionUser session;
  final TeacherAccount? teacher;

  @override
  ConsumerState<ResultEntryWorkspace> createState() =>
      _ResultEntryWorkspaceState();
}

class _ResultEntryWorkspaceState extends ConsumerState<ResultEntryWorkspace> {
  String _selectedClass = 'Form 1 B';
  String? _selectedStudentId;
  int _subjectIndex = 0;
  List<_ExamDraftController> _examRows = <_ExamDraftController>[];

  List<String> get _subjects {
    if (widget.session.role == UserRole.teacher && widget.teacher != null) {
      return <String>[widget.teacher!.subject];
    }
    return kNectaOLevelDefaultSubjectNames;
  }

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.teacher?.assignedClass ?? 'Form 1 B';
    final List<StudentResultRecord> students = _studentsForClass(
      ref.read(schoolAdminProvider).studentResults,
      _selectedClass,
    );
    if (students.isNotEmpty) {
      _selectedStudentId = students.first.id;
    }
    _loadCurrentSubjectFields(ref.read(schoolAdminProvider).studentResults);
  }

  @override
  void dispose() {
    for (final _ExamDraftController row in _examRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final double sectionGap = compact ? 14 : 18;
    final List<StudentResultRecord> allResults = ref
        .watch(schoolAdminProvider)
        .studentResults;
    final List<StudentResultRecord> students = _studentsForClass(
      allResults,
      _selectedClass,
    );
    final String? effectiveStudentId =
        _selectedStudentId ?? (students.isNotEmpty ? students.first.id : null);
    final StudentResultRecord? record = effectiveStudentId == null
        ? null
        : _findRecord(allResults, effectiveStudentId);

    if (effectiveStudentId != _selectedStudentId &&
        effectiveStudentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedStudentId = effectiveStudentId;
          _subjectIndex = 0;
        });
        _loadCurrentSubjectFields(ref.read(schoolAdminProvider).studentResults);
      });
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 8 : 12,
        compact ? 16 : 20,
        compact ? 16 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const RevealMotion(
            child: _SectionIntro(
              title: 'Result entry workspace',
              subtitle:
                  'Choose the class first, then the student, then move subject by subject inside a focused result card.',
            ),
          ),
          SizedBox(height: sectionGap),
          RevealMotion(
            delay: const Duration(milliseconds: 70),
            child: _ClassFormSelector(
              selectedClass: _selectedClass,
              lockedFormPrefix: widget.teacher?.assignedClass
                  .split(' ')
                  .take(2)
                  .join(' '),
              onClassSelected: (String value) {
                final List<StudentResultRecord> nextStudents =
                    _studentsForClass(
                      ref.read(schoolAdminProvider).studentResults,
                      value,
                    );
                setState(() {
                  _selectedClass = value;
                  _selectedStudentId = nextStudents.isEmpty
                      ? null
                      : nextStudents.first.id;
                  _subjectIndex = 0;
                });
                _loadCurrentSubjectFields(
                  ref.read(schoolAdminProvider).studentResults,
                );
              },
            ),
          ),
          SizedBox(height: sectionGap),
          RevealMotion(
            delay: const Duration(milliseconds: 140),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 1140;
                final Widget studentColumn = _PanelCard(
                  title: 'Class roster',
                  subtitle:
                      'The selected class drives the rest of the workflow so staff do not enter results against the wrong group.',
                  child: students.isEmpty
                      ? const Text('No students found in this class yet.')
                      : Column(
                          children: students.map((StudentResultRecord student) {
                            final bool active =
                                student.id == effectiveStudentId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _StudentChoiceTile(
                                student: student,
                                active: active,
                                onTap: () {
                                  setState(() {
                                    _selectedStudentId = student.id;
                                    _subjectIndex = 0;
                                  });
                                  _loadCurrentSubjectFields(
                                    ref
                                        .read(schoolAdminProvider)
                                        .studentResults,
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                );

                final Widget entryColumn = _PanelCard(
                  title: 'Subject result entry',
                  subtitle:
                      'Each mark is saved with an exam type and label so reports can later filter by mid-term, annual, class exam, or teacher-named exams.',
                  child: record == null
                      ? const Text('Select or create a student to continue.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _SubjectStepper(
                              subjects: _subjects,
                              currentIndex: _subjectIndex,
                              onSubjectSelected: (int index) {
                                setState(() {
                                  _subjectIndex = index;
                                });
                                _loadCurrentSubjectFields(
                                  ref.read(schoolAdminProvider).studentResults,
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            _StudentResultSnapshot(record: record),
                            const SizedBox(height: 18),
                            _SubjectEntryBox(
                              subject: _subjects[_subjectIndex],
                              examRows: _examRows,
                              onAddExam: _addExamField,
                              onRemoveExam: _removeExamField,
                              previewAverage: _previewAverage,
                              previewGrade: _previewGrade,
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: <Widget>[
                                FilledButton.icon(
                                  onPressed: _saveCurrentSubject,
                                  icon: const Icon(Icons.save_rounded),
                                  label: const Text('Save Subject'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed:
                                      _subjectIndex >= _subjects.length - 1
                                      ? null
                                      : _saveAndNext,
                                  icon: const Icon(Icons.navigate_next_rounded),
                                  label: const Text('Save and Next Subject'),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      _subjectIndex >= _subjects.length - 1
                                      ? null
                                      : () {
                                          setState(() {
                                            _subjectIndex += 1;
                                          });
                                          _loadCurrentSubjectFields(
                                            ref
                                                .read(schoolAdminProvider)
                                                .studentResults,
                                          );
                                        },
                                  icon: const Icon(Icons.skip_next_rounded),
                                  label: const Text('Skip to Next Section'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.go('/results/${record.id}'),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text('Open Result Sheet'),
                                ),
                              ],
                            ),
                          ],
                        ),
                );

                if (stacked) {
                  return Column(
                    children: <Widget>[
                      studentColumn,
                      const SizedBox(height: 18),
                      entryColumn,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 4, child: studentColumn),
                    const SizedBox(width: 18),
                    Expanded(flex: 6, child: entryColumn),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _loadCurrentSubjectFields(List<StudentResultRecord> allResults) {
    final StudentResultRecord? record = _selectedStudentId == null
        ? null
        : _findRecord(allResults, _selectedStudentId!);
    if (record == null) {
      _replaceExamRows(<ExamMark>[_blankExamMark(0, ExamType.classExam)]);
      return;
    }

    final SubjectResult subject = record.subjectResults.firstWhere(
      (SubjectResult result) => result.subject == _subjects[_subjectIndex],
      orElse: () => const SubjectResult(
        subject: 'Unknown',
        examMarks: <ExamMark>[],
        averageScore: 0,
        grade: 'F',
        gradePoint: 5,
      ),
    );
    _replaceExamRows(
      subject.examMarks.isEmpty
          ? <ExamMark>[_blankExamMark(0, ExamType.classExam)]
          : subject.examMarks,
    );
  }

  void _replaceExamRows(List<ExamMark> marks) {
    for (final _ExamDraftController row in _examRows) {
      row.dispose();
    }
    _examRows = marks.map(_ExamDraftController.fromMark).toList();
  }

  void _addExamField(ExamType type) {
    setState(() {
      _examRows.add(
        _ExamDraftController.fromMark(_blankExamMark(_examRows.length, type)),
      );
    });
  }

  void _removeExamField(int index) {
    if (_examRows.length <= 1) {
      return;
    }
    setState(() {
      final _ExamDraftController controller = _examRows.removeAt(index);
      controller.dispose();
    });
  }

  void _saveCurrentSubject() {
    final String? studentId = _selectedStudentId;
    if (studentId == null) {
      return;
    }

    final String currentSubject = _subjects[_subjectIndex];
    final bool isScience = FormValidators.isScienceSubject(currentSubject);

    final List<ExamMark> examMarks = <ExamMark>[];
    for (int index = 0; index < _examRows.length; index += 1) {
      final _ExamDraftController row = _examRows[index];
      final double? score = double.tryParse(row.scoreController.text.trim());
      final String label = row.labelController.text.trim();

      // Validate label
      final String? labelError = FormValidators.validateExamLabel(label);
      if (labelError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(labelError)));
        return;
      }

      // Validate score
      if (score == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid number for each mark')),
        );
        return;
      }

      // Validate mark ranges based on subject type and component
      if (isScience) {
        if (row.component == ExamComponent.theory) {
          final String? error = FormValidators.validateTheoryMarks(
            score.toString(),
          );
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Row ${index + 1}: Theory mark must be 0-100. $error',
                ),
              ),
            );
            return;
          }
        } else if (row.component == ExamComponent.practical) {
          final String? error = FormValidators.validatePracticalMarks(
            score.toString(),
          );
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Row ${index + 1}: Practical mark must be 0-50. $error',
                ),
              ),
            );
            return;
          }
        }
      } else {
        final String? error = FormValidators.validateStandardMarks(
          score.toString(),
        );
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Row ${index + 1}: Mark must be 0-100. $error'),
            ),
          );
          return;
        }
      }

      examMarks.add(
        ExamMark(
          id: 'manual-$currentSubject-$index',
          label: label,
          type: row.type,
          score: score,
          component: row.component,
          examDate: DateTime.now(),
          uploadedAt: DateTime.now(),
        ),
      );
    }

    if (examMarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one exam record before saving.'),
        ),
      );
      return;
    }

    ref
        .read(schoolAdminProvider.notifier)
        .uploadScores(
          studentId: studentId,
          subject: currentSubject,
          examMarks: examMarks,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $currentSubject scores saved successfully'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveAndNext() {
    _saveCurrentSubject();
    if (_subjectIndex >= _subjects.length - 1) {
      return;
    }

    setState(() {
      _subjectIndex += 1;
    });
    _loadCurrentSubjectFields(ref.read(schoolAdminProvider).studentResults);
  }

  List<StudentResultRecord> _studentsForClass(
    List<StudentResultRecord> allResults,
    String className,
  ) {
    return allResults
        .where((StudentResultRecord record) => record.className == className)
        .toList()
      ..sort(
        (StudentResultRecord a, StudentResultRecord b) =>
            a.studentName.compareTo(b.studentName),
      );
  }

  StudentResultRecord? _findRecord(
    List<StudentResultRecord> allResults,
    String studentId,
  ) {
    for (final StudentResultRecord record in allResults) {
      if (record.id == studentId) {
        return record;
      }
    }
    return null;
  }

  double get _previewAverage {
    final List<double> exams = _examRows
        .map(
          (_ExamDraftController controller) =>
              double.tryParse(controller.scoreController.text.trim()),
        )
        .whereType<double>()
        .toList();
    if (exams.isEmpty) {
      return 0;
    }
    return double.parse(
      (exams.fold<double>(0, (double sum, double item) => sum + item) /
              exams.length)
          .toStringAsFixed(1),
    );
  }

  String get _previewGrade {
    return NectaOLevelCalculator.gradeForScore(_previewAverage).letter;
  }

  ExamMark _blankExamMark(int index, ExamType type) {
    final int order = _examRows.where((row) => row.type == type).length + 1;
    final String label = switch (type) {
      ExamType.midTerm => 'Mid-Term $order',
      ExamType.annual => 'Annual $order',
      ExamType.classExam => 'Class Exam $order',
      ExamType.teacherNamed => 'Teacher Exam $order',
    };
    return ExamMark(
      id: 'blank-${type.name}-$index',
      label: label,
      type: type,
      score: 0,
      examDate: DateTime.now(),
      uploadedAt: DateTime.now(),
    );
  }
}

class _ManagementHero extends StatelessWidget {
  const _ManagementHero({
    required this.overview,
    required this.session,
    required this.teacher,
    this.compact = false,
  });

  final SchoolOverview overview;
  final SessionUser session;
  final TeacherAccount? teacher;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF0D3B66),
            Color(0xFF0F766E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stacked = compact || constraints.maxWidth < 980;
          final Widget leftContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SummaryPill(
                label: session.role == UserRole.headOfSchool
                    ? 'Headmaster workflow'
                    : 'Teacher workflow',
                tone: Colors.white.withValues(alpha: 0.14),
                textColor: Colors.white,
              ),
              SizedBox(height: compact ? 12 : 16),
              Text(
                'Class-first management replaces the old popup flow.',
                style:
                    (compact
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.headlineSmall)
                        ?.copyWith(color: Colors.white),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                session.role == UserRole.headOfSchool
                    ? (compact
                          ? 'Move across forms, add students in context, and review results without leaving the page.'
                          : 'Move across Form 1 to Form 4, add students in context, and review each subject result section without leaving the page.')
                    : (compact
                          ? 'Work from your assigned class with boxed score entry and a direct path into the result sheet.'
                          : 'Work from your assigned class and subject with structured score boxes, exam-by-exam rows, and a direct path into the final result sheet.'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.84),
                ),
              ),
            ],
          );
          final Widget rightContent = Container(
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Current context',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                SizedBox(height: compact ? 10 : 12),
                _HeroInfo(label: 'School', value: overview.schoolName),
                SizedBox(height: compact ? 6 : 8),
                _HeroInfo(label: 'Classes ready', value: 'Form 1 to Form 4'),
                SizedBox(height: compact ? 6 : 8),
                _HeroInfo(
                  label: session.role == UserRole.teacher
                      ? 'Assigned class'
                      : 'Total students',
                  value: session.role == UserRole.teacher
                      ? (teacher?.assignedClass ?? 'Not set')
                      : '${overview.totalStudents}',
                ),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                leftContent,
                SizedBox(height: compact ? 12 : 16),
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

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
        ),
      ],
    );
  }
}

class _ClassFormSelector extends StatelessWidget {
  const _ClassFormSelector({
    required this.selectedClass,
    required this.onClassSelected,
    this.lockedFormPrefix,
  });

  final String selectedClass;
  final String? lockedFormPrefix;
  final ValueChanged<String> onClassSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: kClassCatalog.map((ClassCluster cluster) {
        final bool locked =
            lockedFormPrefix != null && cluster.formLabel != lockedFormPrefix;
        return SizedBox(
          width: 250,
          child: HoverLift(
            borderRadius: BorderRadius.circular(24),
            shadowColor: locked
                ? const Color(0xFF94A3B8)
                : const Color(0xFF155EEF),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: locked
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFEAF1FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.apartment_rounded,
                            color: locked
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF155EEF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cluster.formLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: cluster.classNames.map((String className) {
                        final bool active = className == selectedClass;
                        return ChoiceChip(
                          label: Text(className),
                          selected: active,
                          onSelected: locked
                              ? null
                              : (_) => onClassSelected(className),
                        );
                      }).toList(),
                    ),
                    if (locked) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        'Locked to your assigned form.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StudentChoiceTile extends StatelessWidget {
  const _StudentChoiceTile({
    required this.student,
    required this.active,
    required this.onTap,
  });

  final StudentResultRecord student;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(22),
      shadowColor: const Color(0xFF155EEF),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? const Color(0xFF155EEF) : const Color(0xFFE2E8F0),
            ),
            color: active ? const Color(0xFFEAF1FF) : const Color(0xFFF8FAFC),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                student.studentName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text('${student.admissionNumber} • ${student.division}'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _SummaryPill(
                    label: '${student.averageScore.toStringAsFixed(1)}%',
                    tone: const Color(0xFFE4ECFF),
                  ),
                  _SummaryPill(
                    label: '${student.examsConducted} exams',
                    tone: const Color(0xFFE8F7EE),
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

class _SubjectStepper extends StatelessWidget {
  const _SubjectStepper({
    required this.subjects,
    required this.currentIndex,
    required this.onSubjectSelected,
  });

  final List<String> subjects;
  final int currentIndex;
  final ValueChanged<int> onSubjectSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: subjects.asMap().entries.map((MapEntry<int, String> entry) {
        final bool active = entry.key == currentIndex;
        return HoverLift(
          borderRadius: BorderRadius.circular(18),
          shadowColor: const Color(0xFF155EEF),
          child: InkWell(
            onTap: () => onSubjectSelected(entry.key),
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: active
                    ? const Color(0xFF155EEF)
                    : const Color(0xFFF8FAFC),
                border: Border.all(
                  color: active
                      ? const Color(0xFF155EEF)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.18)
                          : const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: active ? Colors.white : const Color(0xFF155EEF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    entry.value,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: active ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SubjectEntryBox extends StatelessWidget {
  const _SubjectEntryBox({
    required this.subject,
    required this.examRows,
    required this.onAddExam,
    required this.onRemoveExam,
    required this.previewAverage,
    required this.previewGrade,
  });

  final String subject;
  final List<_ExamDraftController> examRows;
  final ValueChanged<ExamType> onAddExam;
  final ValueChanged<int> onRemoveExam;
  final double previewAverage;
  final String previewGrade;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(24),
      shadowColor: const Color(0xFF155EEF),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 760;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFF9FBFF), Color(0xFFF4F8FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCE7FA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        subject,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Record each assessment with its own type and label so marks stay readable and reports can filter by exam type later.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SummaryPill(
                        label: previewAverage == 0
                            ? 'Preview pending'
                            : 'Avg ${previewAverage.toStringAsFixed(1)}% • $previewGrade',
                        tone: const Color(0xFFE4ECFF),
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              subject,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Record each assessment with its own type and label so marks stay readable and reports can filter by exam type later.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: const Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SummaryPill(
                        label: previewAverage == 0
                            ? 'Preview pending'
                            : 'Avg ${previewAverage.toStringAsFixed(1)}% • $previewGrade',
                        tone: const Color(0xFFE4ECFF),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                Column(
                  children: examRows.asMap().entries.map((
                    MapEntry<int, _ExamDraftController> entry,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDCE7FA)),
                        ),
                        child: compact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  DropdownButtonFormField<ExamType>(
                                    initialValue: entry.value.type,
                                    decoration: const InputDecoration(
                                      labelText: 'Exam type',
                                    ),
                                    items: ExamType.values.map((ExamType type) {
                                      return DropdownMenuItem<ExamType>(
                                        value: type,
                                        child: Text(type.label),
                                      );
                                    }).toList(),
                                    onChanged: (ExamType? value) {
                                      if (value == null) {
                                        return;
                                      }
                                      entry.value.type = value;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: entry.value.labelController,
                                    decoration: const InputDecoration(
                                      labelText: 'Exam label',
                                      hintText: 'Mid-Term 1 or Special Test',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: entry.value.scoreController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Score',
                                      suffixIcon: examRows.length > 1
                                          ? IconButton(
                                              onPressed: () =>
                                                  onRemoveExam(entry.key),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SizedBox(
                                    width: 180,
                                    child: DropdownButtonFormField<ExamType>(
                                      initialValue: entry.value.type,
                                      decoration: const InputDecoration(
                                        labelText: 'Exam type',
                                      ),
                                      items: ExamType.values.map((
                                        ExamType type,
                                      ) {
                                        return DropdownMenuItem<ExamType>(
                                          value: type,
                                          child: Text(type.label),
                                        );
                                      }).toList(),
                                      onChanged: (ExamType? value) {
                                        if (value == null) {
                                          return;
                                        }
                                        entry.value.type = value;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: entry.value.labelController,
                                      decoration: const InputDecoration(
                                        labelText: 'Exam label',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 150,
                                    child: TextField(
                                      controller: entry.value.scoreController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: 'Score',
                                        suffixIcon: examRows.length > 1
                                            ? IconButton(
                                                onPressed: () =>
                                                    onRemoveExam(entry.key),
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: () => onAddExam(ExamType.midTerm),
                      icon: const Icon(Icons.event_note_rounded),
                      label: const Text('Add Mid-Term'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => onAddExam(ExamType.annual),
                      icon: const Icon(Icons.fact_check_rounded),
                      label: const Text('Add Annual'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => onAddExam(ExamType.classExam),
                      icon: const Icon(Icons.class_rounded),
                      label: const Text('Add Class Exam'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => onAddExam(ExamType.teacherNamed),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Add Teacher Exam'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ExamDraftController {
  _ExamDraftController({
    required this.type,
    required this.labelController,
    required this.scoreController,
    this.component = ExamComponent.overall,
  });

  factory _ExamDraftController.fromMark(ExamMark mark) {
    return _ExamDraftController(
      type: mark.type,
      labelController: TextEditingController(text: mark.label),
      scoreController: TextEditingController(
        text: mark.score == 0 ? '' : mark.score.toStringAsFixed(1),
      ),
      component: mark.component,
    );
  }

  ExamType type;
  ExamComponent component;
  final TextEditingController labelController;
  final TextEditingController scoreController;

  void dispose() {
    labelController.dispose();
    scoreController.dispose();
  }
}

class _StudentResultSnapshot extends StatelessWidget {
  const _StudentResultSnapshot({required this.record});

  final StudentResultRecord record;

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
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _SummaryPill(
              label: record.studentName,
              tone: const Color(0xFFE4ECFF),
            ),
            _SummaryPill(
              label: record.className,
              tone: const Color(0xFFE8F7EE),
            ),
            _SummaryPill(
              label: '${record.averageScore.toStringAsFixed(1)}% average',
              tone: const Color(0xFFFFF4E8),
            ),
            _SummaryPill(label: record.division, tone: const Color(0xFFF4EBFF)),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(24),
      child: Card(
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

class _StaticInfoRow extends StatelessWidget {
  const _StaticInfoRow({required this.label, required this.value});

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

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.tone,
    this.textColor = const Color(0xFF0F172A),
  });

  final String label;
  final Color tone;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

@immutable
class ClassCluster {
  const ClassCluster({required this.formLabel, required this.classNames});

  final String formLabel;
  final List<String> classNames;
}

const List<ClassCluster> kClassCatalog = <ClassCluster>[
  ClassCluster(
    formLabel: 'Form 1',
    classNames: <String>['Form 1 A', 'Form 1 B'],
  ),
  ClassCluster(
    formLabel: 'Form 2',
    classNames: <String>['Form 2 A', 'Form 2 B'],
  ),
  ClassCluster(
    formLabel: 'Form 3',
    classNames: <String>['Form 3 A', 'Form 3 B'],
  ),
  ClassCluster(
    formLabel: 'Form 4',
    classNames: <String>['Form 4 A', 'Form 4 B'],
  ),
];

class HeadmasterManagementScreen extends ConsumerWidget {
  const HeadmasterManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _LeadershipManagementScreen(
      title: 'Headmaster Operations',
      subtitle:
          'Register teachers, assign one or two subjects, manage school-wide permissions, and keep student intake moving.',
      canRemoveTeachers: true,
    );
  }
}

class AcademicMasterManagementScreen extends ConsumerWidget {
  const AcademicMasterManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _LeadershipManagementScreen(
      title: 'Academic Operations',
      subtitle:
          'Control result windows, assign teacher subjects, and review the active reporting cycle before final school reports are downloaded.',
      canRemoveTeachers: false,
    );
  }
}

class TeacherManagementScreen extends ConsumerWidget {
  const TeacherManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final TeacherAccount? teacher = ref.watch(currentTeacherProvider);
    final SessionUser session = adminState.session!;

    return DefaultTabController(
      length: 2,
      child: WorkspaceShell(
        currentSection: WorkspaceSection.operations,
        session: session,
        title: 'Teacher Workspace',
        subtitle:
            'Register students, fill subject-isolated score sheets in rows and columns, and review the combined class result before export.',
        actions: <Widget>[
          FilledButton.icon(
            onPressed: () => context.go('/result-entry'),
            icon: const Icon(Icons.border_color_rounded),
            label: const Text('Result Entry Page'),
          ),
          FilledButton.tonalIcon(
            onPressed: teacher?.canDownloadResults ?? false
                ? () => context.go('/results')
                : null,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Combined Results'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Settings'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: <Widget>[
              _OperationsHeroCard(
                title: teacher == null
                    ? 'Teacher account not linked'
                    : '${teacher.name} teaches ${teacher.effectiveSubjects.join(' and ')}',
                subtitle: teacher == null
                    ? 'This session needs a linked teacher profile before subject result uploads can be isolated.'
                    : 'Only ${teacher.effectiveSubjects.join(', ')} can be uploaded from this page. Student registration, downloads, and the combined result board stay available in the same workspace.',
                pills: <String>[
                  'Subjects: ${teacher?.effectiveSubjects.length ?? 0}',
                  'Classes: ${overview.totalClasses}',
                  'Upload ${teacher?.canUploadResults ?? false ? 'Enabled' : 'Locked'}',
                  adminState.settings.autoZeroMissingPracticals
                      ? 'Missing practicals auto-fill 0'
                      : 'Manual practical entry',
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            isScrollable: true,
                            dividerColor: Colors.transparent,
                            tabs: const <Widget>[
                              Tab(text: 'Student Registration'),
                              Tab(text: 'Subject Result Sheet'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: TabBarView(
                            children: <Widget>[
                              teacher != null && !teacher.canRegisterStudents
                                  ? _AccessNotice(
                                      title: 'Student registration is disabled',
                                      subtitle:
                                          'Your school settings currently allow teachers to download results, but not create new student records.',
                                    )
                                  : AddStudentWorkspace(overview: overview),
                              teacher == null
                                  ? const _AccessNotice(
                                      title: 'Teacher profile missing',
                                      subtitle:
                                          'A headmaster or academic master needs to finish this teacher assignment before the subject sheet can open.',
                                    )
                                  : SubjectResultEntryWorkspace(
                                      teacher: teacher,
                                      session: session,
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadershipManagementScreen extends ConsumerWidget {
  const _LeadershipManagementScreen({
    required this.title,
    required this.subtitle,
    required this.canRemoveTeachers,
  });

  final String title;
  final String subtitle;
  final bool canRemoveTeachers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SchoolOverview overview = ref.watch(schoolOverviewProvider);
    final SessionUser session = adminState.session!;

    return DefaultTabController(
      length: 3,
      child: WorkspaceShell(
        currentSection: WorkspaceSection.operations,
        session: session,
        title: title,
        subtitle: subtitle,
        actions: <Widget>[
          FilledButton.icon(
            onPressed: () => _showTeacherEditorDialog(context, ref),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Register Teacher'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Settings'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: <Widget>[
              _OperationsHeroCard(
                title: '${overview.schoolName} staff and reporting controls',
                subtitle:
                    'Teacher assignment now happens here so each teacher gets only the subject pages they are responsible for, while the school still produces one combined result.',
                pills: <String>[
                  'Teachers ${overview.totalTeachers}',
                  'Students ${overview.totalStudents}',
                  adminState.settings.enforceTeacherSubjectIsolation
                      ? 'Subject isolation on'
                      : 'Subject isolation off',
                  'Term ${adminState.settings.currentTermLabel}',
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            isScrollable: true,
                            dividerColor: Colors.transparent,
                            tabs: const <Widget>[
                              Tab(text: 'Teacher Registry'),
                              Tab(text: 'Result Controls'),
                              Tab(text: 'Student Intake'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: TabBarView(
                            children: <Widget>[
                              _TeacherRegistryWorkspace(
                                canRemoveTeachers: canRemoveTeachers,
                              ),
                              const _ResultControlWorkspace(),
                              AddStudentWorkspace(overview: overview),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherRegistryWorkspace extends ConsumerWidget {
  const _TeacherRegistryWorkspace({required this.canRemoveTeachers});

  final bool canRemoveTeachers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TeacherAccount> teachers = ref
        .watch(schoolAdminProvider)
        .teachers;

    return ListView(
      children: <Widget>[
        const _SectionIntro(
          title: 'Teacher assignment registry',
          subtitle:
              'Assign one or two subjects, keep upload authority separate from registration and downloads, and update class coverage as staffing changes.',
        ),
        const SizedBox(height: 18),
        ...teachers.map((TeacherAccount teacher) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _PanelCard(
              title: teacher.name,
              subtitle:
                  '${teacher.email} • ${teacher.effectiveSubjects.join(', ')}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      ...teacher.effectiveSubjects.map(
                        (String item) => _SummaryPill(
                          label: item,
                          tone: const Color(0xFFE4ECFF),
                        ),
                      ),
                      ...teacher.effectiveClasses.map(
                        (String item) => _SummaryPill(
                          label: item,
                          tone: const Color(0xFFE8F7EE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: <Widget>[
                      _PermissionSwitch(
                        label: 'Upload results',
                        value: teacher.canUploadResults,
                        onChanged: (_) => ref
                            .read(schoolAdminProvider.notifier)
                            .toggleTeacherUpload(teacher.id),
                      ),
                      _PermissionSwitch(
                        label: 'Edit results',
                        value: teacher.canEditResults,
                        onChanged: (_) => ref
                            .read(schoolAdminProvider.notifier)
                            .toggleTeacherEdit(teacher.id),
                      ),
                      _PermissionSwitch(
                        label: 'Register students',
                        value: teacher.canRegisterStudents,
                        onChanged: (_) => ref
                            .read(schoolAdminProvider.notifier)
                            .toggleTeacherRegistration(teacher.id),
                      ),
                      _PermissionSwitch(
                        label: 'Download reports',
                        value: teacher.canDownloadResults,
                        onChanged: (_) => ref
                            .read(schoolAdminProvider.notifier)
                            .toggleTeacherDownloads(teacher.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: () => _showTeacherEditorDialog(
                          context,
                          ref,
                          teacher: teacher,
                        ),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit Assignment'),
                      ),
                      if (canRemoveTeachers)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showRemoveTeacherDialog(context, ref, teacher),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove Teacher'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ResultControlWorkspace extends ConsumerWidget {
  const _ResultControlWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminState state = ref.watch(schoolAdminProvider);
    final SchoolAdminController controller = ref.read(
      schoolAdminProvider.notifier,
    );

    return ListView(
      children: <Widget>[
        const _SectionIntro(
          title: 'Result controls',
          subtitle:
              'Keep upload windows open, decide whether teachers can only see their assigned subjects, and control how missing practical marks behave in Form 3 and Form 4 science classes.',
        ),
        const SizedBox(height: 18),
        _PanelCard(
          title: 'Reporting window',
          subtitle:
              'These controls affect when staff can upload, edit, and finalize score sheets.',
          child: Column(
            children: <Widget>[
              _StaticInfoRow(
                label: 'Upload deadline',
                value: state.resultWindow.uploadDeadline
                    .toString()
                    .split(' ')
                    .first,
              ),
              const SizedBox(height: 10),
              _StaticInfoRow(
                label: 'Edit deadline',
                value: state.resultWindow.editDeadline
                    .toString()
                    .split(' ')
                    .first,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () => controller.extendUploadDeadline(
                      const Duration(days: 1),
                    ),
                    icon: const Icon(Icons.add_alarm_rounded),
                    label: const Text('Upload +1 day'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        controller.extendEditDeadline(const Duration(days: 1)),
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Edit +1 day'),
                  ),
                  _PermissionSwitch(
                    label: 'Lock all editing',
                    value: state.resultWindow.editingLocked,
                    onChanged: controller.setEditingLocked,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PanelCard(
          title: 'School policy',
          subtitle:
              'These settings keep teacher upload pages narrow while preserving the shared combined result board.',
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _PermissionSwitch(
                label: 'Teacher subject isolation',
                value: state.settings.enforceTeacherSubjectIsolation,
                onChanged: controller.setTeacherSubjectIsolation,
              ),
              _PermissionSwitch(
                label: 'Auto-fill missing practicals with 0',
                value: state.settings.autoZeroMissingPracticals,
                onChanged: controller.setAutoZeroPracticals,
              ),
              _PermissionSwitch(
                label: 'Teachers can register students',
                value: state.settings.allowTeacherStudentRegistration,
                onChanged: controller.setTeacherStudentRegistrationEnabled,
              ),
              _PermissionSwitch(
                label: 'Teachers can download results',
                value: state.settings.allowTeacherResultDownloads,
                onChanged: controller.setTeacherResultDownloadsEnabled,
              ),
              _PermissionSwitch(
                label: 'Teachers can open combined results',
                value: state.settings.showCombinedResultsToTeachers,
                onChanged: controller.setCombinedResultsVisibilityForTeachers,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SubjectResultEntryWorkspace extends ConsumerStatefulWidget {
  const SubjectResultEntryWorkspace({
    super.key,
    required this.teacher,
    required this.session,
    this.initialClass,
  });

  final TeacherAccount teacher;
  final SessionUser session;
  final String? initialClass;

  @override
  ConsumerState<SubjectResultEntryWorkspace> createState() =>
      _SubjectResultEntryWorkspaceState();
}

class _SubjectResultEntryWorkspaceState
    extends ConsumerState<SubjectResultEntryWorkspace> {
  late String _selectedClass;
  late String _selectedSubject;
  late ExamType _examType;
  late DateTime _selectedExamDate;
  late final TextEditingController _examLabelController;
  late final TextEditingController _studentNameController;
  late final TextEditingController _studentAdmissionController;
  late final TextEditingController _studentAttendanceController;
  final Map<String, TextEditingController> _scoreControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _practicalControllers =
      <String, TextEditingController>{};
  bool _showStudentIntake = false;

  @override
  void initState() {
    super.initState();
    _selectedClass =
        widget.initialClass != null &&
            _availableClasses.contains(widget.initialClass)
        ? widget.initialClass!
        : _availableClasses.first;
    _selectedSubject = widget.teacher.effectiveSubjects.first;
    _examType = ExamType.midTerm;
    _selectedExamDate = DateTime.now();
    _examLabelController = TextEditingController(text: _defaultExamLabel);
    _studentNameController = TextEditingController();
    _studentAdmissionController = TextEditingController();
    _studentAttendanceController = TextEditingController(text: '92');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentSheet());
  }

  @override
  void didUpdateWidget(covariant SubjectResultEntryWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? incomingClass = widget.initialClass;
    if (incomingClass != null &&
        incomingClass != oldWidget.initialClass &&
        _availableClasses.contains(incomingClass) &&
        incomingClass != _selectedClass) {
      _selectedClass = incomingClass;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentSheet());
    }
  }

  List<String> get _availableClasses {
    final List<String> classes = widget.teacher.effectiveClasses.toList()
      ..sort();
    return classes.isEmpty ? <String>['Form 1 North'] : classes;
  }

  String get _defaultExamLabel {
    switch (_examType) {
      case ExamType.midTerm:
        return 'Mid-Term 1';
      case ExamType.annual:
        return 'Annual 1';
      case ExamType.classExam:
        return 'Class Exam 1';
      case ExamType.teacherNamed:
        return 'Teacher Assessment';
    }
  }

  bool get _usesPracticals {
    return (_selectedClass.startsWith('Form 3') ||
            _selectedClass.startsWith('Form 4')) &&
        const <String>{
          'Biology',
          'Chemistry',
          'Physics',
        }.contains(_selectedSubject);
  }

  @override
  void dispose() {
    _examLabelController.dispose();
    _studentNameController.dispose();
    _studentAdmissionController.dispose();
    _studentAttendanceController.dispose();
    for (final TextEditingController controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _practicalControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final List<StudentResultRecord> classStudents =
        adminState.studentResults
            .where(
              (StudentResultRecord record) =>
                  record.className == _selectedClass &&
                  record.subjectResults.any(
                    (SubjectResult result) =>
                        result.subject == _selectedSubject,
                  ),
            )
            .toList()
          ..sort(
            (StudentResultRecord a, StudentResultRecord b) =>
                a.studentName.compareTo(b.studentName),
          );
    final int completedRows = classStudents
        .where(
          (StudentResultRecord record) =>
              _rowStatus(record, adminState.settings) == _EntryRowStatus.ready,
        )
        .length;
    final int pendingRows = classStudents.length - completedRows;
    final double sheetAverage = _enteredSheetAverage(
      classStudents,
      adminState.settings,
    );
    final StudentResultRecord? topEntry = _topEnteredStudent(
      classStudents,
      adminState.settings,
    );
    final bool locked = adminState.resultWindow.editingLocked;
    final bool canRegisterStudents =
        widget.teacher.canRegisterStudents &&
        adminState.settings.allowTeacherStudentRegistration;
    final bool canSave =
        !locked && widget.teacher.canUploadResults && classStudents.isNotEmpty;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < 1180;

        final Widget mainColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ResultEntryHeroPanel(
              title: '$_selectedSubject marksheet',
              subtitle:
                  'Work on one subject only for $_selectedClass. The sheet keeps live grade checks, practical averaging where required, and clean upload control for this exact exam session.',
              statusLabel: locked ? 'Editing locked' : 'Editing open',
              statusTone: locked
                  ? const Color(0xFFFFEDD5)
                  : const Color(0xFFDCFCE7),
              summary: <_ResultEntryMetricData>[
                _ResultEntryMetricData(
                  label: 'Working class',
                  value: _selectedClass,
                  icon: Icons.group_work_rounded,
                ),
                _ResultEntryMetricData(
                  label: 'Students',
                  value: '${classStudents.length}',
                  icon: Icons.groups_2_rounded,
                ),
                _ResultEntryMetricData(
                  label: 'Ready rows',
                  value: '$completedRows/${classStudents.length}',
                  icon: Icons.playlist_add_check_circle_rounded,
                ),
                _ResultEntryMetricData(
                  label: 'Exam day',
                  value: formatShortDate(_selectedExamDate),
                  icon: Icons.calendar_month_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ResultEntrySurface(
              eyebrow: 'Exam Session',
              title: 'Session setup',
              subtitle:
                  'Confirm the subject, exam type, label, and exam date before the ledger opens for score entry.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: <Widget>[
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSubject,
                          decoration: const InputDecoration(
                            labelText: 'Assigned subject',
                          ),
                          items: widget.teacher.effectiveSubjects
                              .map(
                                (String subject) => DropdownMenuItem<String>(
                                  value: subject,
                                  child: Text(subject),
                                ),
                              )
                              .toList(),
                          onChanged: (String? value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedSubject = value;
                            });
                            _loadCurrentSheet();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<ExamType>(
                          initialValue: _examType,
                          decoration: const InputDecoration(
                            labelText: 'Exam type',
                          ),
                          items: ExamType.values
                              .map(
                                (ExamType type) => DropdownMenuItem<ExamType>(
                                  value: type,
                                  child: Text(type.label),
                                ),
                              )
                              .toList(),
                          onChanged: (ExamType? value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _examType = value;
                              _examLabelController.text = _defaultExamLabel;
                            });
                            _loadCurrentSheet();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _examLabelController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Exam label',
                            hintText: 'Write your own exam name',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _ReadOnlySessionField(
                          label: 'Working class',
                          value: _selectedClass,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: _pickExamDate,
                        icon: const Icon(Icons.event_rounded),
                        label: Text(
                          'Exam Date ${formatShortDate(_selectedExamDate)}',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _loadCurrentSheet,
                        icon: const Icon(Icons.history_toggle_off_rounded),
                        label: const Text('Load Existing Sheet'),
                      ),
                      if (_usesPracticals)
                        const _LedgerModeBadge(
                          label: 'Theory + Practical average',
                          tone: Color(0xFFDBEAFE),
                          textColor: Color(0xFF1D4ED8),
                        )
                      else
                        const _LedgerModeBadge(
                          label: 'Single-score entry',
                          tone: Color(0xFFDCFCE7),
                          textColor: Color(0xFF166534),
                        ),
                      _LedgerModeBadge(
                        label: widget.teacher.name,
                        tone: const Color(0xFFF1F5F9),
                        textColor: const Color(0xFF334155),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ResultEntrySurface(
              eyebrow: 'Score Ledger',
              title: 'Student score sheet',
              subtitle: _usesPracticals
                  ? 'Science practical subjects in Form 3 and Form 4 record theory and practical separately, then combine them into one session score.'
                  : 'Only students registered for the selected subject appear here, with live grade preview before upload.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Assigned subjects',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.teacher.effectiveSubjects.map((
                      String subject,
                    ) {
                      final bool active = subject == _selectedSubject;
                      return _SubjectSelectionChip(
                        label: subject,
                        selected: active,
                        onTap: () {
                          if (active) {
                            return;
                          }
                          setState(() {
                            _selectedSubject = subject;
                          });
                          _loadCurrentSheet();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  _ScoreSheetActionBar(
                    selectedSubject: _selectedSubject,
                    className: _selectedClass,
                    studentCount: classStudents.length,
                    canRegisterStudents: canRegisterStudents,
                    showingIntake: _showStudentIntake,
                    onToggleStudentIntake: () {
                      setState(() {
                        _showStudentIntake = !_showStudentIntake;
                      });
                    },
                    onReviewSheet: classStudents.isEmpty
                        ? null
                        : () => _reviewSheet(classStudents),
                  ),
                  if (_showStudentIntake && canRegisterStudents) ...<Widget>[
                    const SizedBox(height: 18),
                    _ResultEntryStudentIntakeCard(
                      className: _selectedClass,
                      subject: _selectedSubject,
                      nameController: _studentNameController,
                      admissionController: _studentAdmissionController,
                      attendanceController: _studentAttendanceController,
                      onCreateStudent: _registerStudentFromSheet,
                    ),
                  ],
                  const SizedBox(height: 18),
                  classStudents.isEmpty
                      ? const _ResultEntryEmptyState(
                          title: 'No registered students for this subject',
                          subtitle:
                              'Use the add-student action here, or register learners to this class first, then the score ledger will open with their names ready for marks entry.',
                        )
                      : _SubjectEntryLedger(
                          records: classStudents,
                          usesPracticals: _usesPracticals,
                          settings: adminState.settings,
                          subjectResultsFor: (StudentResultRecord record) =>
                              _subjectResultFor(record),
                          previewGradeFor: (StudentResultRecord record) =>
                              _previewGrade(record, adminState.settings),
                          combinedScoreFor: (StudentResultRecord record) =>
                              _combinedScore(record, adminState.settings),
                          rowStatusFor: (StudentResultRecord record) =>
                              _rowStatus(record, adminState.settings),
                          scoreControllerFor: (StudentResultRecord record) =>
                              _scoreControllers.putIfAbsent(
                                record.id,
                                () => TextEditingController(),
                              ),
                          practicalControllerFor:
                              (StudentResultRecord record) =>
                                  _practicalControllers.putIfAbsent(
                                    record.id,
                                    () => TextEditingController(),
                                  ),
                          onValueChanged: () => setState(() {}),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: classStudents.isEmpty
                      ? null
                      : () => _reviewSheet(classStudents),
                  icon: const Icon(Icons.preview_rounded),
                  label: const Text('Review Sheet'),
                ),
                FilledButton.icon(
                  onPressed: canSave ? () => _saveSheet(classStudents) : null,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Save And Upload Sheet'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      adminState.settings.showCombinedResultsToTeachers &&
                          widget.teacher.canDownloadResults
                      ? () => context.go(
                          '/results?class=${Uri.encodeComponent(_selectedClass)}',
                        )
                      : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Open Class Results'),
                ),
              ],
            ),
          ],
        );

        final Widget sideColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PanelCard(
              title: 'Sheet Status',
              subtitle:
                  'Keep completion, provisional performance, and exam identity visible while typing scores.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _SummaryPill(
                        label: '$completedRows ready',
                        tone: const Color(0xFFDCFCE7),
                      ),
                      _SummaryPill(
                        label: '$pendingRows pending',
                        tone: const Color(0xFFFFEDD5),
                      ),
                      _SummaryPill(
                        label:
                            'Sheet avg ${sheetAverage == 0 ? '0.0' : sheetAverage.toStringAsFixed(1)}%',
                        tone: const Color(0xFFDBEAFE),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _StaticInfoRow(label: 'Exam type', value: _examType.label),
                  const SizedBox(height: 12),
                  _StaticInfoRow(
                    label: 'Exam label',
                    value: _examLabelController.text.trim().isEmpty
                        ? _defaultExamLabel
                        : _examLabelController.text.trim(),
                  ),
                  const SizedBox(height: 12),
                  _StaticInfoRow(
                    label: 'Practical mode',
                    value: _usesPracticals ? 'Enabled' : 'Not required',
                  ),
                  const SizedBox(height: 12),
                  _StaticInfoRow(
                    label: 'Top provisional learner',
                    value: topEntry?.studentName ?? 'No scores entered yet',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PanelCard(
              title: 'Combined Class Snapshot',
              subtitle:
                  'This side rail keeps the current class ranking visible without leaving the marksheet.',
              child: Column(
                children: classStudents.take(6).map((
                  StudentResultRecord record,
                ) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ResultEntrySnapshotTile(record: record),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _PanelCard(
              title: 'Class Performance Analysis',
              subtitle:
                  'General class performance stays available here while subject scores are being captured.',
              child: _SubjectEntryClassAnalysis(
                className: _selectedClass,
                records: classStudents,
                subject: _selectedSubject,
              ),
            ),
          ],
        );

        if (stacked) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                mainColumn,
                const SizedBox(height: 18),
                sideColumn,
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 8, child: mainColumn),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: sideColumn),
            ],
          ),
        );
      },
    );
  }

  SubjectResult _subjectResultFor(StudentResultRecord record) {
    return record.subjectResults.firstWhere(
      (SubjectResult result) => result.subject == _selectedSubject,
    );
  }

  double? _parsedScore(TextEditingController? controller) {
    if (controller == null) {
      return null;
    }
    final String text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
  }

  double? _combinedScore(StudentResultRecord record, SchoolSettings settings) {
    final double? theory = _parsedScore(_scoreControllers[record.id]);
    if (!_usesPracticals) {
      return theory?.clamp(0, 100);
    }
    final double? practical = _parsedScore(_practicalControllers[record.id]);
    if (theory == null && practical == null) {
      return null;
    }
    if (theory == null) {
      return null;
    }
    if (practical == null && !settings.autoZeroMissingPracticals) {
      return null;
    }
    final double resolvedPractical = practical ?? 0;
    return (((theory) + resolvedPractical) / 2).clamp(0, 100);
  }

  String _previewGrade(StudentResultRecord record, SchoolSettings settings) {
    final double? combinedScore = _combinedScore(record, settings);
    if (combinedScore == null) {
      return _subjectResultFor(record).grade;
    }
    return NectaOLevelCalculator.gradeForScore(combinedScore).letter;
  }

  _EntryRowStatus _rowStatus(
    StudentResultRecord record,
    SchoolSettings settings,
  ) {
    final double? theory = _parsedScore(_scoreControllers[record.id]);
    if (theory == null) {
      return _EntryRowStatus.pending;
    }
    if (!_usesPracticals) {
      return _EntryRowStatus.ready;
    }
    final double? practical = _parsedScore(_practicalControllers[record.id]);
    if (practical != null || settings.autoZeroMissingPracticals) {
      return _EntryRowStatus.ready;
    }
    return _EntryRowStatus.partial;
  }

  double _enteredSheetAverage(
    List<StudentResultRecord> classStudents,
    SchoolSettings settings,
  ) {
    final List<double> scores = classStudents
        .map((StudentResultRecord record) => _combinedScore(record, settings))
        .whereType<double>()
        .toList();
    if (scores.isEmpty) {
      return 0;
    }
    final double total = scores.fold<double>(
      0,
      (double sum, double value) => sum + value,
    );
    return total / scores.length;
  }

  StudentResultRecord? _topEnteredStudent(
    List<StudentResultRecord> classStudents,
    SchoolSettings settings,
  ) {
    StudentResultRecord? leader;
    double? highestScore;
    for (final StudentResultRecord record in classStudents) {
      final double? score = _combinedScore(record, settings);
      if (score == null) {
        continue;
      }
      if (highestScore == null || score > highestScore) {
        highestScore = score;
        leader = record;
      }
    }
    return leader;
  }

  void _registerStudentFromSheet() {
    final String name = _studentNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the student full name first.')),
      );
      return;
    }
    final String admission = _studentAdmissionController.text.trim();
    final double? attendance = double.tryParse(
      _studentAttendanceController.text.trim(),
    );
    if (attendance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid attendance baseline for the student.'),
        ),
      );
      return;
    }

    ref
        .read(schoolAdminProvider.notifier)
        .addStudent(
          studentName: name,
          className: _selectedClass,
          admissionNumber: admission.isEmpty ? null : admission,
          attendanceRate: attendance,
        );

    _studentNameController.clear();
    _studentAdmissionController.clear();
    _studentAttendanceController.text = '92';

    setState(() {
      _showStudentIntake = false;
    });
    _loadCurrentSheet();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name added to $_selectedClass and is ready for $_selectedSubject entry.',
        ),
      ),
    );
  }

  void _reviewSheet(List<StudentResultRecord> classStudents) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Review subject sheet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirm the subject, exam, and student scores before upload.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _SummaryPill(
                      label: _selectedSubject,
                      tone: const Color(0xFFDBEAFE),
                    ),
                    _SummaryPill(
                      label: _selectedClass,
                      tone: const Color(0xFFEFF6FF),
                    ),
                    _SummaryPill(
                      label: _examType.label,
                      tone: const Color(0xFFF1F5F9),
                    ),
                    _SummaryPill(
                      label: formatShortDate(_selectedExamDate),
                      tone: const Color(0xFFECFCCB),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: <DataColumn>[
                        const DataColumn(label: Text('Student')),
                        const DataColumn(label: Text('Admission')),
                        const DataColumn(label: Text('Grade')),
                        const DataColumn(label: Text('Score')),
                        if (_usesPracticals)
                          const DataColumn(label: Text('Practical')),
                        const DataColumn(label: Text('Combined')),
                        const DataColumn(label: Text('Status')),
                      ],
                      rows: classStudents.map((StudentResultRecord record) {
                        final double? theory = _parsedScore(
                          _scoreControllers[record.id],
                        );
                        final double? practical = _parsedScore(
                          _practicalControllers[record.id],
                        );
                        final double? combined = _combinedScore(
                          record,
                          ref.read(schoolAdminProvider).settings,
                        );
                        return DataRow(
                          cells: <DataCell>[
                            DataCell(Text(record.studentName)),
                            DataCell(Text(record.admissionNumber)),
                            DataCell(
                              Text(
                                _previewGrade(
                                  record,
                                  ref.read(schoolAdminProvider).settings,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                theory == null
                                    ? '-'
                                    : theory.toStringAsFixed(1),
                              ),
                            ),
                            if (_usesPracticals)
                              DataCell(
                                Text(
                                  practical == null
                                      ? '-'
                                      : practical.toStringAsFixed(1),
                                ),
                              ),
                            DataCell(
                              Text(
                                combined == null
                                    ? '-'
                                    : combined.toStringAsFixed(1),
                              ),
                            ),
                            DataCell(
                              Text(switch (_rowStatus(
                                record,
                                ref.read(schoolAdminProvider).settings,
                              )) {
                                _EntryRowStatus.pending => 'Pending',
                                _EntryRowStatus.partial => 'Partial',
                                _EntryRowStatus.ready => 'Ready',
                              }),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(bottomSheetContext).pop();
                        _saveSheet(classStudents);
                      },
                      icon: const Icon(Icons.cloud_upload_rounded),
                      label: const Text('Confirm And Upload'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Back To Editing'),
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

  void _loadCurrentSheet() {
    final SchoolAdminState state = ref.read(schoolAdminProvider);
    final List<StudentResultRecord> classStudents = state.studentResults
        .where(
          (StudentResultRecord record) => record.className == _selectedClass,
        )
        .toList();
    final String sessionKey = _sheetSessionKey(
      subject: _selectedSubject,
      examType: _examType,
      examLabel: _examLabelController.text.trim().isEmpty
          ? _defaultExamLabel
          : _examLabelController.text.trim(),
      examDate: _selectedExamDate,
    );

    for (final TextEditingController controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller
        in _practicalControllers.values) {
      controller.dispose();
    }
    _scoreControllers.clear();
    _practicalControllers.clear();

    for (final StudentResultRecord record in classStudents) {
      final SubjectResult subjectResult = record.subjectResults.firstWhere(
        (SubjectResult result) => result.subject == _selectedSubject,
      );
      ExamMark? theoryMark;
      ExamMark? practicalMark;
      for (final ExamMark mark in subjectResult.examMarks) {
        if (mark.sessionKey != sessionKey) {
          continue;
        }
        if (theoryMark == null && mark.examDate != null) {
          _selectedExamDate = mark.examDate!;
        }
        if (mark.component == ExamComponent.practical) {
          practicalMark = mark;
        } else {
          theoryMark = mark;
        }
      }

      _scoreControllers[record.id] = TextEditingController(
        text: theoryMark == null ? '' : theoryMark.score.toStringAsFixed(1),
      );
      _practicalControllers[record.id] = TextEditingController(
        text: practicalMark == null
            ? ''
            : practicalMark.score.toStringAsFixed(1),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _saveSheet(List<StudentResultRecord> classStudents) {
    final String examLabel = _examLabelController.text.trim();
    if (examLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the exam label before saving.')),
      );
      return;
    }

    final SchoolAdminState state = ref.read(schoolAdminProvider);
    final Map<String, double> theoryScores = <String, double>{};
    final Map<String, double> practicalScores = <String, double>{};

    for (final StudentResultRecord record in classStudents) {
      final String theoryText = _scoreControllers[record.id]?.text.trim() ?? '';
      final double? theory = double.tryParse(theoryText);
      if (theory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter a valid score for ${record.studentName} before saving.',
            ),
          ),
        );
        return;
      }
      theoryScores[record.id] = theory.clamp(0, 100);

      if (_usesPracticals) {
        final String practicalText =
            _practicalControllers[record.id]?.text.trim() ?? '';
        final double? practical = practicalText.isEmpty
            ? (state.settings.autoZeroMissingPracticals ? 0 : null)
            : double.tryParse(practicalText);
        if (practical == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Enter the practical score for ${record.studentName} or enable auto-zero in settings.',
              ),
            ),
          );
          return;
        }
        practicalScores[record.id] = practical.clamp(0, 100);
      }
    }

    ref
        .read(schoolAdminProvider.notifier)
        .saveSubjectScoreSheet(
          teacherId: widget.teacher.id,
          teacherName: widget.teacher.name,
          className: _selectedClass,
          subject: _selectedSubject,
          examLabel: examLabel,
          examType: _examType,
          examDate: _selectedExamDate,
          theoryScores: theoryScores,
          practicalScores: _usesPracticals ? practicalScores : null,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_selectedSubject scores saved for ${classStudents.length} students on ${formatShortDate(_selectedExamDate)}.',
        ),
      ),
    );
  }

  Future<void> _pickExamDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedExamDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedExamDate = picked;
    });
  }
}

enum _EntryRowStatus { pending, partial, ready }

class _ResultEntryHeroPanel extends StatelessWidget {
  const _ResultEntryHeroPanel({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusTone,
    required this.summary,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusTone;
  final List<_ResultEntryMetricData> summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF08111F),
            Color(0xFF123761),
            Color(0xFF0F766E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Teacher marksheet workspace',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusTone,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: summary.map((final _ResultEntryMetricData item) {
              return _ResultEntryMetricCard(data: item);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ResultEntryMetricData {
  const _ResultEntryMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _ResultEntryMetricCard extends StatelessWidget {
  const _ResultEntryMetricCard({required this.data});

  final _ResultEntryMetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultEntrySurface extends StatelessWidget {
  const _ResultEntrySurface({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF155EEF),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF475569),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlySessionField extends StatelessWidget {
  const _ReadOnlySessionField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _LedgerModeBadge extends StatelessWidget {
  const _LedgerModeBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

class _SubjectSelectionChip extends StatelessWidget {
  const _SubjectSelectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF155EEF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF155EEF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

class _ScoreSheetActionBar extends StatelessWidget {
  const _ScoreSheetActionBar({
    required this.selectedSubject,
    required this.className,
    required this.studentCount,
    required this.canRegisterStudents,
    required this.showingIntake,
    required this.onToggleStudentIntake,
    required this.onReviewSheet,
  });

  final String selectedSubject;
  final String className;
  final int studentCount;
  final bool canRegisterStudents;
  final bool showingIntake;
  final VoidCallback onToggleStudentIntake;
  final VoidCallback? onReviewSheet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _SummaryPill(
            label: '$selectedSubject roster',
            tone: const Color(0xFFDBEAFE),
          ),
          _SummaryPill(
            label: '$className • $studentCount students',
            tone: const Color(0xFFF1F5F9),
          ),
          if (canRegisterStudents)
            FilledButton.tonalIcon(
              onPressed: onToggleStudentIntake,
              icon: Icon(
                showingIntake
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.person_add_alt_1_rounded,
              ),
              label: Text(
                showingIntake ? 'Hide Student Form' : 'Add Student Here',
              ),
            ),
          OutlinedButton.icon(
            onPressed: onReviewSheet,
            icon: const Icon(Icons.rule_folder_rounded),
            label: const Text('Review Before Upload'),
          ),
        ],
      ),
    );
  }
}

class _ResultEntryStudentIntakeCard extends StatelessWidget {
  const _ResultEntryStudentIntakeCard({
    required this.className,
    required this.subject,
    required this.nameController,
    required this.admissionController,
    required this.attendanceController,
    required this.onCreateStudent,
  });

  final String className;
  final String subject;
  final TextEditingController nameController;
  final TextEditingController admissionController;
  final TextEditingController attendanceController;
  final VoidCallback onCreateStudent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Register learner into this score sheet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add the learner details here, then the new row becomes available immediately for $subject marks in $className.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              SizedBox(
                width: 260,
                child: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Student full name',
                    hintText: 'Enter learner name',
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: admissionController,
                  decoration: const InputDecoration(
                    labelText: 'Admission number',
                    hintText: 'Optional custom number',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: attendanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Attendance baseline',
                    hintText: '0 - 100',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _SummaryPill(
                label: 'Class $className',
                tone: const Color(0xFFEFF6FF),
              ),
              _SummaryPill(
                label: 'Subject row opens for $subject',
                tone: const Color(0xFFECFCCB),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreateStudent,
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Create Student In Sheet'),
          ),
        ],
      ),
    );
  }
}

class _SubjectEntryLedger extends StatelessWidget {
  const _SubjectEntryLedger({
    required this.records,
    required this.usesPracticals,
    required this.settings,
    required this.subjectResultsFor,
    required this.previewGradeFor,
    required this.combinedScoreFor,
    required this.rowStatusFor,
    required this.scoreControllerFor,
    required this.practicalControllerFor,
    required this.onValueChanged,
  });

  final List<StudentResultRecord> records;
  final bool usesPracticals;
  final SchoolSettings settings;
  final SubjectResult Function(StudentResultRecord record) subjectResultsFor;
  final String Function(StudentResultRecord record) previewGradeFor;
  final double? Function(StudentResultRecord record) combinedScoreFor;
  final _EntryRowStatus Function(StudentResultRecord record) rowStatusFor;
  final TextEditingController Function(StudentResultRecord record)
  scoreControllerFor;
  final TextEditingController Function(StudentResultRecord record)
  practicalControllerFor;
  final VoidCallback onValueChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: usesPracticals ? 1170 : 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: <Widget>[
                  const _LedgerHeaderCell(text: '#', width: 52),
                  const _LedgerHeaderCell(text: 'Student', width: 230),
                  const _LedgerHeaderCell(text: 'Admission', width: 130),
                  const _LedgerHeaderCell(text: 'Previous Avg', width: 120),
                  const _LedgerHeaderCell(text: 'Grade', width: 96),
                  const _LedgerHeaderCell(text: 'Division', width: 110),
                  _LedgerHeaderCell(
                    text: usesPracticals ? 'Theory' : 'Score',
                    width: 130,
                  ),
                  if (usesPracticals)
                    const _LedgerHeaderCell(text: 'Practical', width: 130),
                  const _LedgerHeaderCell(text: 'Session', width: 100),
                  const _LedgerHeaderCell(text: 'Status', width: 120),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...records.asMap().entries.map((
              MapEntry<int, StudentResultRecord> entry,
            ) {
              final StudentResultRecord record = entry.value;
              final SubjectResult subjectResult = subjectResultsFor(record);
              final _EntryRowStatus status = rowStatusFor(record);
              final double? combinedScore = combinedScoreFor(record);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    children: <Widget>[
                      _LedgerValueCell(
                        width: 52,
                        child: Text(
                          '${entry.key + 1}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      _LedgerValueCell(
                        width: 230,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              record.studentName,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${record.attendanceRate.toStringAsFixed(0)}% attendance',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      _LedgerValueCell(
                        width: 130,
                        child: Text(record.admissionNumber),
                      ),
                      _LedgerValueCell(
                        width: 120,
                        child: Text(
                          '${subjectResult.averageScore.toStringAsFixed(1)}%',
                        ),
                      ),
                      _LedgerValueCell(
                        width: 96,
                        child: _CompactToneBadge(
                          label: previewGradeFor(record),
                          background: const Color(0xFFDBEAFE),
                          foreground: const Color(0xFF1D4ED8),
                        ),
                      ),
                      _LedgerValueCell(
                        width: 110,
                        child: _CompactToneBadge(
                          label: record.division,
                          background: const Color(0xFFF1F5F9),
                          foreground: const Color(0xFF334155),
                        ),
                      ),
                      _LedgerValueCell(
                        width: 130,
                        child: _LedgerScoreInput(
                          controller: scoreControllerFor(record),
                          label: usesPracticals ? 'Theory' : 'Score',
                          onChanged: (_) => onValueChanged(),
                        ),
                      ),
                      if (usesPracticals)
                        _LedgerValueCell(
                          width: 130,
                          child: _LedgerScoreInput(
                            controller: practicalControllerFor(record),
                            label: 'Practical',
                            onChanged: (_) => onValueChanged(),
                          ),
                        ),
                      _LedgerValueCell(
                        width: 100,
                        child: Text(
                          combinedScore == null
                              ? '-'
                              : '${combinedScore.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      _LedgerValueCell(
                        width: 120,
                        child: _EntryStatusBadge(status: status),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (usesPracticals && settings.autoZeroMissingPracticals)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Missing practical scores currently auto-fill as 0 from school settings.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LedgerHeaderCell extends StatelessWidget {
  const _LedgerHeaderCell({required this.text, required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LedgerValueCell extends StatelessWidget {
  const _LedgerValueCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _LedgerScoreInput extends StatelessWidget {
  const _LedgerScoreInput({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}

class _CompactToneBadge extends StatelessWidget {
  const _CompactToneBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: foreground),
      ),
    );
  }
}

class _EntryStatusBadge extends StatelessWidget {
  const _EntryStatusBadge({required this.status});

  final _EntryRowStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color background;
    late final Color foreground;
    switch (status) {
      case _EntryRowStatus.pending:
        label = 'Pending';
        background = const Color(0xFFFFEDD5);
        foreground = const Color(0xFF9A3412);
      case _EntryRowStatus.partial:
        label = 'Partial';
        background = const Color(0xFFFEF3C7);
        foreground = const Color(0xFF92400E);
      case _EntryRowStatus.ready:
        label = 'Ready';
        background = const Color(0xFFDCFCE7);
        foreground = const Color(0xFF166534);
    }
    return _CompactToneBadge(
      label: label,
      background: background,
      foreground: foreground,
    );
  }
}

class _ResultEntrySnapshotTile extends StatelessWidget {
  const _ResultEntrySnapshotTile({required this.record});

  final StudentResultRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            record.studentName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            record.admissionNumber,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _CompactToneBadge(
                label: '${record.averageScore.toStringAsFixed(1)}%',
                background: const Color(0xFFDBEAFE),
                foreground: const Color(0xFF1D4ED8),
              ),
              _CompactToneBadge(
                label: record.division,
                background: const Color(0xFFF1F5F9),
                foreground: const Color(0xFF334155),
              ),
              _CompactToneBadge(
                label: '${record.subjectResults.length} subjects',
                background: const Color(0xFFDCFCE7),
                foreground: const Color(0xFF166534),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultEntryEmptyState extends StatelessWidget {
  const _ResultEntryEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

class _OperationsHeroCard extends StatelessWidget {
  const _OperationsHeroCard({
    required this.title,
    required this.subtitle,
    required this.pills,
  });

  final String title;
  final String subtitle;
  final List<String> pills;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF163C69),
            Color(0xFF0F766E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: pills
                .map(
                  (String item) => _SummaryPill(
                    label: item,
                    tone: Colors.white.withValues(alpha: 0.14),
                    textColor: Colors.white,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PermissionSwitch extends StatelessWidget {
  const _PermissionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: _PanelCard(
          title: title,
          subtitle: subtitle,
          child: const Text(
            'Open Settings or ask school leadership to update the permission policy for this account.',
          ),
        ),
      ),
    );
  }
}

class _SubjectEntryClassAnalysis extends StatelessWidget {
  const _SubjectEntryClassAnalysis({
    required this.className,
    required this.records,
    required this.subject,
  });

  final String className;
  final List<StudentResultRecord> records;
  final String subject;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Text('No class analysis is available until students exist.');
    }

    final double classAverage =
        records.fold<double>(
          0,
          (double sum, StudentResultRecord record) => sum + record.averageScore,
        ) /
        records.length;
    final List<StudentResultRecord> ranked = <StudentResultRecord>[...records]
      ..sort(
        (StudentResultRecord a, StudentResultRecord b) =>
            b.averageScore.compareTo(a.averageScore),
      );
    final StudentResultRecord topStudent = ranked.first;
    final SubjectResult? strongestSubjectResult = records
        .map(
          (StudentResultRecord record) => record.subjectResults.firstWhere(
            (SubjectResult result) => result.subject == subject,
            orElse: () => const SubjectResult(
              subject: 'Unknown',
              examMarks: <ExamMark>[],
              averageScore: 0,
              grade: 'F',
              gradePoint: 5,
            ),
          ),
        )
        .where((SubjectResult result) => result.subject == subject)
        .fold<SubjectResult?>(null, (
          SubjectResult? current,
          SubjectResult next,
        ) {
          if (current == null || next.averageScore > current.averageScore) {
            return next;
          }
          return current;
        });
    final Map<String, int> divisionSpread = <String, int>{
      'Division I': 0,
      'Division II': 0,
      'Division III': 0,
      'Division IV': 0,
      'Division 0': 0,
    };
    for (final StudentResultRecord record in records) {
      divisionSpread[record.division] =
          (divisionSpread[record.division] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _SummaryPill(
              label: '$className average ${classAverage.toStringAsFixed(1)}%',
              tone: const Color(0xFFE4ECFF),
            ),
            _SummaryPill(
              label: 'Top learner ${topStudent.studentName}',
              tone: const Color(0xFFE8F7EE),
            ),
            if (strongestSubjectResult != null)
              _SummaryPill(
                label: '$subject best grade ${strongestSubjectResult.grade}',
                tone: const Color(0xFFF4EBFF),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: divisionSpread.entries.map((MapEntry<String, int> entry) {
            return _SummaryPill(
              label: '${entry.key}: ${entry.value}',
              tone: const Color(0xFFF8FAFC),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Future<void> _showTeacherEditorDialog(
  BuildContext context,
  WidgetRef ref, {
  TeacherAccount? teacher,
}) async {
  final bool editing = teacher != null;
  final TextEditingController nameController = TextEditingController(
    text: teacher?.name ?? '',
  );
  final TextEditingController emailController = TextEditingController(
    text: teacher?.email ?? '',
  );
  final Set<String> selectedSubjects = <String>{...?teacher?.effectiveSubjects}
    ..removeWhere((String value) => value.trim().isEmpty);
  final Set<String> selectedClasses = <String>{...?teacher?.effectiveClasses}
    ..removeWhere((String value) => value.trim().isEmpty);
  if (selectedSubjects.isEmpty) {
    selectedSubjects.add('Basic Mathematics');
  }
  if (selectedClasses.isEmpty) {
    selectedClasses.add('Form 1 A');
  }

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder:
            (BuildContext context, void Function(void Function()) setState) {
              return AlertDialog(
                title: Text(
                  editing ? 'Edit Teacher Assignment' : 'Register Teacher',
                ),
                content: SizedBox(
                  width: 640,
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
                        const SizedBox(height: 18),
                        Text(
                          'Assign up to two subjects',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: kNectaOLevelSubjectNames.map((
                            String subject,
                          ) {
                            final bool selected = selectedSubjects.contains(
                              subject,
                            );
                            final bool locked =
                                !selected && selectedSubjects.length >= 2;
                            return FilterChip(
                              label: Text(subject),
                              selected: selected,
                              onSelected: locked
                                  ? null
                                  : (bool value) {
                                      setState(() {
                                        if (value) {
                                          selectedSubjects.add(subject);
                                        } else {
                                          selectedSubjects.remove(subject);
                                        }
                                        if (selectedSubjects.isEmpty) {
                                          selectedSubjects.add(
                                            'Basic Mathematics',
                                          );
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Classes taught',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: kClassCatalog
                              .expand((ClassCluster item) => item.classNames)
                              .map((String schoolClass) {
                                return FilterChip(
                                  label: Text(schoolClass),
                                  selected: selectedClasses.contains(
                                    schoolClass,
                                  ),
                                  onSelected: (bool value) {
                                    setState(() {
                                      if (value) {
                                        selectedClasses.add(schoolClass);
                                      } else {
                                        selectedClasses.remove(schoolClass);
                                      }
                                      if (selectedClasses.isEmpty) {
                                        selectedClasses.add('Form 1 A');
                                      }
                                    });
                                  },
                                );
                              })
                              .toList(),
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
                      final String email = emailController.text.trim();
                      if (name.isEmpty || !email.contains('@')) {
                        return;
                      }

                      final List<String> subjects = selectedSubjects.toList();
                      final List<String> classes = selectedClasses.toList();
                      final SchoolAdminController controller = ref.read(
                        schoolAdminProvider.notifier,
                      );

                      if (editing) {
                        controller.updateTeacherAssignments(
                          teacherId: teacher.id,
                          subjects: subjects,
                          assignedClasses: classes,
                        );
                      } else {
                        controller.addTeacher(
                          name: name,
                          email: email,
                          subjects: subjects,
                          assignedClasses: classes,
                        );
                      }

                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(editing ? 'Save' : 'Register'),
                  ),
                ],
              );
            },
      );
    },
  );

  nameController.dispose();
  emailController.dispose();
}

Future<void> _showRemoveTeacherDialog(
  BuildContext context,
  WidgetRef ref,
  TeacherAccount teacher,
) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Remove Teacher'),
        content: Text(
          'Remove ${teacher.name} from the registry? Their subject assignment will disappear from teacher login immediately.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(schoolAdminProvider.notifier).removeTeacher(teacher.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );
}

String _sheetSessionKey({
  required String subject,
  required ExamType examType,
  required String examLabel,
  required DateTime examDate,
}) {
  final String month = examDate.month.toString().padLeft(2, '0');
  final String day = examDate.day.toString().padLeft(2, '0');
  return '${subject.toLowerCase()}-${examType.name}-${examLabel.toLowerCase().replaceAll(' ', '-')}-${examDate.year}-$month-$day';
}
