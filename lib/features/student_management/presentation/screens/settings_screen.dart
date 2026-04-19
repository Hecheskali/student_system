import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/workspace_shell.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _yearController;
  late final TextEditingController _termController;

  @override
  void initState() {
    super.initState();
    final SchoolSettings settings = ref.read(schoolAdminProvider).settings;
    _yearController = TextEditingController(text: settings.currentAcademicYear);
    _termController = TextEditingController(text: settings.currentTermLabel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SchoolSettings settings = ref.read(schoolAdminProvider).settings;
    if (_yearController.text != settings.currentAcademicYear) {
      _yearController.text = settings.currentAcademicYear;
    }
    if (_termController.text != settings.currentTermLabel) {
      _termController.text = settings.currentTermLabel;
    }
  }

  @override
  void dispose() {
    _yearController.dispose();
    _termController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SchoolAdminState adminState = ref.watch(schoolAdminProvider);
    final SessionUser? session = adminState.session;
    final TeacherAccount? teacher = ref.watch(currentTeacherProvider);

    if (session == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login to open settings'),
          ),
        ),
      );
    }

    final bool leadership = session.role != UserRole.teacher;

    return WorkspaceShell(
      currentSection: WorkspaceSection.settings,
      session: session,
      title: 'Settings',
      subtitle: leadership
          ? 'Control subject isolation, teacher permissions, reporting windows, and the academic cycle from one place.'
          : 'Review the rules that apply to your account, subject uploads, student registration, and combined results.',
      actions: <Widget>[
        FilledButton.tonalIcon(
          onPressed: () => context.go('/manage'),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Operations'),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          _SettingsHero(
            title: leadership
                ? '${adminState.schoolName} controls'
                : '${session.name} account policy',
            subtitle: leadership
                ? 'Settings now cover the real school workflow: teacher assignment, practical handling, result downloads, and academic cycle control.'
                : 'Teachers can see exactly which permissions are open, which subjects are assigned, and whether combined result access is enabled.',
            chips: <String>[
              'Year ${adminState.settings.currentAcademicYear}',
              adminState.settings.currentTermLabel,
              adminState.settings.enforceTeacherSubjectIsolation
                  ? 'Subject isolation on'
                  : 'Subject isolation off',
              adminState.resultWindow.editingLocked
                  ? 'Editing locked'
                  : 'Editing open',
            ],
          ),
          const SizedBox(height: 18),
          if (leadership) ...<Widget>[
            _SettingsCard(
              title: 'Academic cycle',
              subtitle:
                  'Use this when the school moves to a new year, term, or reporting cycle.',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'Academic year',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _termController,
                      decoration: const InputDecoration(
                        labelText: 'Term label',
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saveAcademicCycle,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save cycle'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LeadershipSettingsPanel(state: adminState),
          ] else ...<Widget>[
            _TeacherSettingsPanel(
              state: adminState,
              teacher: teacher,
              session: session,
            ),
          ],
        ],
      ),
    );
  }

  void _saveAcademicCycle() {
    ref
        .read(schoolAdminProvider.notifier)
        .setAcademicCycle(
          academicYear: _yearController.text.trim().isEmpty
              ? '2026'
              : _yearController.text.trim(),
          termLabel: _termController.text.trim().isEmpty
              ? 'Term II'
              : _termController.text.trim(),
        );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Academic cycle updated.')));
  }
}

class _LeadershipSettingsPanel extends ConsumerWidget {
  const _LeadershipSettingsPanel({required this.state});

  final SchoolAdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SchoolAdminController controller = ref.read(
      schoolAdminProvider.notifier,
    );

