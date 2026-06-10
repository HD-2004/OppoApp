import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/featured_employer_package_providers.dart';
import '../../domain/employer_package.dart';
import 'package_badge.dart';

class FeaturedEmployerBanner extends ConsumerWidget {
  const FeaturedEmployerBanner({super.key, required this.onViewJobs});

  final VoidCallback? onViewJobs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employersAsync = ref.watch(featuredEmployersProvider);

    return employersAsync.when(
      loading: () => const _FeaturedEmployerBannerSkeleton(),
      error: (_, _) => _FeaturedEmployerEmpty(
        onRetry: () => ref.invalidate(featuredEmployersProvider),
      ),
      data: (employers) {
        if (employers.isEmpty) {
          return const _FeaturedEmployerEmpty();
        }

        return SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: employers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _FeaturedEmployerBannerCard(
              employer: employers[index],
              onViewJobs: onViewJobs,
            ),
          ),
        );
      },
    );
  }
}

class _FeaturedEmployerBannerCard extends StatelessWidget {
  const _FeaturedEmployerBannerCard({
    required this.employer,
    required this.onViewJobs,
  });

  final FeaturedEmployer employer;
  final VoidCallback? onViewJobs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 286,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: employer.packageTier.accentColor.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _EmployerLogo(url: employer.logoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PackageBadge(tier: employer.packageTier, compact: true),
                const SizedBox(height: 8),
                Text(
                  employer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _activeJobsLabel(employer.activeJobCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: onViewJobs,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Xem ngay'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _activeJobsLabel(int? count) {
    if (count == null) return 'Đang tuyển';
    return 'Đang tuyển $count vị trí';
  }
}

class _EmployerLogo extends StatelessWidget {
  const _EmployerLogo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
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
                errorBuilder: (_, _, _) => const _EmployerLogoFallback(),
              ),
            )
          : const _EmployerLogoFallback(),
    );
  }
}

class _EmployerLogoFallback extends StatelessWidget {
  const _EmployerLogoFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.business_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _FeaturedEmployerEmpty extends StatelessWidget {
  const _FeaturedEmployerEmpty({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
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

class _FeaturedEmployerBannerSkeleton extends StatelessWidget {
  const _FeaturedEmployerBannerSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 286,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
