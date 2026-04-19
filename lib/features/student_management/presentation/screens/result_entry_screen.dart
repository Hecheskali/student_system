import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/workspace_shell.dart';
import 'management_screen.dart';

class ResultEntryScreen extends ConsumerStatefulWidget {
  const ResultEntryScreen({super.key, this.initialClass});

  final String? initialClass;

  @override
  ConsumerState<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends ConsumerState<ResultEntryScreen> {
  String? _selectedClass;

  @override
  void initState() {
    super.initState();
    _selectedClass = widget.initialClass;
  }

  @override
  void didUpdateWidget(covariant ResultEntryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialClass != widget.initialClass) {
      _selectedClass = widget.initialClass;
    }
  }

  @override
  Widget build(BuildContext context) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final TeacherAccount? teacher = ref.watch(currentTeacherProvider);
    final SessionUser? session = adminState.session;
    final List<String> allClasses =
        adminState.studentResults
            .map((StudentResultRecord record) => record.className)
            .toSet()
            .toList()
          ..sort();
    final List<String> availableClasses = teacher == null
        ? allClasses
        : teacher.effectiveClasses
              .where((String className) => allClasses.contains(className))
              .toList();
    final Map<String, int> classStudentCounts = <String, int>{
      for (final String className in availableClasses)
        className: adminState.studentResults
            .where(
              (StudentResultRecord record) => record.className == className,
            )
            .length,
    };
    if (_selectedClass != null && !availableClasses.contains(_selectedClass)) {
      _selectedClass = null;
    }

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to open result entry'),
          ),
        ),
      );
    }

    final List<Map<String, String>> breadcrumbs = <Map<String, String>>[
      const <String, String>{'label': 'Dashboard', 'route': '/dashboard'},
      const <String, String>{'label': 'Result Entry', 'route': '/result-entry'},
      if (_selectedClass != null) <String, String>{'label': _selectedClass!},
    ];

    return WorkspaceShell(
      currentSection: WorkspaceSection.resultEntry,
      session: session,
      title: 'Subject Result Entry',
      subtitle:
          'Start with the class, then open the professional marksheet for subject score entry, grade checks, divisions, and live class analysis.',
      breadcrumbs: breadcrumbs,
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: () => context.go('/manage'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Operations'),
        ),
        FilledButton.tonalIcon(
          onPressed: _selectedClass == null
              ? null
              : () => context.go(
                  '/results?class=${Uri.encodeComponent(_selectedClass!)}',
                ),
          icon: const Icon(Icons.fact_check_rounded),
          label: const Text('Class Results'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: teacher == null
            ? _LeadershipNotice(session: session)
            : ListView(
                children: <Widget>[
                  _DedicatedResultHero(
                    teacher: teacher,
                    selectedClass: _selectedClass,
                    classStudentCounts: classStudentCounts,
                  ),
                  const SizedBox(height: 18),
                  _ClassStepBoard(
                    classes: availableClasses,
                    selectedClass: _selectedClass,
                    classStudentCounts: classStudentCounts,
                    onSelected: (String className) {
                      setState(() {
                        _selectedClass = className;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  if (_selectedClass == null)
                    const _ClassFirstNotice()
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SubjectResultEntryWorkspace(
                          teacher: teacher,
                          session: session,
                          initialClass: _selectedClass,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _DedicatedResultHero extends StatelessWidget {
  const _DedicatedResultHero({
    required this.teacher,
    required this.selectedClass,
    required this.classStudentCounts,
  });

  final TeacherAccount teacher;
  final String? selectedClass;
  final Map<String, int> classStudentCounts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF071524),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Class-first teacher marksheet',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            selectedClass == null
                ? 'Open the right class before the sheet appears'
                : 'Professional marksheet for $selectedClass',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            selectedClass == null
                ? 'Choose the working class first, then the system opens a proper subject ledger for registered students only. This avoids mixing classes and keeps the marksheet aligned with real school workflow.'
                : 'The sheet for $selectedClass is isolated to the teacher assignment, with registered students, live grade preview, division visibility, and class analysis kept in one cleaner workspace.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: <Widget>[
              _HeroStatChip(
                label: 'Assigned subjects',
                value: '${teacher.effectiveSubjects.length}',
              ),
              _HeroStatChip(
                label: 'Active classes',
                value: '${teacher.effectiveClasses.length}',
              ),
              _HeroStatChip(
                label: 'Registered learners',
                value:
                    '${classStudentCounts.values.fold<int>(0, (int total, int count) => total + count)}',
              ),
              if (selectedClass != null)
                _HeroStatChip(
                  label: 'Working class',
                  value:
                      '$selectedClass • ${classStudentCounts[selectedClass] ?? 0}',
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: teacher.effectiveSubjects
                .take(4)
                .map((String item) => _HeroChip(label: item))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ClassStepBoard extends StatelessWidget {
  const _ClassStepBoard({
    required this.classes,
    required this.selectedClass,
    required this.classStudentCounts,
    required this.onSelected,
  });

  final List<String> classes;
  final String? selectedClass;
  final Map<String, int> classStudentCounts;
  final ValueChanged<String> onSelected;

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
            'Step 1: Choose class',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Result entry stays locked until the working class is confirmed. That keeps the roster, subject sheet, and combined result trail on the same class.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: classes.map((String className) {
              final bool active = className == selectedClass;
              return _ClassSelectionTile(
                label: className,
                studentCount: classStudentCounts[className] ?? 0,
                selected: active,
                onTap: () => onSelected(className),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ClassFirstNotice extends StatelessWidget {
  const _ClassFirstNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Step 2 opens after class selection',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'The marksheet remains hidden until the class is selected, so result entry starts from the exact roster that belongs to that class.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

class _LeadershipNotice extends StatelessWidget {
  const _LeadershipNotice({required this.session});

  final SessionUser session;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Teacher result entry is a dedicated page',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  '${session.role.label} accounts can open this page, but subject upload stays tied to a teacher assignment so scores remain isolated by subject.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () => context.go('/manage'),
                      icon: const Icon(Icons.groups_rounded),
                      label: const Text('Manage Teachers'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/results'),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('View Combined Results'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
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

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
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

class _ClassSelectionTile extends StatelessWidget {
  const _ClassSelectionTile({
    required this.label,
    required this.studentCount,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int studentCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 220,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE0EAFF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF155EEF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.class_rounded,
                  color: selected
                      ? const Color(0xFF155EEF)
                      : const Color(0xFF475569),
                ),
                const Spacer(),
                Text(
                  '$studentCount students',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              selected ? 'Current working class' : 'Open this marksheet',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }
}
