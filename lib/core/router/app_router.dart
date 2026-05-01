import 'package:go_router/go_router.dart';

import '../../features/student_management/domain/entities/education_entities.dart';
import '../../features/student_management/presentation/screens/analytics_screen.dart';
import '../../features/student_management/presentation/screens/all_results_screen.dart';
import '../../features/student_management/presentation/screens/dashboard_screen.dart';
import '../../features/student_management/presentation/screens/hierarchy_explorer_screen.dart';
import '../../features/student_management/presentation/screens/login_screen.dart';
import '../../features/student_management/presentation/screens/profiles_screen.dart';
import '../../features/student_management/presentation/screens/records_screen.dart';
import '../../features/student_management/presentation/screens/result_detail_screen.dart';
import '../../features/student_management/presentation/screens/result_entry_professional_screen.dart';
import '../../features/student_management/presentation/screens/result_entry_screen.dart';
import '../../features/student_management/presentation/screens/results_screen.dart';
import '../../features/student_management/presentation/screens/search_screen.dart';
import '../../features/student_management/presentation/screens/settings_screen.dart';
import '../../features/student_management/presentation/screens/signup_screen.dart';
import '../../features/student_management/presentation/screens/splash_screen.dart';
import '../../features/student_management/presentation/screens/student_detail_screen.dart';
import '../../features/student_management/presentation/screens/student_intake_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) {
          final String role = state.uri.queryParameters['role'] ?? 'teacher';
          return SignUpScreen(
            initialRole: role == 'headmaster'
                ? UserRole.headOfSchool
                : role == 'academicmaster'
                ? UserRole.academicMaster
                : UserRole.teacher,
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/student-intake',
        builder: (context, state) => StudentIntakeScreen(
          initialClass: state.uri.queryParameters['class'],
        ),
      ),
      GoRoute(
        path: '/manage',
        builder: (context, state) => ResultEntryProfessionalScreen(
          initialClass: state.uri.queryParameters['class'],
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
