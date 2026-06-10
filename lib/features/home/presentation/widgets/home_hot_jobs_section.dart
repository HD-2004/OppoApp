import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/jobs/presentation/widgets/employer_avatar.dart';

class HomeHotJobsSection extends ConsumerWidget {
  const HomeHotJobsSection({
    super.key,
    required this.onSeeAll,
    required this.onJobTap,
  });

  final VoidCallback onSeeAll;
  final ValueChanged<JobPost> onJobTap;

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFF97316),
            size: 22,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Việc làm nổi bật',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'Xem tất cả',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final quickJobs = ref.watch(activeQuickJobsProvider);

    return quickJobs.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 238, child: _HotJobsShimmer()),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          _HotJobsError(onRetry: () => ref.invalidate(activeQuickJobsProvider)),
        ],
      ),
      data: (jobs) {
        if (jobs.isEmpty) return const SizedBox.shrink();

        final sorted = [...jobs];
        final userLat = user?.latitude;
        final userLng = user?.longitude;
        if (userLat != null && userLng != null) {
          sorted.sort((a, b) {
            final aLat = a.latitude;
            final aLng = a.longitude;
            final bLat = b.latitude;
            final bLng = b.longitude;
            if (aLat == null || aLng == null) return 1;
            if (bLat == null || bLng == null) return -1;
            return _distance(
              userLat,
              userLng,
              aLat,
              aLng,
            ).compareTo(_distance(userLat, userLng, bLat, bLng));
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            SizedBox(
              height: 238,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) => _HotJobCard(
                  job: sorted[index],
                  onTap: () => onJobTap(sorted[index]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _HotJobCard extends StatelessWidget {
  const _HotJobCard({required this.job, required this.onTap});

  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final company = job.companyName?.trim().isNotEmpty == true
        ? job.companyName!
        : job.employerName;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 224,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmployerAvatar(
                    employerName: company,
                    imageUrl: job.employerAvatarUrl,
                    size: 46,
                    borderRadius: 10,
                  ),
                  const Spacer(),
                  const _UrgentBadge(),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                company,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 10),
              Text(
                job.salary.isEmpty ? 'Thỏa thuận' : job.salary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Ứng tuyển nhanh',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Tuyển gấp',
        style: TextStyle(
          color: Color(0xFFD97706),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HotJobsShimmer extends StatelessWidget {
  const _HotJobsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, _) => Container(
        width: 224,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _HotJobsError extends StatelessWidget {
  const _HotJobsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Không tải được việc làm tuyển gấp.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
