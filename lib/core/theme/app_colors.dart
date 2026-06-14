import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF213E7A);
  static const secondary = Color(0xFF3D86BF);
  static const accent = Color(0xFF2CC7F0);

  static const primaryLight = secondary;
  static const primaryDark = Color(0xFF172B58);
  static const backgroundSoft = lightBackground;
  static const border = outline;
  static const textOnPrimary = Colors.white;

  static const primarySoft = Color(0xFFEAF4FF);
  static const secondarySoft = Color(0xFFDFF2FF);
  static const accentSoft = Color(0xFFE8FAFF);

  static const lightBackground = Color(0xFFF5FAFF);
  static const darkBackground = Color(0xFF07101E);
  static const lightSurface = Colors.white;
  static const darkSurface = Color(0xFF101C31);
  static const darkCardBackground = Color(0xFF13213A);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);
  static const textDisabled = Color(0xFF94A3B8);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFF94A3B8);

  static const outline = Color(0xFFD9E8F5);
  static const outlineStrong = Color(0xFFBBD4EA);
  static const darkOutline = Color(0xFF29405F);
  static const darkOutlineStrong = Color(0xFF3C587C);
  static const disabled = Color(0xFF94A3B8);
  static const darkDisabled = Color(0xFF64748B);
  static const iconColor = textSecondary;
  static const darkIconColor = darkTextSecondary;

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static LinearGradient brandGradient({
    AlignmentGeometry begin = Alignment.centerLeft,
    AlignmentGeometry end = Alignment.centerRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [primary, secondary],
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
    return isDark(context) ? const Color(0xFF0F1A2D) : const Color(0xFFF3F7FB);
  }
}
