import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/app/app.dart';

void main() {
  testWidgets('shows login when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    expect(find.text('Ốp Pờ'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
  });

  testWidgets('opens forgot password screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quên mật khẩu'));
    await tester.pumpAndSettle();

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
  });
}
