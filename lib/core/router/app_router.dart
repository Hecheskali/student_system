import 'package:go_router/go_router.dart';

import '../../features/student_management/presentation/screens/analytics_screen.dart';
import '../../features/student_management/presentation/screens/all_results_screen.dart';
import '../../features/student_management/presentation/screens/dashboard_screen.dart';
import '../../features/student_management/presentation/screens/headmaster_login_screen.dart';
import '../../features/student_management/presentation/screens/hierarchy_explorer_screen.dart';
import '../../features/student_management/presentation/screens/login_screen.dart';
import '../../features/student_management/presentation/screens/management_screen.dart';
import '../../features/student_management/presentation/screens/profiles_screen.dart';
import '../../features/student_management/presentation/screens/records_screen.dart';
import '../../features/student_management/presentation/screens/result_detail_screen.dart';
import '../../features/student_management/presentation/screens/result_entry_screen.dart';
import '../../features/student_management/presentation/screens/results_screen.dart';
import '../../features/student_management/presentation/screens/role_selection_screen.dart';
import '../../features/student_management/presentation/screens/search_screen.dart';
import '../../features/student_management/presentation/screens/settings_screen.dart';
import '../../features/student_management/presentation/screens/splash_screen.dart';
import '../../features/student_management/presentation/screens/student_detail_screen.dart';
import '../../features/student_management/presentation/screens/student_intake_screen.dart';
import '../../features/student_management/presentation/screens/teacher_login_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/headmaster-login',
        builder: (context, state) => const HeadmasterLoginScreen(),
      ),
      GoRoute(
        path: '/teacher-login',
        builder: (context, state) => const TeacherLoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) =>
            DashboardScreen(initialPanel: state.uri.queryParameters['panel']),
      ),
      GoRoute(
        path: '/student-intake',
        builder: (context, state) => StudentIntakeScreen(
          initialClass: state.uri.queryParameters['class'],
        ),
      ),
      GoRoute(
        path: '/manage',
        builder: (context, state) => ManagementScreen(
          initialTab: state.uri.queryParameters['tab'] ?? 'upload',
        ),
      ),
      GoRoute(
        path: '/results',
        builder: (context, state) =>
            ResultsScreen(initialClass: state.uri.queryParameters['class']),
      ),
      GoRoute(
        path: '/all-results',
        builder: (context, state) =>
            AllResultsScreen(initialForm: state.uri.queryParameters['form']),
      ),
      GoRoute(
        path: '/result-entry',
        builder: (context, state) =>
            ResultEntryScreen(initialClass: state.uri.queryParameters['class']),
      ),
      GoRoute(
        path: '/records',
        builder: (context, state) => const RecordsScreen(),
      ),
      GoRoute(
        path: '/results/:studentId',
        builder: (context, state) => ResultDetailScreen(
          studentId: state.pathParameters['studentId']!,
          sourceClass: state.uri.queryParameters['class'],
        ),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            SearchScreen(query: state.uri.queryParameters['query'] ?? ''),
      ),
      GoRoute(
        path: '/profiles',
        builder: (context, state) => const ProfilesScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/explorer',
        builder: (context, state) => HierarchyExplorerScreen(
          districtId: state.uri.queryParameters['districtId'],
          schoolId: state.uri.queryParameters['schoolId'],
          classId: state.uri.queryParameters['classId'],
          studentId: state.uri.queryParameters['studentId'],
        ),
      ),
      GoRoute(
        path: '/student/:studentId',
        builder: (context, state) =>
            StudentDetailScreen(studentId: state.pathParameters['studentId']!),
      ),
    ],
  );
}
