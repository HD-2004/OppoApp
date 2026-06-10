import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AuthColors {
  const AuthColors._();

  static const primary = AppColors.primary;
  static const secondary = AppColors.secondary;
  static const accent = AppColors.accent;
  static const cta = AppColors.primary;
  static const ctaDark = AppColors.secondary;
  static const lightBackground = AppColors.lightBackground;
  static const darkBackground = AppColors.darkBackground;
  static const lightSurface = AppColors.lightSurface;
  static const darkSurface = AppColors.darkSurface;
  static const lightTextPrimary = AppColors.textPrimary;
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const lightTextSecondary = AppColors.textSecondary;
  static const darkTextSecondary = Color(0xFFB9C7DD);
  static const success = AppColors.success;
  static const warning = AppColors.warning;
  static const danger = AppColors.danger;

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color background(BuildContext context) {
    return isDark(context) ? darkBackground : lightBackground;
  }

  static Color surface(BuildContext context) {
    return isDark(context) ? darkSurface : lightSurface;
  }

  static Color textPrimary(BuildContext context) {
    return isDark(context) ? darkTextPrimary : lightTextPrimary;
  }

  static Color textSecondary(BuildContext context) {
    return isDark(context) ? darkTextSecondary : lightTextSecondary;
  }

  static Color fieldFill(BuildContext context) {
    return isDark(context) ? const Color(0xFF15243B) : const Color(0xFFF9FCFF);
  }

  static Color outline(BuildContext context) {
    return isDark(context) ? const Color(0xFF29405F) : AppColors.outline;
  }

  static Color primaryButton(BuildContext context) {
    return isDark(context) ? ctaDark : cta;
  }

  static Color softTint(BuildContext context) {
    return isDark(context) ? const Color(0xFF0D1B31) : AppColors.primarySoft;
  }
}
