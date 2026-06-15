import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/data/password_reset_api.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/forgot_password_screen.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/reset_password_screen.dart';

class FakePasswordResetApi extends PasswordResetApi {
  String? requestedEmail;

  @override
  Future<void> requestOtp({required String email}) async {
    requestedEmail = email;
  }

  @override
  Future<String> verifyOtp({required String email, required String otp}) async {
    return 'verified-token';
  }

  @override
  Future<void> confirmResetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {}
}

Widget buildApp() {
  final api = FakePasswordResetApi();
  final router = GoRouter(
    initialLocation: '/reset-password',
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordScreen(email: 'user@example.com'),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [passwordResetApiProvider.overrideWithValue(api)],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Widget buildForgotPasswordApp(FakePasswordResetApi api) {
  final router = GoRouter(
    initialLocation: '/forgot-password',
    routes: [
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => Scaffold(
          body: Text('OTP for ${state.uri.queryParameters['email']}'),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [passwordResetApiProvider.overrideWithValue(api)],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('forgot password navigates to otp screen after sending code', (
    tester,
  ) async {
    final api = FakePasswordResetApi();
    await tester.pumpWidget(buildForgotPasswordApp(api));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'hoanghieu20824@gmail.com',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Gửi mã xác nhận'));
    await tester.tap(find.text('Gửi mã xác nhận'));
    await tester.pumpAndSettle();

    expect(api.requestedEmail, 'hoanghieu20824@gmail.com');
    expect(find.text('OTP for hoanghieu20824@gmail.com'), findsOneWidget);
  });

  testWidgets('initial reset screen shows otp step without password fields', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Mã xác nhận OTP'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mật khẩu mới'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu mới'),
      findsNothing,
    );
    expect(find.text('Xác thực OTP'), findsOneWidget);
  });

  testWidgets('successful otp verification opens new password step', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final otpFields = find.byType(TextField);
    for (var index = 0; index < 6; index++) {
      await tester.enterText(otpFields.at(index), '${index + 1}');
    }
    await tester.pump();
    await tester.ensureVisible(find.text('Xác thực OTP'));
    await tester.tap(find.text('Xác thực OTP'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Mật khẩu mới'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu mới'),
      findsOneWidget,
    );
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
  });
}
