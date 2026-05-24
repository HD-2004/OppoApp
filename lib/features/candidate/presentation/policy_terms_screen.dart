import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

class PolicyTermsScreen extends StatelessWidget {
  const PolicyTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('policyTerms'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PolicyCard(
              title: l10n.isVietnamese
                  ? 'Điều khoản dịch vụ'
                  : 'Terms of Service',
              message: l10n.text('searchWillBeBuilt'),
            ),
            const SizedBox(height: 12),
            _PolicyCard(
              title: l10n.isVietnamese
                  ? 'Chính sách quyền riêng tư'
                  : 'Privacy Policy',
              message: l10n.text('searchWillBeBuilt'),
            ),
            const SizedBox(height: 12),
            _PolicyCard(
              title: l10n.isVietnamese
                  ? 'Quy tắc cộng đồng'
                  : 'Community Guidelines',
              message: l10n.text('searchWillBeBuilt'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}
