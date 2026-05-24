import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class HomeFilterChips extends StatelessWidget {
  const HomeFilterChips({super.key, required this.filters});

  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return FilterChip(
            label: Text(filters[index]),
            selected: index == 0,
            onSelected: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.format('filterWillBeBuilt', {
                      'filter': filters[index],
                    }),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
