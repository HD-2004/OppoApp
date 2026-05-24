import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class LocationCard extends StatelessWidget {
  const LocationCard({super.key, required this.onUpdateLocation});

  final VoidCallback onUpdateLocation;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.text('currentLocation'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.text('tryChangeFilters')),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onUpdateLocation,
              icon: const Icon(Icons.my_location),
              label: Text(l10n.text('updateLocation')),
            ),
          ],
        ),
      ),
    );
  }
}
