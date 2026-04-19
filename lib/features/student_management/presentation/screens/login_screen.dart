import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/education_entities.dart';
import '../providers/student_management_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLiveBackend = ref.watch(supabaseServiceProvider) != null;
    final SessionUser? session = ref.watch(schoolAdminProvider).session;

    if (session != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/dashboard');
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFF8FBFF),
              Color(0xFFEAF2FF),
              Color(0xFFF8FAFC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = constraints.maxWidth < 900;
                    return Flex(
                      direction: stacked ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          flex: 5,
                          child: _LoginIntroCard(stacked: stacked),
                        ),
                        if (!stacked) const SizedBox(width: 18),
                        if (stacked) const SizedBox(height: 18),
                        Expanded(
                          flex: 4,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: ListView(
                                shrinkWrap: true,
                                children: <Widget>[
                                  Text(
                                    hasLiveBackend
                                        ? 'Login with Supabase'
                                        : 'Login or sign up',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    hasLiveBackend
                                        ? 'Use your Supabase email and password. If this is your first account, create it from the sign-up buttons below.'
                                        : 'Production access now includes both role login shortcuts and dedicated sign-up entry for teachers and headmaster.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: const Color(0xFF475569),
                                        ),
                                  ),
                                  const SizedBox(height: 22),
                                  if (hasLiveBackend) ...<Widget>[
                                    TextField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: Icon(Icons.mail_rounded),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon: const Icon(
                                          Icons.lock_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                          ),
                                        ),
                                      ),
                                      onSubmitted: (_) => _submitLiveLogin(),
                                    ),
                                    const SizedBox(height: 18),
                                    FilledButton.icon(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitLiveLogin,
                                      icon: _isSubmitting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.login_rounded),
                                      label: const Text('Login'),
                                    ),
                                    const SizedBox(height: 20),
                                  ] else ...<Widget>[
                                    _RoleButton(
                                      title: 'Academic Master Login',
                                      description:
                                          'Manage exam uploads, review results, set deadlines, and oversee academic performance.',
                                      icon: Icons.school_rounded,
                                      tone: const Color(0xFF7C3AED),
                                      onTap: () {
                                        ref
                                            .read(schoolAdminProvider.notifier)
                                            .loginAs(UserRole.academicMaster);
                                        context.go('/dashboard');
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _RoleButton(
                                      title: 'Teacher Login',
                                      description:
                                          'Open the teacher workspace for score uploads, student management, and personal result permissions.',
                                      icon: Icons.cast_for_education_rounded,
                                      tone: const Color(0xFF155EEF),
                                      onTap: () {
                                        ref
                                            .read(schoolAdminProvider.notifier)
                                            .loginAs(UserRole.teacher);
                                        context.go('/dashboard');
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _RoleButton(
                                      title: 'Headmaster Login',
                                      description:
                                          'Add/remove teachers, monitor school-wide operations, and manage permissions.',
                                      icon: Icons.admin_panel_settings_rounded,
                                      tone: const Color(0xFF0F766E),
                                      onTap: () {
                                        ref
                                            .read(schoolAdminProvider.notifier)
                                            .loginAs(UserRole.headOfSchool);
                                        context.go('/dashboard');
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  if (!hasLiveBackend) ...<Widget>[
                                    const Divider(),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Need an account?',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          context.go('/signup?role=teacher'),
                                      icon: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                      ),
                                      label: const Text('Teacher Sign Up'),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () => context.go(
                                        '/signup?role=academicmaster',
                                      ),
                                      icon: const Icon(Icons.school_rounded),
                                      label: const Text(
                                        'Academic Master Sign Up',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          context.go('/signup?role=headmaster'),
                                      icon: const Icon(
                                        Icons.manage_accounts_rounded,
                                      ),
                                      label: const Text('Headmaster Sign Up'),
                                    ),
                                  ],
                                ],
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

  Future<void> _submitLiveLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both email and password.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(schoolAdminProvider.notifier)
          .signInWithEmailAndPassword(email: email, password: password);
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
      ).showSnackBar(SnackBar(content: Text('Login failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _LoginIntroCard extends StatelessWidget {
  const _LoginIntroCard({required this.stacked});

  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF162B4D),
            Color(0xFF155EEF),
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
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 24),
          Text(
            'School result operations now start with the right account path.',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Teachers can upload student scores, add students, and manage subject results by exam count. Headmaster can monitor every area, control permissions, view divisions, and export reports.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This is Kidarafa Secondart School management system',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.purple.withValues(alpha: 0.82),
            ),
          ),

          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const <Widget>[
              _InfoPill(label: 'Teacher sign-up'),
              _InfoPill(label: 'Headmaster sign-up'),
              _InfoPill(label: 'Results and analytics'),
            ],
          ),
          if (!stacked) const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.title,
    required this.description,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: tone),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, color: tone),
          ],
        ),
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
