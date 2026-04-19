import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_navigation_history.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize(
    url: 'https://mnvspcycpbanqdrxrkgy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1udnNwY3ljcGJhbnFkcnhya2d5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1MTM2NzcsImV4cCI6MjA5MjA4OTY3N30.wH1WZ6fLtvFNWhcQZRFCpx3IRYT2QaA0-G6MEKdYf6U',
  );
  runApp(const ProviderScope(child: StudentSystemApp()));
}

class StudentSystemApp extends StatefulWidget {
  const StudentSystemApp({super.key});

  @override
  State<StudentSystemApp> createState() => _StudentSystemAppState();
}

class _StudentSystemAppState extends State<StudentSystemApp> {
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
    return MaterialApp.router(
      title: 'Student Command Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
    );
  }
}
