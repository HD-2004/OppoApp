import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/core/theme/app_theme.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/change_password_screen.dart';

void main() {
  testWidgets('change password rejects reusing the current password', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.lightTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const ChangePasswordScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const reusedPassword = 'OldPass1!';
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu hiện tại'),
      reusedPassword,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu mới'),
      reusedPassword,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu mới'),
      reusedPassword,
    );
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, 'Đổi mật khẩu');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Mật khẩu mới không được trùng mật khẩu hiện tại.'),
      findsOneWidget,
    );
  });
}
