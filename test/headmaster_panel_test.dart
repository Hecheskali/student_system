import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:student_system/core/theme/theme_mode_provider.dart';
import 'package:student_system/features/student_management/domain/entities/education_entities.dart';
import 'package:student_system/features/student_management/presentation/providers/headmaster_panel_provider.dart';
import 'package:student_system/features/student_management/presentation/providers/student_management_providers.dart';
import 'package:student_system/features/student_management/presentation/screens/dashboard_screen.dart';
import 'package:student_system/features/student_management/presentation/utils/report_exporter.dart';

void main() {
  test('female students are ordered A-Z before male students A-Z', () {
    final List<StudentResultRecord> records = <StudentResultRecord>[
      _record('ZACHARY BETA', StudentGender.male, 'S6822/-004'),
      _record('AMINA ALPHA', StudentGender.female, 'S6822/-002'),
      _record('BRIAN ALPHA', StudentGender.male, 'S6822/-003'),
      _record('BETTY ALPHA', StudentGender.female, 'S6822/-001'),
    ]..sort(compareStudentResultsForRoster);

    expect(
      records.map((StudentResultRecord record) => record.studentName),
      <String>['AMINA ALPHA', 'BETTY ALPHA', 'BRIAN ALPHA', 'ZACHARY BETA'],
    );
  });

  test(
    'student deactivation hides records from active headmaster counts',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SchoolAdminController controller = container.read(
        schoolAdminProvider.notifier,
      );
      controller.loginAs(UserRole.headOfSchool);
      await controller.addStudent(
        studentName: 'AMINA ALPHA',
        className: 'Form 1 A',
        gender: StudentGender.female,
      );
      await controller.addStudent(
        studentName: 'BRIAN ALPHA',
        className: 'Form 1 A',
        gender: StudentGender.male,
      );

      expect(container.read(headmasterOverviewProvider).totalStudents, 2);

      final String studentId = container
          .read(schoolAdminProvider)
          .studentResults
          .first
          .id;
      controller.deactivateStudent(studentId);

      expect(container.read(headmasterOverviewProvider).totalStudents, 1);
      expect(container.read(schoolAdminProvider).studentResults.length, 2);
    },
  );

  test('headmaster report export formats include pdf excel and csv', () {
    expect(
      ReportFileFormat.values.map((ReportFileFormat format) => format.label),
      containsAll(<String>['PDF', 'Excel', 'CSV']),
    );
  });

  test('theme mode provider switches dark and light modes', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.light);
    container.read(themeModeProvider.notifier).state = ThemeMode.dark;
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('headmaster sees panel and academic master keeps old dashboard', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final ProviderContainer headmasterContainer = ProviderContainer();
    addTearDown(headmasterContainer.dispose);
    headmasterContainer
        .read(schoolAdminProvider.notifier)
        .loginAs(UserRole.headOfSchool);

    await _pumpDashboard(tester, headmasterContainer);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text('Fees Collected'), findsOneWidget);

    final ProviderContainer academicContainer = ProviderContainer();
    addTearDown(academicContainer.dispose);
    academicContainer
        .read(schoolAdminProvider.notifier)
        .loginAs(UserRole.academicMaster);

    await _pumpDashboard(tester, academicContainer);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Overview'), findsNothing);
    expect(find.text('Teacher Dashboard'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final GoRouter router = GoRouter(
    initialLocation: '/dashboard',
    routes: <RouteBase>[
      GoRoute(
        path: '/dashboard',
        builder: (BuildContext context, GoRouterState state) {
          return DashboardScreen(
            initialPanel: state.uri.queryParameters['panel'],
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Login'));
        },
      ),
      GoRoute(
        path: '/manage',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Manage'));
        },
      ),
      GoRoute(
        path: '/records',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Records'));
        },
      ),
      GoRoute(
        path: '/profiles',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Profiles'));
        },
      ),
      GoRoute(
        path: '/results',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Results'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

StudentResultRecord _record(
  String name,
  StudentGender gender,
  String admissionNumber,
) {
  return StudentResultRecord(
    id: admissionNumber,
    admissionNumber: admissionNumber,
    studentName: name,
    className: 'Form 1 A',
    gender: gender,
    averageScore: 0,
    interExamAverage: 0,
    division: 'Division 0',
    divisionPoints: 0,
    attendanceRate: 90,
    subjectResults: const <SubjectResult>[],
    performanceTrend: const <ScorePoint>[
      ScorePoint(label: 'Term 1', value: 0),
      ScorePoint(label: 'Inter', value: 0),
      ScorePoint(label: 'Term 2', value: 0),
      ScorePoint(label: 'Current', value: 0),
    ],
    riskLevel: RiskLevel.stable,
  );
}
