import 'package:flutter_test/flutter_test.dart';

import 'package:student_system/main.dart';

void main() {
  testWidgets('splash screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentSystemApp());

    expect(find.text('Student Command Center'), findsOneWidget);
    expect(
      find.text(
        'District-to-student analytics built for drill-down decisions.',
      ),
      findsOneWidget,
    );
  });
}
