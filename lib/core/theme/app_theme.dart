import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const seed = AppColors.primary;

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          tertiary: AppColors.accent,
          surface: AppColors.lightSurface,
          onSurface: AppColors.textPrimary,
          outline: AppColors.outline,
          outlineVariant: AppColors.outline,
          error: AppColors.danger,
        );
    final textTheme = _textTheme(
      brightness: Brightness.light,
      textColor: AppColors.textPrimary,
      secondaryTextColor: AppColors.textSecondary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: AppFontFamilies.inter,
      fontFamilyFallback: AppFontFamilies.bodyFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[AppFontFamilies.defaults],
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _headingStyle(
          textTheme.titleLarge,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.inter(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ).copyWith(fontFamilyFallback: AppFontFamilies.bodyFallback);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          tertiary: AppColors.accent,
          surface: AppColors.darkBackground,
          onSurface: AppColors.darkTextPrimary,
          outline: AppColors.darkOutline,
          outlineVariant: AppColors.darkOutline,
          error: AppColors.danger,
        );
    final textTheme = _textTheme(
      brightness: Brightness.dark,
      textColor: AppColors.darkTextPrimary,
      secondaryTextColor: AppColors.darkTextSecondary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: AppFontFamilies.inter,
      fontFamilyFallback: AppFontFamilies.bodyFallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[AppFontFamilies.defaults],
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _headingStyle(
          textTheme.titleLarge,
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.darkOutline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkTextSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppColors.primary.withValues(alpha: 0.22),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.darkTextSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.inter(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.darkTextSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ).copyWith(fontFamilyFallback: AppFontFamilies.bodyFallback);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0xFF0F1A2D),
        filled: true,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static TextTheme _textTheme({
    required Brightness brightness,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final typography = Typography.material2021(
      platform: TargetPlatform.android,
    );
    final baseTheme = brightness == Brightness.dark
        ? typography.white
        : typography.black;
    final interTheme = GoogleFonts.interTextTheme(
      baseTheme,
    ).apply(bodyColor: textColor, displayColor: textColor);

    return interTheme.copyWith(
      displayLarge: _headingStyle(
        interTheme.displayLarge,
        color: textColor,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: _headingStyle(
        interTheme.displayMedium,
        color: textColor,
        fontWeight: FontWeight.w800,
      ),
      displaySmall: _headingStyle(
        interTheme.displaySmall,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: _headingStyle(
        interTheme.headlineLarge,
        color: textColor,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: _headingStyle(
        interTheme.headlineMedium,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: _headingStyle(
        interTheme.headlineSmall,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: _headingStyle(
        interTheme.titleLarge,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: _headingStyle(
        interTheme.titleMedium,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: _headingStyle(
        interTheme.titleSmall,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: _bodyStyle(interTheme.bodyLarge, color: textColor),
      bodyMedium: _bodyStyle(interTheme.bodyMedium, color: textColor),
      bodySmall: _bodyStyle(interTheme.bodySmall, color: secondaryTextColor),
      labelLarge: _bodyStyle(
        interTheme.labelLarge,
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: _bodyStyle(
        interTheme.labelMedium,
        color: secondaryTextColor,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: _bodyStyle(
        interTheme.labelSmall,
        color: secondaryTextColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static TextStyle _headingStyle(
    TextStyle? base, {
    required Color color,
    FontWeight? fontWeight,
  }) {
    return GoogleFonts.getFont(
      'Bricolage Grotesque',
      textStyle: base,
      color: color,
      fontWeight: fontWeight ?? base?.fontWeight,
    ).copyWith(fontFamilyFallback: AppFontFamilies.bodyFallback);
  }

  static TextStyle _bodyStyle(
    TextStyle? base, {
    required Color color,
    FontWeight? fontWeight,
  }) {
    return GoogleFonts.inter(
      textStyle: base,
      color: color,
      fontWeight: fontWeight ?? base?.fontWeight,
    ).copyWith(fontFamilyFallback: AppFontFamilies.bodyFallback);
  }
}
