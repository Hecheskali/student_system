import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _hasScheduledRedirect = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLiveBackend = ref.watch(supabaseServiceProvider) != null;
    final SessionUser? session = ref.watch(schoolAdminProvider).session;

    if (session == null) {
      _hasScheduledRedirect = false;
    }

    if (session != null && !_hasScheduledRedirect) {
      _hasScheduledRedirect = true;
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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: LayoutBuilder(
                      builder:
                          (
                            BuildContext context,
                            BoxConstraints innerConstraints,
                          ) {
                            final bool stacked =
                                innerConstraints.maxWidth < 900;

                            if (stacked) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  const _LoginIntroCard(stacked: true),
                                  const SizedBox(height: 18),
                                  _LoginAuthCard(
                                    formKey: _formKey,
                                    hasLiveBackend: hasLiveBackend,
                                    isSubmitting: _isSubmitting,
                                    isPasswordVisible: _isPasswordVisible,
                                    emailController: _emailController,
                                    passwordController: _passwordController,
                                    emailFocusNode: _emailFocusNode,
                                    passwordFocusNode: _passwordFocusNode,
                                    onPasswordVisibilityToggle: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                    onSubmit: _submitLiveLogin,
                                    onRoleLogin: _handlePreviewRoleLogin,
                                  ),
                                ],
                              );
                            }

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  const Expanded(
                                    flex: 5,
                                    child: _LoginIntroCard(stacked: false),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 4,
                                    child: _LoginAuthCard(
                                      formKey: _formKey,
                                      hasLiveBackend: hasLiveBackend,
                                      isSubmitting: _isSubmitting,
                                      isPasswordVisible: _isPasswordVisible,
                                      emailController: _emailController,
                                      passwordController: _passwordController,
                                      emailFocusNode: _emailFocusNode,
                                      passwordFocusNode: _passwordFocusNode,
                                      onPasswordVisibilityToggle: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                      onSubmit: _submitLiveLogin,
                                      onRoleLogin: _handlePreviewRoleLogin,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handlePreviewRoleLogin(UserRole role) {
    ref.read(schoolAdminProvider.notifier).loginAs(role);
    context.go('/dashboard');
  }

  Future<void> _submitLiveLogin() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

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
      ).showSnackBar(SnackBar(content: Text(_formatLoginError(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatLoginError(Object error) {
    final String normalized = error
        .toString()
        .replaceFirst(RegExp(r'^[A-Za-z]+(?:Exception|Error):\s*'), '')
        .trim();
    final String lower = normalized.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }

    if (lower.contains('email not confirmed')) {
      return 'Confirm the email address before logging in.';
    }

    if (normalized.isEmpty) {
      return 'Login failed. Please try again.';
    }

    return 'Login failed: $normalized';
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
            'School result operations are ready for a cleaner sign-in flow.',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Teachers can upload student scores, add students, and manage subject results. Academic masters can supervise reporting windows, while headmasters keep a full view of permissions, exports, and school-wide performance.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kidarafa Secondary School management system',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFFDE68A)),
          ),

          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const <Widget>[
              _InfoPill(label: 'Live email login'),
              _InfoPill(label: 'Role-based access'),
              _InfoPill(label: 'Results and analytics'),
            ],
          ),
          if (!stacked) const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _LoginAuthCard extends StatelessWidget {
  const _LoginAuthCard({
    required this.formKey,
    required this.hasLiveBackend,
    required this.isSubmitting,
    required this.isPasswordVisible,
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.onPasswordVisibilityToggle,
    required this.onSubmit,
    required this.onRoleLogin,
  });

  final GlobalKey<FormState> formKey;
  final bool hasLiveBackend;
  final bool isSubmitting;
  final bool isPasswordVisible;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onSubmit;
  final ValueChanged<UserRole> onRoleLogin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ModeBadge(hasLiveBackend: hasLiveBackend),
                const SizedBox(height: 18),
                Text(
                  hasLiveBackend ? 'Welcome back' : 'Preview login paths',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  hasLiveBackend
                      ? 'Sign in with your school email and password, then continue into the dashboard. New users can create an account from the shortcuts below.'
                      : 'Supabase is not active in this preview, so you can enter through the role shortcuts below or open the sign-up flow to test the experience.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 22),
                if (hasLiveBackend) ...<Widget>[
                  TextFormField(
                    controller: emailController,
                    focusNode: emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'name@school.edu',
                      prefixIcon: Icon(Icons.mail_rounded),
                    ),
                    validator: _validateEmail,
                    onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    focusNode: passwordFocusNode,
                    obscureText: !isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.password],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        onPressed: onPasswordVisibilityToggle,
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                    onFieldSubmitted: (_) => onSubmit(),
                    onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isSubmitting ? null : onSubmit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(
                        isSubmitting ? 'Signing in...' : 'Login to Dashboard',
                      ),
                    ),
                  ),
                ] else ...<Widget>[
                  _RoleButton(
                    title: 'Academic Master Login',
                    description:
                        'Manage exam uploads, review results, set deadlines, and oversee academic performance.',
                    icon: Icons.school_rounded,
                    tone: const Color(0xFF7C3AED),
                    onTap: () => onRoleLogin(UserRole.academicMaster),
                  ),
                  const SizedBox(height: 14),
                  _RoleButton(
                    title: 'Teacher Login',
                    description:
                        'Open the teacher workspace for score uploads, student management, and personal result permissions.',
                    icon: Icons.cast_for_education_rounded,
                    tone: const Color(0xFF155EEF),
                    onTap: () => onRoleLogin(UserRole.teacher),
                  ),
                  const SizedBox(height: 14),
                  _RoleButton(
                    title: 'Headmaster Login',
                    description:
                        'Add or remove teachers, monitor operations, and manage school-wide access.',
                    icon: Icons.admin_panel_settings_rounded,
                    tone: const Color(0xFF0F766E),
                    onTap: () => onRoleLogin(UserRole.headOfSchool),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  hasLiveBackend ? 'Create an account' : 'Explore sign-up',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  hasLiveBackend
                      ? 'Choose the role you want to create and continue into the same school workflow after registration.'
                      : 'These entry points let you test the role-specific onboarding screens before connecting the full live backend.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                _SignUpShortcut(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Teacher Sign Up',
                  onPressed: () => context.go('/signup?role=teacher'),
                ),
                const SizedBox(height: 12),
                _SignUpShortcut(
                  icon: Icons.school_rounded,
                  label: 'Academic Master Sign Up',
                  onPressed: () => context.go('/signup?role=academicmaster'),
                ),
                const SizedBox(height: 12),
                _SignUpShortcut(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Headmaster Sign Up',
                  onPressed: () => context.go('/signup?role=headmaster'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Enter your email address';
    }

    final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password';
    }
    return null;
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.hasLiveBackend});

  final bool hasLiveBackend;

  @override
  Widget build(BuildContext context) {
    final Color tone = hasLiveBackend
        ? const Color(0xFF0F766E)
        : const Color(0xFF9A3412);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            hasLiveBackend
                ? Icons.cloud_done_rounded
                : Icons.visibility_rounded,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 8),
          Text(
            hasLiveBackend ? 'Live Supabase Auth' : 'Preview Mode',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: tone),
          ),
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

class _SignUpShortcut extends StatelessWidget {
  const _SignUpShortcut({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
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