    return Column(
      children: <Widget>[
        _SettingsCard(
          title: 'Teacher policy',
          subtitle:
              'These switches control what all teachers are generally allowed to do across the live school workflow.',
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _SettingToggle(
                label: 'Teacher subject isolation',
                value: state.settings.enforceTeacherSubjectIsolation,
                onChanged: controller.setTeacherSubjectIsolation,
              ),
              _SettingToggle(
                label: 'Auto-zero missing practicals',
                value: state.settings.autoZeroMissingPracticals,
                onChanged: controller.setAutoZeroPracticals,
              ),
              _SettingToggle(
                label: 'Allow teacher registration',
                value: state.settings.allowTeacherStudentRegistration,
                onChanged: controller.setTeacherStudentRegistrationEnabled,
              ),
              _SettingToggle(
                label: 'Allow teacher downloads',
                value: state.settings.allowTeacherResultDownloads,
                onChanged: controller.setTeacherResultDownloadsEnabled,
              ),
              _SettingToggle(
                label: 'Show combined results to teachers',
                value: state.settings.showCombinedResultsToTeachers,
                onChanged: controller.setCombinedResultsVisibilityForTeachers,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Result window',
          subtitle:
              'Use quick controls here, or extend the exact deadlines from the operations page.',
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _SettingValue(
                label: 'Upload deadline',
                value: state.resultWindow.uploadDeadline
                    .toString()
                    .split(' ')
                    .first,
              ),
              _SettingValue(
                label: 'Edit deadline',
                value: state.resultWindow.editDeadline
                    .toString()
                    .split(' ')
                    .first,
              ),
              _SettingToggle(
                label: 'Lock editing',
                value: state.resultWindow.editingLocked,
                onChanged: controller.setEditingLocked,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeacherSettingsPanel extends StatelessWidget {
  const _TeacherSettingsPanel({
    required this.state,
    required this.teacher,
    required this.session,
  });

  final SchoolAdminState state;
  final TeacherAccount? teacher;
  final SessionUser session;

  @override
  Widget build(BuildContext context) {
    final List<String> subjects =
        teacher?.effectiveSubjects ?? session.effectiveSubjects;
    final List<String> classes =
        teacher?.effectiveClasses ?? session.effectiveClasses;

    return Column(
      children: <Widget>[
        _SettingsCard(
          title: 'Assigned teaching area',
          subtitle:
              'Only these subjects can be uploaded from your teacher result sheet. Everything else stays hidden on that page.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              ...subjects.map(
                (String item) =>
                    _SettingChip(label: item, color: const Color(0xFFE4ECFF)),
              ),
              ...classes.map(
                (String item) =>
                    _SettingChip(label: item, color: const Color(0xFFE8F7EE)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'Permissions',
          subtitle:
              'This reflects the active school policy for your teacher account.',
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _SettingValue(
                label: 'Upload results',
                value: teacher?.canUploadResults ?? false
                    ? 'Enabled'
                    : 'Locked',
              ),
              _SettingValue(
                label: 'Edit results',
                value: teacher?.canEditResults ?? false ? 'Enabled' : 'Locked',
              ),
              _SettingValue(
                label: 'Register students',
                value: teacher?.canRegisterStudents ?? false
                    ? 'Enabled'
                    : 'Locked',
              ),
              _SettingValue(
                label: 'Download reports',
                value: teacher?.canDownloadResults ?? false
                    ? 'Enabled'
                    : 'Locked',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsCard(
          title: 'School result policy',
          subtitle:
              'These settings explain how the general school result is produced after each teacher finishes their own subject sheet.',
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _SettingValue(
                label: 'Combined result board',
                value: state.settings.showCombinedResultsToTeachers
                    ? 'Visible'
                    : 'Hidden for teachers',
              ),
              _SettingValue(
                label: 'Subject isolation',
                value: state.settings.enforceTeacherSubjectIsolation
                    ? 'Enabled'
                    : 'Disabled',
              ),
              _SettingValue(
                label: 'Science practical rule',
                value: state.settings.autoZeroMissingPracticals
                    ? 'Missing practicals become 0'
                    : 'Manual practical entry',
              ),
              _SettingValue(
                label: 'Editing window',
                value: state.resultWindow.editingLocked ? 'Closed' : 'Open',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  final String title;
  final String subtitle;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF19406E),
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
            children: chips
                .map(
                  (String item) => _SettingChip(
                    label: item,
                    color: Colors.white.withValues(alpha: 0.14),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
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
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
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

class _SettingValue extends StatelessWidget {
  const _SettingValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _SettingChip extends StatelessWidget {
  const _SettingChip({
    required this.label,
    required this.color,
    this.textColor = const Color(0xFF0F172A),
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
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
