import 'package:flutter/material.dart';

import '../../domain/job_post.dart';

class FeaturedJobItem {
  const FeaturedJobItem({
    required this.id,
    required this.title,
    required this.employerName,
    this.logoUrl,
    this.location,
    this.salary,
    this.packageLabel,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String employerName;
  final String? logoUrl;
  final String? location;
  final String? salary;
  final String? packageLabel;
  final bool isFeatured;

  factory FeaturedJobItem.fromJob(JobPost job) {
    return FeaturedJobItem(
      id: job.id,
      title: job.title,
      employerName: job.companyName?.trim().isNotEmpty == true
          ? job.companyName!.trim()
          : job.employerName.trim(),
      logoUrl: job.employerAvatarUrl,
      location: job.location.trim().isEmpty ? null : job.location.trim(),
      salary: job.salary.trim().isEmpty ? null : job.salary.trim(),
      isFeatured: job.visibilityScore > 0,
    );
  }
}

class FeaturedJobsSection extends StatelessWidget {
  const FeaturedJobsSection({
    super.key,
    required this.items,
    this.onSeeAllPressed,
    this.onJobPressed,
  });

  final List<FeaturedJobItem> items;
  final VoidCallback? onSeeAllPressed;
  final ValueChanged<String>? onJobPressed;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tin tuyển dụng nổi bật',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSeeAllPressed,
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 12),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return FeaturedJobCard(
                  item: item,
                  onTap: () => onJobPressed?.call(item.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedJobCard extends StatelessWidget {
  const FeaturedJobCard({super.key, required this.item, this.onTap});

  final FeaturedJobItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final softSurface = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        width: 204,
        height: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FeaturedEmployerLogo(logoUrl: item.logoUrl),
                const Spacer(),
                if (item.packageLabel?.trim().isNotEmpty == true)
                  FeaturedPackageBadge(label: item.packageLabel!.trim())
                else if (item.isFeatured)
                  const FeaturedPackageBadge(label: 'Nổi bật'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                height: 1.16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.employerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: softSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _supportingText(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _supportingText(FeaturedJobItem item) {
    final parts = [
      if (item.location?.trim().isNotEmpty == true) item.location!.trim(),
      if (item.salary?.trim().isNotEmpty == true) item.salary!.trim(),
    ];
    return parts.isEmpty ? 'Đang tuyển dụng' : parts.join(' · ');
  }
}

class FeaturedEmployerLogo extends StatelessWidget {
  const FeaturedEmployerLogo({super.key, this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = logoUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: hasImage
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _EmployerLogoFallback(),
            )
          : const _EmployerLogoFallback(),
    );
  }
}

class FeaturedPackageBadge extends StatelessWidget {
  const FeaturedPackageBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmployerLogoFallback extends StatelessWidget {
  const _EmployerLogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.business_outlined,
      color: Color(0xFF64748B),
      size: 23,
    );
  }
}
