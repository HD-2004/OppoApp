import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.support)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SupportCard(
              icon: Icons.support_agent_outlined,
              title: l10n.text('contactSupport'),
              subtitle: l10n.text('searchWillBeBuilt'),
            ),
            const SizedBox(height: 12),
            _SupportCard(
              icon: Icons.help_outline,
              title: 'FAQ',
              subtitle: l10n.text('searchWillBeBuilt'),
            ),
            const SizedBox(height: 12),
            _SupportCard(
              icon: Icons.report_problem_outlined,
              title: l10n.isVietnamese ? 'Báo cáo sự cố' : 'Report a problem',
              subtitle: l10n.text('searchWillBeBuilt'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
