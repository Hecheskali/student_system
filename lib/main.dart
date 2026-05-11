import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_navigation_history.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize(
    url: 'https://mnvspcycpbanqdrxrkgy.supabase.co',
    anonKey: 'sb_publishable_VpBQlmnFXh66ExZPtWJOhA_bZbHGh-E',
  );
  runApp(const ProviderScope(child: StudentSystemApp()));
}

class StudentSystemApp extends ConsumerStatefulWidget {
  const StudentSystemApp({super.key});

  @override
  ConsumerState<StudentSystemApp> createState() => _StudentSystemAppState();
}

class _StudentSystemAppState extends ConsumerState<StudentSystemApp> {
  @override
  void initState() {
    super.initState();
    AppRouter.router.routerDelegate.addListener(_recordRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordRoute());
  }

  @override
  void dispose() {
    AppRouter.router.routerDelegate.removeListener(_recordRoute);
    super.dispose();
  }

  void _recordRoute() {
    final String location = AppRouter.router.routeInformationProvider.value.uri
        .toString();
    AppNavigationHistory.instance.record(location);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Student Command Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}
