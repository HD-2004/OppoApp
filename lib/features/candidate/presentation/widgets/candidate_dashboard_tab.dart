import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';

class CandidateDashboardTab extends ConsumerWidget {
  const CandidateDashboardTab({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).asData?.value.user;

    // Get candidate full name
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : l10n.candidate;

    // Get time of day for dynamic greeting
    final hour = DateTime.now().hour;
    String greetingKey;
    if (hour >= 5 && hour < 12) {
      greetingKey = l10n.isVietnamese
          ? 'Chào buổi sáng, {name}!'
          : 'Good morning, {name}!';
    } else if (hour >= 12 && hour < 18) {
      greetingKey = l10n.isVietnamese
          ? 'Chào buổi chiều, {name}!'
          : 'Good afternoon, {name}!';
    } else {
      greetingKey = l10n.isVietnamese
          ? 'Chào buổi tối, {name}!'
          : 'Good evening, {name}!';
    }

    final greeting = greetingKey.replaceAll('{name}', displayName);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Welcome Banner
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E40AF).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative background icon / shape
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(
                        Icons.work_outline,
                        size: 150,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                greeting,
                                style: textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Text('👋', style: TextStyle(fontSize: 24)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.homeWelcomeSubtitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1E40AF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => onSelectTab(
                                1,
                              ), // Switch to Jobs tab (Bài đăng)
                              icon: const Icon(Icons.search, size: 18),
                              label: Text(
                                l10n.findJobsButton,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () => onSelectTab(
                                3,
                              ), // Switch to Profile tab (Hồ sơ của tôi)
                              icon: const Icon(Icons.edit, size: 18),
                              label: Text(
                                l10n.updateCvButton,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Stats Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: crossAxisCount == 4 ? 1.6 : 1.45,
                  children: [
                    _buildStatCard(
                      context,
                      title: l10n.statsAppliedJobs,
                      value: '9',
                      badgeText: '+1 ${l10n.recentLabel}',
                      icon: Icons.description_outlined,
                      cardColor: const Color(0xFFEFF6FF),
                      iconBgColor: const Color(0xFF1E40AF),
                      textColor: const Color(0xFF1E40AF),
                      badgeColor: const Color(0xFFDCDFEA),
                      badgeTextColor: const Color(0xFF1E40AF),
                    ),
                    _buildStatCard(
                      context,
                      title: l10n.statsSavedJobs,
                      value: '0',
                      badgeText: '0 ${l10n.thisWeekLabel}',
                      icon: Icons.star_border_outlined,
                      cardColor: const Color(0xFFFFF7ED),
                      iconBgColor: const Color(0xFFEA580C),
                      textColor: const Color(0xFFEA580C),
                      badgeColor: const Color(0xFFFFEDD5),
                      badgeTextColor: const Color(0xFFEA580C),
                    ),
                    _buildStatCard(
                      context,
                      title: l10n.statsProfileViews,
                      value: '165',
                      badgeText: '+12% ${l10n.thisMonthLabel}',
                      icon: Icons.visibility_outlined,
                      cardColor: const Color(0xFFF0FDF4),
                      iconBgColor: const Color(0xFF16A34A),
                      textColor: const Color(0xFF16A34A),
                      badgeColor: const Color(0xFFDCFCE7),
                      badgeTextColor: const Color(0xFF16A34A),
                    ),
                    _buildStatCard(
                      context,
                      title: l10n.statsMatchedJobs,
                      value: '0',
                      badgeText: '0 ${l10n.thisMonthLabel}',
                      icon: Icons.check_circle_outline,
                      cardColor: const Color(0xFFEEF2FF),
                      iconBgColor: const Color(0xFF4F46E5),
                      textColor: const Color(0xFF4F46E5),
                      badgeColor: const Color(0xFFE0E7FF),
                      badgeTextColor: const Color(0xFF4F46E5),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 3. Current Jobs Section
            Text(
              l10n.currentJobsTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.work_off_outlined,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.noCurrentJobs,
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String badgeText,
    required IconData icon,
    required Color cardColor,
    required Color iconBgColor,
    required Color textColor,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconBgColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 9,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
