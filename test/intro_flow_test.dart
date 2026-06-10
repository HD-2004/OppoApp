import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/login_screen.dart';
import 'package:oppo_temp_jobs/features/intro/presentation/intro_screen.dart';
import 'package:oppo_temp_jobs/features/intro/presentation/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpIntroFlow(
    WidgetTester tester, {
    required bool hasSeenIntro,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (hasSeenIntro) 'has_seen_intro': true,
    });

    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/intro',
          builder: (context, state) => const IntroScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }

  testWidgets('splash opens intro when intro has not been seen', (
    WidgetTester tester,
  ) async {
    await pumpIntroFlow(tester, hasSeenIntro: false);
    await tester.pumpAndSettle();

    expect(find.byType(IntroScreen), findsOneWidget);
    expect(find.text('Tìm việc linh hoạt, thu nhập tức thì'), findsOneWidget);
  });

  testWidgets('splash opens login when intro has already been seen', (
    WidgetTester tester,
  ) async {
    await pumpIntroFlow(tester, hasSeenIntro: true);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('intro primary button marks intro as seen and replaces login', (
    WidgetTester tester,
  ) async {
    await pumpIntroFlow(tester, hasSeenIntro: false);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Bắt đầu ngay'));
    await tester.tap(find.text('Bắt đầu ngay'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('has_seen_intro'), isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
