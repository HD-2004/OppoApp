import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/jobs/presentation/widgets/employer_avatar.dart';

class HomeLatestJobsSection extends ConsumerWidget {
  const HomeLatestJobsSection({
    super.key,
    required this.onJobTap,
    required this.onApplyTap,
  });

  final ValueChanged<JobPost> onJobTap;
  final ValueChanged<JobPost> onApplyTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(activeJobsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Công việc mới nhất',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        jobs.when(
          loading: () => const _LatestJobsShimmer(),
          error: (_, _) => _LatestJobsError(
            onRetry: () => ref.invalidate(activeJobsProvider),
          ),
          data: (items) {
            if (items.isEmpty) return const _LatestJobsEmpty();
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFF3F4F6),
              ),
              itemBuilder: (_, index) => _LatestJobCard(
                job: items[index],
                onTap: () => onJobTap(items[index]),
                onApply: () => onApplyTap(items[index]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LatestJobCard extends StatelessWidget {
  const _LatestJobCard({
    required this.job,
    required this.onTap,
    required this.onApply,
  });

  final JobPost job;
  final VoidCallback onTap;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final company = job.companyName?.trim().isNotEmpty == true
        ? job.companyName!
        : job.employerName;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployerAvatar(
                employerName: company,
                imageUrl: job.employerAvatarUrl,
                size: 58,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      children: [
                        _Meta(
                          icon: Icons.location_on_outlined,
                          text: job.location.isEmpty
                              ? 'Chưa cập nhật địa điểm'
                              : job.location,
                        ),
                        _Meta(
                          icon: Icons.payments_outlined,
                          text: job.salary.isEmpty ? 'Thỏa thuận' : job.salary,
                          highlighted: true,
                        ),
                        _Meta(
                          icon: Icons.work_outline_rounded,
                          text: job.jobType.label,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _timeAgo(job.postedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: onApply,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Ứng tuyển',
                            style: TextStyle(
                              fontSize: 12,
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
      ),
    );
  }

  String _timeAgo(DateTime postedAt) {
    if (postedAt.millisecondsSinceEpoch == 0) return 'Chưa rõ thời gian đăng';
    final difference = DateTime.now().difference(postedAt);
    if (difference.isNegative || difference.inMinutes < 1) return 'Vừa đăng';
    if (difference.inMinutes < 60) {
      return 'Đăng ${difference.inMinutes} phút trước';
    }
    if (difference.inHours < 24) {
      return 'Đăng ${difference.inHours} giờ trước';
    }
    if (difference.inDays < 7) {
      return 'Đăng ${difference.inDays} ngày trước';
    }
    return 'Đăng ${(difference.inDays / 7).floor()} tuần trước';
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  final IconData icon;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlighted ? AppColors.primary : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
                color: highlighted
                    ? AppColors.primary
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestJobsShimmer extends StatelessWidget {
  const _LatestJobsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 126,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _LatestJobsEmpty extends StatelessWidget {
  const _LatestJobsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.work_off_outlined, size: 40, color: Color(0xFF9CA3AF)),
            SizedBox(height: 10),
            Text(
              'Hiện chưa có công việc phù hợp',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestJobsError extends StatelessWidget {
  const _LatestJobsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFF9CA3AF),
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text('Không tải được danh sách công việc'),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
