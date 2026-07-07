import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF1E40AF);
  static const secondary = Color(0xFF4FACFE);
  static const accent = Color(0xFF00F2FE);
  static const info = primary;

  static const primaryLight = secondary;
  static const primaryDark = Color(0xFF1E40AF);
  static const backgroundSoft = lightBackground;
  static const border = outline;
  static const textOnPrimary = Colors.white;

  static const primarySoft = Color(0xFFEFF6FF);
  static const secondarySoft = Color(0xFFE0F2FE);
  static const accentSoft = Color(0xFFE6FFFB);

  static const lightBackground = Color(0xFFF8FAFC);
  static const bgLight = lightSurface;
  static const bgDark = Color(0xFFF1F5F9);
  static const darkBackground = Color(0xFF07101E);
  static const lightSurface = Colors.white;
  static const darkSurface = Color(0xFF101C31);
  static const darkCardBackground = Color(0xFF13213A);

  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const text = textPrimary;
  static const textLight = textSecondary;
  static const textMuted = textSecondary;
  static const textDisabled = Color(0xFF94A3B8);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFF94A3B8);

  static const outline = Color(0xFFE2E8F0);
  static const outlineStrong = Color(0xFFCBD5E1);
  static const darkOutline = Color(0xFF29405F);
  static const darkOutlineStrong = Color(0xFF3C587C);
  static const disabled = Color(0xFF94A3B8);
  static const darkDisabled = Color(0xFF64748B);
  static const iconColor = textSecondary;
  static const darkIconColor = darkTextSecondary;

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const error = danger;

  static LinearGradient brandGradient({
    AlignmentGeometry begin = Alignment.centerLeft,
    AlignmentGeometry end = Alignment.centerRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [primary, primary],
    );
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color background(BuildContext context) {
    return isDark(context) ? darkBackground : lightBackground;
  }

  static Color surface(BuildContext context) {
    return isDark(context) ? darkSurface : lightSurface;
  }

  static Color cardBackground(BuildContext context) {
    return isDark(context) ? darkCardBackground : lightSurface;
  }

  static Color textPrimaryFor(BuildContext context) {
    return isDark(context) ? darkTextPrimary : textPrimary;
  }

  static Color textSecondaryFor(BuildContext context) {
    return isDark(context) ? darkTextSecondary : textSecondary;
  }

  static Color textMutedFor(BuildContext context) {
    return isDark(context) ? darkTextMuted : textMuted;
  }

  static Color borderFor(BuildContext context) {
    return isDark(context) ? darkOutline : outline;
  }

  static Color strongBorderFor(BuildContext context) {
    return isDark(context) ? darkOutlineStrong : outlineStrong;
  }

  static Color iconFor(BuildContext context) {
    return isDark(context) ? darkIconColor : iconColor;
  }

  static Color disabledFor(BuildContext context) {
    return isDark(context) ? darkDisabled : disabled;
  }

  static Color softPrimaryFor(BuildContext context) {
    return isDark(context) ? primary.withValues(alpha: 0.18) : primarySoft;
  }

  static Color fieldFill(BuildContext context) {
    return isDark(context) ? const Color(0xFF0F1A2D) : bgDark;
  }
}

class AppGradients {
  const AppGradients._();

  static const primary = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary, AppColors.primary],
  );

  static const info = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
  );

  static const success = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
  );
}
