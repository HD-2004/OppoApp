import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/app_language_controller.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_theme_controller.dart';
import 'router.dart';

class TempJobsApp extends ConsumerWidget {
  const TempJobsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeModeAsync = ref.watch(appThemeControllerProvider);
    final locale =
        ref.watch(appLanguageControllerProvider).asData?.value ??
        const Locale('vi');

    final themeMode = themeModeAsync.asData?.value;
    if (themeMode == null) {
      return const SizedBox.shrink();
    }

    return MaterialApp.router(
      title: 'Ốp Pờ',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
