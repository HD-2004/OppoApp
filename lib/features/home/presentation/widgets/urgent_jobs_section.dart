import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/domain/job_post.dart';

class UrgentJobsSection extends ConsumerWidget {
  const UrgentJobsSection({super.key, required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickJobsAsync = ref.watch(activeQuickJobsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Việc làm gấp',
                  style: TextStyle(
                    fontSize: 16,
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
                    color: Color(0xFF0D9488),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scroll list
        SizedBox(
          height: 140,
          child: quickJobsAsync.when(
            loading: () => const _UrgentJobsShimmer(),
            error: (err, _) => _UrgentJobsError(
              onRetry: () => ref.invalidate(activeQuickJobsProvider),
            ),
            data: (jobs) {
              if (jobs.isEmpty) {
                return const _UrgentJobsEmpty();
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: jobs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _UrgentJobCard(job: jobs[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UrgentJobCard extends StatelessWidget {
  const _UrgentJobCard({required this.job});
  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final shiftTime = _buildShiftTime();
    final salaryLabel = _buildSalary();

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URGENT badge + salary
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.white, size: 10),
                    SizedBox(width: 2),
                    Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  salaryLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFC2410C),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Job title
          Text(
            job.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Shift time + location
          Row(
            children: [
              if (shiftTime.isNotEmpty) ...[
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    shiftTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (job.location.isNotEmpty) ...[
                const Icon(
                  Icons.location_on_rounded,
                  size: 12,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    _shortLocation(job.location),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _buildShiftTime() {
    if (job.startTime != null &&
        job.endTime != null &&
        job.startTime!.isNotEmpty &&
        job.endTime!.isNotEmpty) {
      return '${job.startTime} - ${job.endTime}';
    }
    if (job.shiftTime.isNotEmpty) {
      return job.shiftTime;
    }
    return '';
  }

  String _buildSalary() {
    if (job.hourlyRate != null && job.hourlyRate! > 0) {
      final k = (job.hourlyRate! * 0.85 / 1000).round();
      return '${k}k/h';
    }
    if (job.salary.isNotEmpty) {
      return job.salary;
    }
    return 'Thỏa thuận';
  }

  String _shortLocation(String location) {
    // Extract district or keep short
    final parts = location.split(',');
    return parts.first.trim();
  }
}

// ── States ──────────────────────────────────────────────────────────────────

class _UrgentJobsShimmer extends StatelessWidget {
  const _UrgentJobsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _UrgentJobsEmpty extends StatelessWidget {
  const _UrgentJobsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Hiện chưa có việc làm gấp',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _UrgentJobsError extends StatelessWidget {
  const _UrgentJobsError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 28),
          const SizedBox(height: 6),
          const Text(
            'Không tải được việc làm gấp',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
