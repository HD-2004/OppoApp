import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/reset_password_screen.dart';

Widget buildResetPasswordApp() {
  final router = GoRouter(
    initialLocation: '/reset-password?email=user@example.com',
    routes: [
      GoRoute(
        path: '/reset-password',
        builder: (_, state) {
          return ResetPasswordScreen(email: state.uri.queryParameters['email']);
        },
      ),
      GoRoute(
        path: '/reset-password/new-password',
        builder: (_, state) {
          final session = state.extra as ResetPasswordSession?;
          return ResetPasswordNewPasswordScreen(session: session);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const Scaffold(body: Text('Forgot password')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('Login')),
      ),
    ],
  );

  return ProviderScope(
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
  testWidgets('reset password first step only asks for OTP', (tester) async {
    await tester.pumpWidget(buildResetPasswordApp());
    await tester.pumpAndSettle();

    expect(find.text('Mã xác nhận OTP'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mật khẩu mới'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu mới'),
      findsNothing,
    );
    expect(find.text('Tiếp tục'), findsOneWidget);
  });

  testWidgets('entering OTP opens the new password page', (tester) async {
    await tester.pumpWidget(buildResetPasswordApp());
    await tester.pumpAndSettle();

    final otpFields = find.byType(TextField);
    for (var index = 0; index < 6; index++) {
      await tester.enterText(otpFields.at(index), '${index + 1}');
    }
    await tester.pump();
    await tester.ensureVisible(find.text('Tiếp tục'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo mật khẩu\nmới'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mật khẩu mới'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu mới'),
      findsOneWidget,
    );
    expect(find.text('Độ mạnh mật khẩu'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsWidgets);
  });
}
