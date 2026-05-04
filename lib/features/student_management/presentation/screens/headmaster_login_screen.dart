import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/student_management_providers.dart';

/// Headmaster Login Screen - Specialized login for school administrators
class HeadmasterLoginScreen extends ConsumerStatefulWidget {
  const HeadmasterLoginScreen({super.key});

  @override
  ConsumerState<HeadmasterLoginScreen> createState() =>
      _HeadmasterLoginScreenState();
}

class _HeadmasterLoginScreenState extends ConsumerState<HeadmasterLoginScreen> {
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
    final session = ref.watch(schoolAdminProvider).session;

    if (session == null) {
      _hasScheduledRedirect = false;
    }

    // Auto-redirect if already logged in
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
                                  const _HeadmasterIntroCard(stacked: true),
                                  const SizedBox(height: 18),
                                  _HeadmasterAuthCard(
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
                                    onSubmit: _submitHeadmasterLogin,
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
                                    child: _HeadmasterIntroCard(stacked: false),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 4,
                                    child: _HeadmasterAuthCard(
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
                                      onSubmit: _submitHeadmasterLogin,
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

  Future<void> _submitHeadmasterLogin() async {
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

    if (lower.contains('not authorized') ||
        lower.contains('not a headmaster')) {
      return 'Only headmasters can access this portal. Please use the teacher login.';
    }

    if (normalized.isEmpty) {
      return 'Login failed. Please try again.';
    }

    return 'Login failed: $normalized';
  }
}

class _HeadmasterIntroCard extends StatelessWidget {
  const _HeadmasterIntroCard({required this.stacked});

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
            child: const Icon(
              Icons.security_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Headmaster Administration Portal',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'As the school administrator, you have complete control over user accounts, permissions, and system-wide settings. Manage teachers, review results, and oversee all school operations from here.',
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
              _InfoPill(label: 'Admin access'),
              _InfoPill(label: 'User management'),
              _InfoPill(label: 'Full system control'),
            ],
          ),
          if (!stacked) const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _HeadmasterAuthCard extends StatelessWidget {
  const _HeadmasterAuthCard({
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
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Headmaster Login',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your credentials to access the administration panel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: emailController,
                  focusNode: emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'headmaster@school.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (String? value) {
                    if (value?.isEmpty ?? true) {
                      return 'Email is required';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    emailFocusNode.unfocus();
                    passwordFocusNode.requestFocus();
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  focusNode: passwordFocusNode,
                  obscureText: !isPasswordVisible,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: onPasswordVisibilityToggle,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (String? value) {
                    if (value?.isEmpty ?? true) {
                      return 'Password is required';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    passwordFocusNode.unfocus();
                    if (!isSubmitting) {
                      onSubmit();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF155EEF),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Sign In'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => context.go('/role-selection'),
              child: const Text('Back to Role Selection'),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
