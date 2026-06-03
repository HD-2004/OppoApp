import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/app/app.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/introduction_screen.dart';

void main() {
  testWidgets('introduction uses bundled F&B image asset', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: IntroductionScreen())),
    );

    expect(find.image(const AssetImage('img/intro.png')), findsOneWidget);
  });

  testWidgets('shows introduction when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    expect(find.text('Ốp Pờ'), findsOneWidget);
    expect(
      find.text('Bắt đầu hành trình sự nghiệp F&B của bạn'),
      findsOneWidget,
    );
    expect(find.text('Tìm việc linh hoạt, thu nhập tức thì'), findsOneWidget);
    expect(find.text('Bắt đầu ngay'), findsOneWidget);
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
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
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

    expect(find.text('Quên mật khẩu'), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
  });

  testWidgets('opens candidate-only register screen from login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TempJobsApp()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký'), findsWidgets);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Nhà tuyển dụng'), findsNothing);
    expect(find.text('Vai trò'), findsNothing);
  });

  testWidgets('auth input text is black on login and register', (
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
      expect(field.style.color, Colors.black);
    }

    await tester.ensureVisible(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();

    final registerFields = tester.widgetList<EditableText>(
      find.byType(EditableText),
    );
    expect(registerFields.length, 4);
    for (final field in registerFields) {
      expect(field.style.color, Colors.black);
    }
  });
}
