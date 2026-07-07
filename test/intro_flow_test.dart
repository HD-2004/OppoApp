import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image;
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/login_screen.dart';
import 'package:oppo_temp_jobs/features/intro/presentation/intro_screen.dart';
import 'package:oppo_temp_jobs/features/intro/presentation/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const logoAsset = 'img/oppo-logo-color.png';
  const splashVisibleDuration = Duration(milliseconds: 2500);

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

  Future<void> pumpPastSplash(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(
      splashVisibleDuration + const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('splash opens login automatically when intro has not been seen', (
    WidgetTester tester,
  ) async {
    await pumpIntroFlow(tester, hasSeenIntro: false);
    await pumpPastSplash(tester);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('has_seen_intro'), isTrue);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Bắt đầu ngay'), findsNothing);
  });

  testWidgets('splash uses bundled logo asset while routing', (
    WidgetTester tester,
  ) async {
    await pumpIntroFlow(tester, hasSeenIntro: false);
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      find.image(const AssetImage('img/oppo-logo-color.png')),
      findsOneWidget,
    );

    await tester.pump(
      splashVisibleDuration + const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('splash keeps logo visible for a few seconds before login', (
    WidgetTester tester,
  ) async {
    await pumpIntroFlow(tester, hasSeenIntro: false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      find.image(const AssetImage('img/oppo-logo-color.png')),
      findsOneWidget,
    );
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('bundled logo asset loads non-empty bytes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return FutureBuilder<int>(
              future: DefaultAssetBundle.of(
                context,
              ).load(logoAsset).then((data) => data.lengthInBytes),
              builder: (context, snapshot) {
                return Text('${snapshot.data ?? 0}');
              },
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    final logoBytes = int.parse(tester.widget<Text>(find.byType(Text)).data!);
    expect(logoBytes, greaterThan(0));
  });

  testWidgets('bundled logo asset decodes as transparent logo artwork', (
    WidgetTester tester,
  ) async {
    final bytes = await rootBundle.load(logoAsset);
    final decodedLogo = image.decodePng(bytes.buffer.asUint8List());

    expect(decodedLogo, isNotNull);
    expect(decodedLogo!.width, 2000);
    expect(decodedLogo.height, 2000);
    expect(decodedLogo.getPixel(1000, 1700).a, 0);
  });

  testWidgets('splash opens login when intro has already been seen', (
    WidgetTester tester,
  ) async {
    await pumpIntroFlow(tester, hasSeenIntro: true);
    await pumpPastSplash(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('intro screen is logo-only without entry buttons', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: IntroScreen())),
    );

    expect(find.byType(IntroScreen), findsOneWidget);
    expect(
      find.image(const AssetImage('img/oppo-logo-color.png')),
      findsOneWidget,
    );
    expect(find.text('Bắt đầu ngay'), findsNothing);
    expect(find.text('Đăng nhập'), findsNothing);
  });
}
