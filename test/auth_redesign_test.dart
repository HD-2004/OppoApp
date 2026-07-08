import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/data/auth_repository.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/candidate_age_policy.dart';
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

  testWidgets('login only shows Google hosted UI sign in', (tester) async {
    await pumpAuthScreen(tester, const LoginScreen());

    final googleButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Google'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(find.text('Facebook'), findsNothing);
    expect(googleButton.onPressed, isNotNull);
  });

  testWidgets('register opens candidate form without employer role', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const RegisterScreen());

    expect(find.text('Tạo tài khoản ứng viên'), findsOneWidget);
    expect(find.text('Nhà tuyển dụng'), findsNothing);
    expect(find.text('Tạo tài khoản'), findsWidgets);
    expect(find.text('Ngày sinh'), findsOneWidget);
    expect(find.text('Tối thiểu 8 ký tự'), findsOneWidget);
    expect(find.text('Có ký tự đặc biệt'), findsOneWidget);
  });

  testWidgets('register blocks candidates under 18 before sign up', (
    tester,
  ) async {
    final spyController = _SpyAuthController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(() => spyController)],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: ThemeData(useMaterial3: true),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Nguyen An',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'candidate@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'Password1!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
      'Password1!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ngày sinh'),
      _underageDateOfBirth(),
    );
    await tester.pump();

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Tạo tài khoản'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ứng dụng chỉ dành cho ứng viên từ 18 tuổi trở lên.'),
      findsOneWidget,
    );
    expect(spyController.registerCount, 0);
  });

  testWidgets('register only shows Google hosted UI sign up', (tester) async {
    await pumpAuthScreen(tester, const RegisterScreen());

    final googleButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Google'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(find.text('Facebook'), findsNothing);
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

  testWidgets('reset password starts with OTP before new password', (
    tester,
  ) async {
    await pumpAuthScreen(
      tester,
      const ResetPasswordScreen(email: 'user@example.com'),
    );

    expect(find.text('Nhập mã\nOTP'), findsOneWidget);
    expect(find.text('Mã xác nhận OTP'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mật khẩu mới'), findsNothing);
    expect(find.text('Độ mạnh mật khẩu'), findsNothing);
  });
}

String _underageDateOfBirth() {
  final today = DateTime.now();
  final eighteenthBirthdayTomorrow = DateTime(
    today.year - CandidateAgePolicy.minimumAge,
    today.month,
    today.day + 1,
  );
  return CandidateAgePolicy.formatDisplayDate(eighteenthBirthdayTomorrow);
}

class _SpyAuthController extends AuthController {
  int registerCount = 0;
  RegisterRequest? lastRequest;

  @override
  Future<AuthState> build() async {
    return const AuthState.unauthenticated();
  }

  @override
  Future<void> register(RegisterRequest request) async {
    registerCount++;
    lastRequest = request;
  }
}
