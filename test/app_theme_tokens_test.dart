import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:oppo_temp_jobs/core/theme/app_fonts.dart';
import 'package:oppo_temp_jobs/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('app color tokens match the requested brand palette', () {
    expect(AppColors.primary, const Color(0xFF1E40AF));
    expect(AppColors.lightBackground, const Color(0xFFF8FAFC));
    expect(AppColors.lightSurface, const Color(0xFFFFFFFF));
    expect(AppColors.bgDark, const Color(0xFFF1F5F9));
    expect(AppColors.textPrimary, const Color(0xFF1E293B));
    expect(AppColors.textSecondary, const Color(0xFF64748B));
    expect(AppColors.outline, const Color(0xFFE2E8F0));
    expect(AppColors.success, const Color(0xFF10B981));
    expect(AppColors.warning, const Color(0xFFF59E0B));
    expect(AppColors.danger, const Color(0xFFEF4444));
    expect(AppColors.info, const Color(0xFF1E40AF));
  });

  test('app gradient tokens match the requested brand gradients', () {
    expect(AppGradients.primary.colors, const [
      Color(0xFF1E40AF),
      Color(0xFF1E40AF),
    ]);
    expect(AppGradients.info.colors, const [
      Color(0xFF4FACFE),
      Color(0xFF00F2FE),
    ]);
    expect(AppGradients.success.colors, const [
      Color(0xFF43E97B),
      Color(0xFF38F9D7),
    ]);
  });

  test('light and dark themes keep the Oppo brand primary color', () async {
    final lightTheme = AppTheme.lightTheme;
    final darkTheme = AppTheme.darkTheme;
    await GoogleFonts.pendingFonts();

    expect(lightTheme.colorScheme.primary, AppColors.primary);
    expect(darkTheme.colorScheme.primary, AppColors.primary);
  });

  test('dark theme exposes readable surface and text tokens', () async {
    final scheme = AppTheme.darkTheme.colorScheme;
    await GoogleFonts.pendingFonts();

    expect(scheme.surface, AppColors.darkBackground);
    expect(scheme.onSurface, AppColors.darkTextPrimary);
    expect(scheme.outline, AppColors.darkOutline);
  });

  test(
    'themes use Inter for body text and Bricolage Grotesque for headings',
    () async {
      final lightText = AppTheme.lightTheme.textTheme;
      final darkText = AppTheme.darkTheme.textTheme;
      await GoogleFonts.pendingFonts();

      expect(lightText.bodyMedium?.fontFamily, startsWith('Inter'));
      expect(darkText.bodyMedium?.fontFamily, startsWith('Inter'));
      expect(
        lightText.headlineMedium?.fontFamily,
        startsWith('BricolageGrotesque'),
      );
      expect(
        darkText.headlineMedium?.fontFamily,
        startsWith('BricolageGrotesque'),
      );
      expect(
        lightText.bodyMedium?.fontFamilyFallback,
        AppFontFamilies.bodyFallback,
      );
    },
  );

  test('theme extension exposes decorative display font families', () async {
    final fonts = AppTheme.lightTheme.extension<AppFontFamilies>();
    await GoogleFonts.pendingFonts();

    expect(fonts, isNotNull);
    expect(fonts?.body, AppFontFamilies.interFamily);
    expect(fonts?.heading, AppFontFamilies.bricolageGrotesqueFamily);
    expect(fonts?.decorative, AppFontFamilies.pacificoFamily);
    expect(fonts?.roundedDisplay, AppFontFamilies.chironGoRoundTcFamily);
    expect(fonts?.playfulDisplay, AppFontFamilies.grandstanderFamily);
  });
}
