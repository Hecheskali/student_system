import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/services/necta_olevel_subjects.dart';
import '../providers/student_management_providers.dart';
import '../utils/form_validators.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/workspace_shell.dart';
import 'management_screen.dart';

class StudentIntakeScreen extends ConsumerStatefulWidget {
  const StudentIntakeScreen({super.key, this.initialClass});

  final String? initialClass;

  @override
  ConsumerState<StudentIntakeScreen> createState() =>
      _StudentIntakeScreenState();
}

class _StudentIntakeScreenState extends ConsumerState<StudentIntakeScreen> {
  String _selectedClass = 'Form 1 A';
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialClass != null) {
      _selectedClass = widget.initialClass!;
    }
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
            child: const Text('Login to register students'),
          ),
        ),
      );
    }

    final List<String> allClasses =
        kClassCatalog.expand((cluster) => cluster.classNames).toList()..sort();

    final List<StudentResultRecord> classStudents =
        adminState.studentResults
            .where((record) => record.className == _selectedClass)
            .toList()
          ..sort((a, b) => a.studentName.compareTo(b.studentName));

    final Set<String> subjectsInClass = classStudents
        .expand((student) => student.subjectResults)
        .map((subject) => subject.subject)
        .toSet();

    final List<String> sortedSubjects = subjectsInClass.toList()..sort();

    return WorkspaceShell(
      currentSection: WorkspaceSection.studentIntake,
      session: session,
      title: 'Student Registration & Intake',
      subtitle:
          'Professional student registration with class selection, subject assignment, and complete roster visibility.',
      breadcrumbs: <Map<String, String>>[
        const <String, String>{'label': 'Dashboard', 'route': '/dashboard'},
        const <String, String>{
          'label': 'Student Registration',
          'route': '/student-intake',
        },
        <String, String>{'label': _selectedClass},
      ],
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => setState(() => _showAddForm = !_showAddForm),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(_showAddForm ? 'Cancel' : 'Add New Student'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          // Class Selector
          _ClassSelectorCard(
            selectedClass: _selectedClass,
            classes: allClasses,
            onClassSelected: (String className) {
              setState(() {
                _selectedClass = className;
                _showAddForm = false;
              });
            },
          ),
          const SizedBox(height: 24),

          // Statistics
          _StudentIntakeStats(
            schoolName: overview.schoolName,
            selectedClass: _selectedClass,
            studentCount: classStudents.length,
            subjectCount: sortedSubjects.length,
          ),
          const SizedBox(height: 24),

          // Add Student Form (if showing)
          if (_showAddForm) ...<Widget>[
            _AddStudentForm(
              selectedClass: _selectedClass,
              availableSubjects: kNectaOLevelDefaultSubjectNames,
              onStudentAdded: () {
                setState(() => _showAddForm = false);
              },
            ),
            const SizedBox(height: 24),
          ],

          // Students × Subjects Table
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 960;
              return _StudentsSubjectsTable(
                students: classStudents,
                subjects: sortedSubjects,
                compact: compact,
              );
            },
          ),
        ],
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
            'Choose the class to view and manage student registration',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
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
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StudentIntakeStats extends StatelessWidget {
  const _StudentIntakeStats({
    required this.schoolName,
    required this.selectedClass,
    required this.studentCount,
    required this.subjectCount,
  });

  final String schoolName;
  final String selectedClass;
  final int studentCount;
  final int subjectCount;

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
            'Class Intake Overview',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatCard(label: 'Students Registered', value: '$studentCount'),
              _StatCard(label: 'Subjects Assigned', value: '$subjectCount'),
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

class _AddStudentForm extends ConsumerStatefulWidget {
  const _AddStudentForm({
    required this.selectedClass,
    required this.availableSubjects,
    required this.onStudentAdded,
  });

  final String selectedClass;
  final List<String> availableSubjects;
  final VoidCallback onStudentAdded;

  @override
  ConsumerState<_AddStudentForm> createState() => _AddStudentFormState();
}

class _AddStudentFormState extends ConsumerState<_AddStudentForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final Set<String> _selectedSubjects = <String>{};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE4ECFF), width: 2),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Register New Student',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Add student details and select their subjects',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Student Full Name',
                  hintText: 'e.g. JOHN PAUL SMITH (3+ names, CAPITALS)',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: FormValidators.validateStudentFullName,
              ),
              const SizedBox(height: 18),
              Text(
                'Assign Subjects',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.availableSubjects.map((String subject) {
                  final bool selected = _selectedSubjects.contains(subject);
                  return FilterChip(
                    label: Text(subject),
                    selected: selected,
                    onSelected: (bool value) {
                      setState(() {
                        if (value) {
                          _selectedSubjects.add(subject);
                        } else {
                          _selectedSubjects.remove(subject);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _saveStudent,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Register Student'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject')),
      );
      return;
    }

    final String formattedName = FormValidators.formatStudentName(
      _nameController.text.trim(),
    );

    try {
      await ref
          .read(schoolAdminProvider.notifier)
          .addStudent(
            studentName: formattedName,
            className: widget.selectedClass,
            subjects: _selectedSubjects.toList(growable: false),
          );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not register student: $error')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    _nameController.clear();
    _selectedSubjects.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $formattedName registered to ${widget.selectedClass}'),
      ),
    );

    widget.onStudentAdded();
  }
}

class _StudentsSubjectsTable extends StatelessWidget {
  const _StudentsSubjectsTable({
    required this.students,
    required this.subjects,
    this.compact = false,
  });

  final List<StudentResultRecord> students;
  final List<String> subjects;
  final bool compact;

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
          Text(
            'Students & Subject Assignments',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'View all students and their assigned subjects. Rows: Students | Columns: Subjects',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          if (students.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.person_outline_rounded,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No students registered in this class yet',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _ProfessionalTable(
                  students: students,
                  subjects: subjects,
                  compact: compact,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfessionalTable extends StatelessWidget {
  const _ProfessionalTable({
    required this.students,
    required this.subjects,
    required this.compact,
  });

  final List<StudentResultRecord> students;
  final List<String> subjects;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      columnWidths: <int, TableColumnWidth>{
        0: const FixedColumnWidth(220),
        ...{
          for (int i = 1; i <= subjects.length; i++)
            i: const FixedColumnWidth(160),
        },
      },
      children: <TableRow>[
        // Header row with subject names
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Students',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...subjects.map((String subject) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  subject,
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ],
        ),
        // Student rows
        ...students.map((StudentResultRecord student) {
          return TableRow(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      student.studentName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.admissionNumber,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ...subjects.map((String subject) {
                final bool hasSubject = student.subjectResults.any(
                  (result) => result.subject == subject,
                );
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hasSubject
                            ? const Color(0xFFE8F7EE)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasSubject ? '✓' : '○',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: hasSubject
                              ? const Color(0xFF10B981)
                              : const Color(0xFFB45309),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}
