import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/domain/job_post.dart';

/// "Hot Jobs" section — horizontal swipe cards giống ảnh tham khảo
class HomeHotJobsSection extends ConsumerWidget {
  const HomeHotJobsSection({
    super.key,
    required this.onSeeAll,
    required this.onJobTap,
  });

  final VoidCallback onSeeAll;
  final ValueChanged<JobPost> onJobTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickJobsAsync = ref.watch(activeQuickJobsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Hot Jobs',
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
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Cards
        SizedBox(
          height: 230,
          child: quickJobsAsync.when(
            loading: () => const _HotJobsShimmer(),
            error: (_, _) => _HotJobsError(
              onRetry: () => ref.invalidate(activeQuickJobsProvider),
            ),
            data: (jobs) {
              if (jobs.isEmpty) return const _HotJobsEmpty();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _HotJobCard(job: jobs[i], onTap: () => onJobTap(jobs[i])),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HotJobCard extends StatelessWidget {
  const _HotJobCard({required this.job, required this.onTap});

  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final company = job.companyName ?? job.employerName;
    final salary = job.salary.isNotEmpty ? job.salary : 'Thỏa thuận';
    final isUrgent = job.isQuickJob || job.jobType == JobPostType.urgent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: logo area + urgent badge
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company logo
                  _CompanyLogo(logoUrl: job.employerAvatarUrl),
                  const Spacer(),
                  if (isUrgent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Urgent',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                job.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),

            // Company
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                company,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),

            // Salary + job type tags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _TagChip(label: salary, isBlue: true),
                  _TagChip(label: job.jobType.label, isBlue: false),
                ],
              ),
            ),

            const Spacer(),

            // Quick Apply button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Quick Apply',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.isBlue});

  final String label;
  final bool isBlue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBlue ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isBlue ? const Color(0xFF1E40AF) : const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                logoUrl!,
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
    return const Icon(
      Icons.business_rounded,
      size: 22,
      color: Color(0xFFD1D5DB),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

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
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _HotJobsEmpty extends StatelessWidget {
  const _HotJobsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined, size: 36, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Hiện chưa có Hot Jobs',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HotJobsError extends StatelessWidget {
  const _HotJobsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFD1D5DB),
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'Không tải được',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
