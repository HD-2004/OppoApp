import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/confirm_signup_screen.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/forgot_password_screen.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/login_screen.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/register_screen.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/reset_password_screen.dart';

void main() {
  Future<void> pumpAuthScreen(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('login presents the fast F&B value proposition and CTA', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const LoginScreen());

    expect(find.textContaining('Tìm việc nhanh'), findsOneWidget);
    expect(find.textContaining('Chủ động ca làm'), findsOneWidget);
    expect(find.textContaining('Nhận lương liền'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(
      find.textContaining('Đăng ký ngay', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('login social buttons are enabled for hosted UI sign in', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const LoginScreen());

    final facebookButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Facebook'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final googleButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Google'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(facebookButton.onPressed, isNotNull);
    expect(googleButton.onPressed, isNotNull);
  });

  testWidgets('register opens candidate form without employer role', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const RegisterScreen());

    expect(find.text('Tạo tài khoản ứng viên'), findsOneWidget);
    expect(find.text('Nhà tuyển dụng'), findsNothing);
    expect(find.text('Tạo tài khoản'), findsWidgets);
    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
    expect(find.text('Có ký tự đặc biệt'), findsOneWidget);
  });

  testWidgets('register social buttons are enabled for hosted UI sign up', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const RegisterScreen());

    final facebookButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Facebook'),
        matching: find.byType(OutlinedButton),
      ),
    );
    final googleButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Google'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(facebookButton.onPressed, isNotNull);
    expect(googleButton.onPressed, isNotNull);
  });

  testWidgets('forgot password focuses on OTP recovery action', (tester) async {
    await pumpAuthScreen(tester, const ForgotPasswordScreen());

    expect(find.text('Khôi phục\nmật khẩu'), findsOneWidget);
    expect(find.text('Gửi mã xác nhận'), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
  });

  testWidgets('confirm signup uses six-box OTP verification UI', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      const ConfirmSignUpScreen(email: 'user@example.com'),
    );

    expect(find.text('Nhập mã xác nhận'), findsOneWidget);
    expect(find.text('Xác nhận'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);
  });

  testWidgets('reset password shows strength guidance for the new password', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      const ResetPasswordScreen(email: 'user@example.com'),
    );

    expect(find.text('Tạo mật khẩu\nmới'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsWidgets);
    expect(find.text('Độ mạnh mật khẩu'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsWidgets);
  });
}
