import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

class UserLocationScreen extends StatelessWidget {
  const UserLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _PlaceholderDetailScreen(
      title: l10n.location,
      message: l10n.text('tryChangeFilters'),
    );
  }
}

class _PlaceholderDetailScreen extends StatelessWidget {
  const _PlaceholderDetailScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
