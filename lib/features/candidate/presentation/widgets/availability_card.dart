import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.isAvailable,
    required this.onChanged,
  });

  final bool isAvailable;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.text('workStatus'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAvailable ? l10n.available : l10n.off,
                    style: textTheme.titleLarge?.copyWith(
                      color: isAvailable
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAvailable
                        ? l10n.text('availableDescription')
                        : l10n.text('offDescription'),
                  ),
                ],
              ),
            ),
            Switch(value: isAvailable, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
