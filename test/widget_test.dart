import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/app/app.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('introduction uses bundled logo asset only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: IntroductionScreen())),
    );

    expect(
      find.image(const AssetImage('img/oppo-logo-color.png')),
      findsOneWidget,
    );
    expect(find.image(const AssetImage('img/intro.png')), findsNothing);
    expect(find.text('Bắt đầu hành trình sự nghiệp F&B của bạn'), findsNothing);
    expect(find.text('Tìm việc linh hoạt, thu nhập tức thì'), findsNothing);
  });

  testWidgets('shows introduction when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    expect(
      find.image(const AssetImage('img/oppo-logo-color.png')),
      findsOneWidget,
    );
    expect(find.text('Bắt đầu ngay'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Tìm việc linh hoạt, thu nhập tức thì'), findsNothing);
  });

  testWidgets('opens login from introduction', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(
      find.textContaining('Đăng ký ngay', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('opens forgot password screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Quên mật khẩu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quên mật khẩu'));
    await tester.pumpAndSettle();

    expect(find.text('Khôi phục\nmật khẩu'), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
  });

  testWidgets('opens candidate register screen from login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.textContaining('Đăng ký ngay', findRichText: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Đăng ký ngay', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản ứng viên'), findsOneWidget);
    expect(find.text('Nhà tuyển dụng'), findsNothing);
    expect(find.text('Tạo tài khoản'), findsWidgets);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);

    await tester.ensureVisible(
      find.textContaining('Đã có tài khoản?', findRichText: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.textContaining('Đã có tài khoản?', findRichText: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Quên mật khẩu'), findsOneWidget);
  });

  testWidgets('auth input text uses high-contrast auth color', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();

    final loginFields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(loginFields.length, 2);
    for (final field in loginFields) {
      expect(field.style.color, const Color(0xFF1E293B));
    }

    await tester.ensureVisible(
      find.textContaining('Đăng ký ngay', findRichText: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Đăng ký ngay', findRichText: true));
    await tester.pumpAndSettle();

    final registerFields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(registerFields.length, 5);
    for (final field in registerFields) {
      expect(field.style.color, const Color(0xFF1E293B));
    }
  });
}
