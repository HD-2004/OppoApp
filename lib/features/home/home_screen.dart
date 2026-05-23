import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Oppo Temp Jobs')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Temporary work operations',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'V1 focuses on urgent shift jobs with claim, check-in, check-out, confirmation, and escrow status tracking.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _RoleEntryCard(
              icon: Icons.work_history_outlined,
              title: 'Worker marketplace',
              subtitle: 'Browse open shifts, claim work, and manage a booking.',
              onTap: () => context.go('/worker'),
            ),
            const SizedBox(height: 12),
            _RoleEntryCard(
              icon: Icons.storefront_outlined,
              title: 'Employer dashboard',
              subtitle: 'Publish urgent shifts and monitor accepted workers.',
              onTap: () => context.go('/employer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleEntryCard extends StatelessWidget {
  const _RoleEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
