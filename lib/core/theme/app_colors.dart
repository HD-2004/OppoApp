import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF213E7A);
  static const secondary = Color(0xFF3D86BF);
  static const accent = Color(0xFF2CC7F0);

  static const primarySoft = Color(0xFFEAF4FF);
  static const secondarySoft = Color(0xFFDFF2FF);
  static const accentSoft = Color(0xFFE8FAFF);

  static const lightBackground = Color(0xFFF5FAFF);
  static const darkBackground = Color(0xFF07101E);
  static const lightSurface = Colors.white;
  static const darkSurface = Color(0xFF101C31);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);
  static const textDisabled = Color(0xFF94A3B8);

  static const outline = Color(0xFFD9E8F5);
  static const outlineStrong = Color(0xFFBBD4EA);

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
}
