import 'package:flutter/material.dart';

import '../../domain/employer_package.dart';

extension EmployerPackageTierStyle on EmployerPackageTier {
  Color get accentColor {
    return switch (this) {
      EmployerPackageTier.basicBoost => const Color(0xFF94A3B8),
      EmployerPackageTier.premium => const Color(0xFFF59E0B),
      EmployerPackageTier.enterprise => const Color(0xFF7C3AED),
    };
  }
}

class PackageBadge extends StatelessWidget {
  const PackageBadge({super.key, required this.tier, this.compact = false});

  final EmployerPackageTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = tier.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        tier.badgeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white : accent,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
