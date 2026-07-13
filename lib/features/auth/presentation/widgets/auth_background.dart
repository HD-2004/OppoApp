import 'package:flutter/material.dart';

import 'auth_colors.dart';

/// Solid auth background behind content.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = AuthColors.isDark(context);
    return ColoredBox(
      color: isDark ? const Color(0xFF071226) : AuthColors.authBackgroundTone,
      child: child,
    );
  }
}
