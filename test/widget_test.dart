import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/app/app.dart';

void main() {
  testWidgets('shows urgent shift entry points', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));

    expect(find.text('Oppo Temp Jobs'), findsOneWidget);
    expect(find.text('Worker marketplace'), findsOneWidget);
    expect(find.text('Employer dashboard'), findsOneWidget);
  });
}
