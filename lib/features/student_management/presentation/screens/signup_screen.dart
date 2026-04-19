import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../../domain/services/necta_olevel_subjects.dart';
import '../providers/student_management_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.initialRole = UserRole.teacher});

  final UserRole initialRole;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late UserRole _role;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _schoolController;
  late final TextEditingController _districtController;
  String _subject = _subjects.first;
  String _assignedClass = _classes.first;
  bool _isSubmitting = false;

  static final List<String> _subjects = kNectaOLevelSubjectNames;

  static const List<String> _classes = <String>[
    'Form 1 A',
    'Form 1 B',
    'Form 2 A',
    'Form 2 B',
    'Form 3 A',
    'Form 3 B',
    'Form 4 A',
    'Form 4 B',
  ];

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _schoolController = TextEditingController(text: 'Summit View College');
    _districtController = TextEditingController(text: 'Jabu District');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLiveBackend = ref.watch(supabaseServiceProvider) != null;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFF7FBFF),
              Color(0xFFEAF1FF),
              Color(0xFFF8FAFC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = constraints.maxWidth < 900;
                    return Flex(
                      direction: stacked ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(flex: 5, child: _SignUpIntro(role: _role)),
                        if (!stacked) const SizedBox(width: 18),
                        if (stacked) const SizedBox(height: 18),
                        Expanded(
                          flex: 4,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Form(
                                key: _formKey,
                                child: ListView(
                                  shrinkWrap: true,
                                  children: <Widget>[
                                    Text(
                                      'Create account',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Teachers, academic masters, and headmasters can all sign up here and enter the school workflow.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF475569),
                                          ),
                                    ),
                                    if (hasLiveBackend) ...<Widget>[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Live sign-up creates a Supabase auth account and saves the role profile to the database.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF0F766E),
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    SegmentedButton<UserRole>(
                                      segments: const <ButtonSegment<UserRole>>[
                                        ButtonSegment<UserRole>(
                                          value: UserRole.teacher,
                                          label: Text('Teacher'),
                                          icon: Icon(
                                            Icons.cast_for_education_rounded,
                                          ),
                                        ),
                                        ButtonSegment<UserRole>(
                                          value: UserRole.academicMaster,
                                          label: Text('Academic Master'),
                                          icon: Icon(Icons.school_rounded),
                                        ),
                                        ButtonSegment<UserRole>(
                                          value: UserRole.headOfSchool,
                                          label: Text('Headmaster'),
                                          icon: Icon(
                                            Icons.admin_panel_settings_rounded,
                                          ),
                                        ),
                                      ],
                                      selected: <UserRole>{_role},
                                      onSelectionChanged:
                                          (Set<UserRole> selection) {
                                            setState(() {
                                              _role = selection.first;
                                            });
                                          },
                                    ),
                                    const SizedBox(height: 18),
                                    TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Full name',
                                      ),
                                      validator: (String? value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Enter full name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                      ),
                                      validator: (String? value) {
                                        if (value == null ||
                                            !value.contains('@')) {
                                          return 'Enter a valid email';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (hasLiveBackend) ...<Widget>[
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Password',
                                        ),
                                        validator: (String? value) {
                                          if (value == null ||
                                              value.length < 6) {
                                            return 'Use at least 6 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Confirm password',
                                        ),
                                        validator: (String? value) {
                                          if (value !=
                                              _passwordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _schoolController,
                                      decoration: const InputDecoration(
                                        labelText: 'School name',
                                      ),
                                      validator: (String? value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Enter school name';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _districtController,
                                      decoration: const InputDecoration(
                                        labelText: 'District',
                                      ),
                                      validator: (String? value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Enter district name';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_role == UserRole.teacher) ...<Widget>[
                                      const SizedBox(height: 14),
                                      DropdownButtonFormField<String>(
                                        key: ValueKey<String>(_subject),
                                        initialValue: _subject,
                                        decoration: const InputDecoration(
                                          labelText: 'Subject',
                                        ),
                                        items: _subjects
                                            .map(
                                              (String subject) =>
                                                  DropdownMenuItem<String>(
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
                                            _subject = value;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      DropdownButtonFormField<String>(
                                        key: ValueKey<String>(_assignedClass),
                                        initialValue: _assignedClass,
                                        decoration: const InputDecoration(
                                          labelText: 'Assigned class',
                                        ),
                                        items: _classes
                                            .map(
                                              (String schoolClass) =>
                                                  DropdownMenuItem<String>(
                                                    value: schoolClass,
                                                    child: Text(schoolClass),
                                                  ),
                                            )
                                            .toList(),
                                        onChanged: (String? value) {
                                          if (value == null) {
                                            return;
                                          }
                                          setState(() {
                                            _assignedClass = value;
                                          });
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 22),
                                    FilledButton.icon(
                                      onPressed: _isSubmitting ? null : _submit,
                                      icon: _isSubmitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_add_alt_1_rounded,
                                            ),
                                      label: Text(
                                        _role == UserRole.teacher
                                            ? 'Create Teacher Account'
                                            : _role == UserRole.academicMaster
                                            ? 'Create Academic Master Account'
                                            : 'Create Headmaster Account',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go('/login'),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                      ),
                                      label: const Text('Back to Login'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(schoolAdminProvider.notifier)
          .registerUser(
            SignUpDraft(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              role: _role,
              schoolName: _schoolController.text.trim(),
              districtName: _districtController.text.trim(),
              subject: _role == UserRole.teacher ? _subject : null,
              assignedClass: _role == UserRole.teacher ? _assignedClass : null,
              subjects: _role == UserRole.teacher
                  ? <String>[_subject]
                  : const <String>[],
              assignedClasses: _role == UserRole.teacher
                  ? <String>[_assignedClass]
                  : const <String>[],
            ),
            password: ref.read(supabaseServiceProvider) != null
                ? _passwordController.text
                : null,
          );
      if (!mounted) {
        return;
      }
      context.go('/dashboard');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _SignUpIntro extends StatelessWidget {
  const _SignUpIntro({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF17335A),
            Color(0xFF0F766E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              role == UserRole.teacher
                  ? Icons.cast_for_education_rounded
                  : Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            role == UserRole.teacher
                ? 'Teacher sign-up now exists in the live workflow.'
                : role == UserRole.academicMaster
                ? 'Academic master sign-up now supports the full reporting workflow.'
                : 'Headmaster sign-up now leads the full monitoring workflow.',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            role == UserRole.teacher
                ? 'Create teacher access, assign a subject and class, then start uploading student scores from the reporting pages.'
                : role == UserRole.academicMaster
                ? 'Create the academic master account and move directly into exam supervision, result review, and reporting coordination.'
                : 'Create the headmaster account and move directly into school-wide supervision, permissions, division summaries, and reporting analytics.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _InfoPill(
                label: role == UserRole.teacher
                    ? 'Subject upload access'
                    : 'Teacher permission control',
              ),
              const _InfoPill(label: 'Best 7 subject division'),
              const _InfoPill(label: 'Division and analysis views'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
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
