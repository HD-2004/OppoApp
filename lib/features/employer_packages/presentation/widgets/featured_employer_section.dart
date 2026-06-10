import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/featured_employer_package_providers.dart';
import '../../domain/employer_package.dart';
import 'package_badge.dart';

class FeaturedEmployerSection extends ConsumerWidget {
  const FeaturedEmployerSection({super.key, required this.onViewJobs});

  final VoidCallback? onViewJobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employersAsync = ref.watch(featuredEmployersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Text(
            '🔥 Nhà tuyển dụng nổi bật',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        employersAsync.when(
          loading: () => const _FeaturedEmployerSectionSkeleton(),
          error: (_, _) => _FeaturedEmployerSectionEmpty(
            onRetry: () => ref.invalidate(featuredEmployersProvider),
          ),
          data: (employers) {
            if (employers.isEmpty) {
              return const _FeaturedEmployerSectionEmpty();
            }

            return SizedBox(
              height: 122,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: employers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _FeaturedEmployerCard(
                  employer: employers[index],
                  onTap: onViewJobs,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _FeaturedEmployerCard extends StatelessWidget {
  const _FeaturedEmployerCard({required this.employer, required this.onTap});

  final FeaturedEmployer employer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 294,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            _Logo(url: employer.logoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          employer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (employer.rating != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        Text(
                          employer.rating!.toStringAsFixed(1),
                          style: textTheme.labelMedium,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        icon: Icons.work_outline_rounded,
                        label: _activeJobsLabel(employer.activeJobCount),
                      ),
                      if (employer.distanceLabel?.isNotEmpty == true)
                        _MetaChip(
                          icon: Icons.near_me_outlined,
                          label: employer.distanceLabel!,
                        ),
                    ],
                  ),
                  const Spacer(),
                  PackageBadge(tier: employer.packageTier, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _activeJobsLabel(int? count) {
    if (count == null) return 'Đang tuyển';
    return '$count việc đang tuyển';
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: url != null && url!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _LogoFallback(),
              ),
            )
          : const _LogoFallback(),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.business_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _FeaturedEmployerSectionEmpty extends StatelessWidget {
  const _FeaturedEmployerSectionEmpty({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.business_center_outlined, color: colorScheme.outline),
            const SizedBox(width: 10),
            const Expanded(child: Text('Hiện chưa có nhà tuyển dụng nổi bật')),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _FeaturedEmployerSectionSkeleton extends StatelessWidget {
  const _FeaturedEmployerSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 294,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
