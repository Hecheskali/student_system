import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/workspace_shell.dart';
import 'management_screen.dart';

class ResultEntryProfessionalScreen extends ConsumerStatefulWidget {
  const ResultEntryProfessionalScreen({super.key, this.initialClass});

  final String? initialClass;

  @override
  ConsumerState<ResultEntryProfessionalScreen> createState() =>
      _ResultEntryProfessionalScreenState();
}

class _ResultEntryProfessionalScreenState
    extends ConsumerState<ResultEntryProfessionalScreen> {
  String _selectedClass = 'Form 1 A';
  String _searchQuery = '';
  String? _selectedStudentId;
  String? _selectedSubject;
  ExamType? _selectedExamType;
  final TextEditingController _marksController = TextEditingController();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialClass != null) {
      _selectedClass = widget.initialClass!;
    }
  }

  @override
  void dispose() {
    _marksController.dispose();
    super.dispose();
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
            child: const Text('Login to enter results'),
          ),
        ),
      );
    }

    final List<String> allClasses =
        kClassCatalog
            .expand((ClassCluster cluster) => cluster.classNames)
            .toList()
          ..sort();

    final List<StudentResultRecord> classStudents =
        adminState.studentResults
            .where(
              (StudentResultRecord record) =>
                  record.className == _selectedClass,
            )
            .toList()
          ..sort(
            (StudentResultRecord a, StudentResultRecord b) =>
                a.studentName.compareTo(b.studentName),
          );

    final List<StudentResultRecord> filteredStudents = _filterStudents(
      classStudents,
      _searchQuery,
    );
    final StudentResultRecord? selectedStudent = _selectedStudent(
      classStudents,
    );
    final List<String> subjectChoices = _subjectChoices(
      classStudents: classStudents,
      teacher: teacher,
      session: session,
    );
    final String? activeSubject = subjectChoices.contains(_selectedSubject)
        ? _selectedSubject
        : null;

    final int uploadedRecords = classStudents.fold<int>(
      0,
      (int total, StudentResultRecord record) => total + record.examsConducted,
    );

    return WorkspaceShell(
      currentSection: WorkspaceSection.operations,
      session: session,
      title: 'Manage Result Upload',
      subtitle:
          'Select a registered student, choose the subject and exam type, enter the mark on the sheet, then upload without leaving the page.',
      breadcrumbs: <Map<String, String>>[
        const <String, String>{'label': 'Dashboard', 'route': '/dashboard'},
        const <String, String>{'label': 'Manage', 'route': '/manage'},
        <String, String>{'label': _selectedClass},
      ],
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: () => context.go('/all-results'),
          icon: const Icon(Icons.table_chart_rounded),
          label: const Text('Uploaded Results'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          _ClassSelectorCard(
            selectedClass: _selectedClass,
            classes: allClasses,
            onClassSelected: (String className) {
              setState(() {
                _selectedClass = className;
                _selectedStudentId = null;
                _searchQuery = '';
                _selectedSubject = null;
                _selectedExamType = null;
                _marksController.clear();
              });
            },
          ),
          const SizedBox(height: 24),
          _ResultUploadStats(
            schoolName: overview.schoolName,
            selectedClass: _selectedClass,
            registeredStudents: classStudents.length,
            visibleStudents: filteredStudents.length,
            uploadedRecords: uploadedRecords,
          ),
          const SizedBox(height: 24),
          _ResultUploadControls(
            searchQuery: _searchQuery,
            onSearchChanged: (String query) {
              setState(() {
                _searchQuery = query;
                final bool selectedStillVisible = filteredStudents.any(
                  (StudentResultRecord record) =>
                      record.id == _selectedStudentId,
                );
                if (!selectedStillVisible) {
                  _selectedStudentId = null;
                  _marksController.clear();
                }
              });
            },
            subjects: subjectChoices,
            selectedSubject: activeSubject,
            onSubjectSelected: (String? subject) {
              setState(() {
                _selectedSubject = subject;
                _marksController.clear();
              });
            },
            selectedExamType: _selectedExamType,
            onExamTypeSelected: (ExamType? type) {
              setState(() {
                _selectedExamType = type;
                _marksController.clear();
              });
            },
          ),
          const SizedBox(height: 24),
          _ResultEntrySheet(
            students: filteredStudents,
            selectedStudentId: selectedStudent?.id,
            selectedSubject: activeSubject,
            selectedExamType: _selectedExamType,
            marksController: _marksController,
            isUploading: _isUploading,
            onStudentSelected: (StudentResultRecord student) {
              setState(() {
                _selectedStudentId = student.id;
                _marksController.clear();
              });
            },
            onUpload: selectedStudent == null
                ? null
                : () => _uploadMarks(selectedStudent, activeSubject),
          ),
        ],
      ),
    );
  }

  List<StudentResultRecord> _filterStudents(
    List<StudentResultRecord> students,
    String query,
  ) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return students;
    }

    return students.where((StudentResultRecord student) {
      return student.studentName.toLowerCase().contains(normalized) ||
          student.admissionNumber.toLowerCase().contains(normalized);
    }).toList();
  }

  StudentResultRecord? _selectedStudent(List<StudentResultRecord> students) {
    if (_selectedStudentId == null) {
      return null;
    }

    for (final StudentResultRecord student in students) {
      if (student.id == _selectedStudentId) {
        return student;
      }
    }
    return null;
  }

  List<String> _subjectChoices({
    required List<StudentResultRecord> classStudents,
    required TeacherAccount? teacher,
    required SessionUser session,
  }) {
    final Set<String> classSubjects = classStudents
        .expand((StudentResultRecord student) => student.subjectResults)
        .map((SubjectResult subject) => subject.subject)
        .toSet();

    final List<String> allowedSubjects = teacher != null
        ? teacher.effectiveSubjects
        : session.subjects.isNotEmpty && session.role == UserRole.teacher
        ? session.subjects
        : classSubjects.toList();

    final List<String> subjects =
        allowedSubjects
            .where((String subject) => classSubjects.contains(subject))
            .toSet()
            .toList()
          ..sort();
    return subjects;
  }

  Future<void> _uploadMarks(
    StudentResultRecord student,
    String? activeSubject,
  ) async {
    if (activeSubject == null || _selectedExamType == null) {
      _showSnack(
        message: 'Select a subject and exam type before uploading.',
        color: Colors.orange,
      );
      return;
    }

    final String rawMarks = _marksController.text.trim();
    if (rawMarks.isEmpty) {
      _showSnack(message: 'Enter marks for the highlighted student.');
      return;
    }

    final double? marks = double.tryParse(rawMarks);
    if (marks == null || marks < 0 || marks > 100) {
      _showSnack(message: 'Marks must be a number from 0 to 100.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final DateTime now = DateTime.now();
      final String examLabel =
          '${_selectedExamType!.label} ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';

      ref
          .read(schoolAdminProvider.notifier)
          .uploadScores(
            studentId: student.id,
            subject: activeSubject,
            examMarks: <ExamMark>[
              ExamMark(
                id: 'exam-${now.microsecondsSinceEpoch}',
                label: examLabel,
                type: _selectedExamType!,
                score: marks,
                examDate: now,
                uploadedAt: now,
              ),
            ],
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _isUploading = false;
        _marksController.clear();
      });

      _showSnack(
        message:
            'Uploaded successfully: ${student.studentName} - $activeSubject - ${marks.toStringAsFixed(1)}',
        color: Colors.green,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isUploading = false);
      _showSnack(
        message: 'Upload failed. Check the mark and try again.',
        color: Colors.red,
      );
    }
  }

  void _showSnack({required String message, Color color = Colors.orange}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _ClassSelectorCard extends StatelessWidget {
  const _ClassSelectorCard({
    required this.selectedClass,
    required this.classes,
    required this.onClassSelected,
  });

  final String selectedClass;
  final List<String> classes;
  final ValueChanged<String> onClassSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Select Class', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Only registered students in the selected class appear on the upload sheet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: classes.map((String className) {
              return ChoiceChip(
                label: Text(className),
                selected: className == selectedClass,
                onSelected: (_) => onClassSelected(className),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ResultUploadStats extends StatelessWidget {
  const _ResultUploadStats({
    required this.schoolName,
    required this.selectedClass,
    required this.registeredStudents,
    required this.visibleStudents,
    required this.uploadedRecords,
  });

  final String schoolName;
  final String selectedClass;
  final int registeredStudents;
  final int visibleStudents;
  final int uploadedRecords;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Result Upload Sheet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatCard(
                label: 'Registered Students',
                value: '$registeredStudents',
              ),
              _StatCard(label: 'Visible Rows', value: '$visibleStudents'),
              _StatCard(label: 'Uploaded Records', value: '$uploadedRecords'),
              _StatCard(label: 'Class', value: selectedClass),
              _StatCard(label: 'School', value: schoolName),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

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
              color: Colors.white.withValues(alpha: 0.76),
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

class _ResultUploadControls extends StatelessWidget {
  const _ResultUploadControls({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.subjects,
    required this.selectedSubject,
    required this.onSubjectSelected,
    required this.selectedExamType,
    required this.onExamTypeSelected,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<String> subjects;
  final String? selectedSubject;
  final ValueChanged<String?> onSubjectSelected;
  final ExamType? selectedExamType;
  final ValueChanged<ExamType?> onExamTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool narrow = constraints.maxWidth < 940;
          final Widget searchField = TextField(
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              labelText: 'Search registered student',
              hintText: 'Name or admission number',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => onSearchChanged(''),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
          final Widget subjectField = DropdownButtonFormField<String>(
            initialValue: selectedSubject,
            items: subjects.map((String subject) {
              return DropdownMenuItem<String>(
                value: subject,
                child: Text(subject, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: subjects.isEmpty ? null : onSubjectSelected,
            decoration: const InputDecoration(
              labelText: 'Subject',
              prefixIcon: Icon(Icons.menu_book_rounded),
            ),
          );
          final Widget examField = DropdownButtonFormField<ExamType>(
            initialValue: selectedExamType,
            items: ExamType.values.map((ExamType type) {
              return DropdownMenuItem<ExamType>(
                value: type,
                child: Text(type.label),
              );
            }).toList(),
            onChanged: onExamTypeSelected,
            decoration: const InputDecoration(
              labelText: 'Exam Type',
              prefixIcon: Icon(Icons.assignment_rounded),
            ),
          );

          final Widget controls = narrow
              ? Column(
                  children: <Widget>[
                    searchField,
                    const SizedBox(height: 12),
                    subjectField,
                    const SizedBox(height: 12),
                    examField,
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: subjectField),
                    const SizedBox(width: 14),
                    Expanded(flex: 2, child: examField),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Upload Controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Search or click a student row, then enter the mark in the highlighted row.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _ResultEntrySheet extends StatelessWidget {
  const _ResultEntrySheet({
    required this.students,
    required this.selectedStudentId,
    required this.selectedSubject,
    required this.selectedExamType,
    required this.marksController,
    required this.isUploading,
    required this.onStudentSelected,
    required this.onUpload,
  });

  final List<StudentResultRecord> students;
  final String? selectedStudentId;
  final String? selectedSubject;
  final ExamType? selectedExamType;
  final TextEditingController marksController;
  final bool isUploading;
  final ValueChanged<StudentResultRecord> onStudentSelected;
  final VoidCallback? onUpload;

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
            'Registered Student Sheet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Rows come only from registered students. No result rows are hard-coded into the app.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 18),
          if (students.isEmpty)
            const _ResultEntryEmptyState()
          else
            Column(
              children: <Widget>[
                const _SheetHeader(),
                const SizedBox(height: 10),
                ...students.map((StudentResultRecord student) {
                  final bool selected = student.id == selectedStudentId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StudentResultEntryRow(
                      student: student,
                      selected: selected,
                      selectedSubject: selectedSubject,
                      selectedExamType: selectedExamType,
                      marksController: marksController,
                      isUploading: isUploading,
                      onTap: () => onStudentSelected(student),
                      onUpload: selected ? onUpload : null,
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: const <Widget>[
          Expanded(flex: 3, child: Text('Student')),
          Expanded(flex: 2, child: Text('Admission')),
          Expanded(flex: 2, child: Text('Current Result')),
          Expanded(flex: 2, child: Text('Mark')),
          SizedBox(width: 150, child: Text('Action')),
        ],
      ),
    );
  }
}

class _StudentResultEntryRow extends StatelessWidget {
  const _StudentResultEntryRow({
    required this.student,
    required this.selected,
    required this.selectedSubject,
    required this.selectedExamType,
    required this.marksController,
    required this.isUploading,
    required this.onTap,
    required this.onUpload,
  });

  final StudentResultRecord student;
  final bool selected;
  final String? selectedSubject;
  final ExamType? selectedExamType;
  final TextEditingController marksController;
  final bool isUploading;
  final VoidCallback onTap;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final SubjectResult? subject = _subjectResult(student, selectedSubject);
    final String currentResult = _currentResultLabel(subject, selectedExamType);

    return Material(
      color: selected ? const Color(0xFFEAF1FF) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? const Color(0xFF155EEF)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF155EEF)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        selected ? Icons.check_rounded : Icons.person_rounded,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            student.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            student.className,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 2, child: Text(student.admissionNumber)),
              Expanded(
                flex: 2,
                child: Text(
                  currentResult,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: selected
                    ? TextField(
                        controller: marksController,
                        enabled: !isUploading,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: '0-100',
                        ),
                      )
                    : const Text('Select row'),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 136,
                child: selected
                    ? FilledButton.icon(
                        onPressed: isUploading ? null : onUpload,
                        icon: isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(isUploading ? 'Saving' : 'Upload'),
                      )
                    : FilledButton.tonal(
                        onPressed: onTap,
                        child: const Text('Select'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

SubjectResult? _subjectResult(
  StudentResultRecord student,
  String? selectedSubject,
) {
  if (selectedSubject == null) {
    return null;
  }
  for (final SubjectResult subject in student.subjectResults) {
    if (subject.subject == selectedSubject) {
      return subject;
    }
  }
  return null;
}

String _currentResultLabel(SubjectResult? subject, ExamType? selectedExamType) {
  if (subject == null) {
    return 'Choose subject';
  }
  final List<ExamMark> marks = selectedExamType == null
      ? subject.examMarks
      : subject.examMarks
            .where((ExamMark mark) => mark.type == selectedExamType)
            .toList();
  if (marks.isEmpty) {
    return 'No uploaded mark';
  }

  final double average =
      marks.fold<double>(
        0,
        (double total, ExamMark mark) => total + mark.score,
      ) /
      marks.length;
  final String examLabel = selectedExamType?.label ?? 'All exams';
  return '$examLabel ${average.toStringAsFixed(1)} (${marks.length})';
}

class _ResultEntryEmptyState extends StatelessWidget {
  const _ResultEntryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.person_search_rounded,
            size: 42,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 14),
          Text(
            'No registered students found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Register students first, then they will appear here for result upload.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}
