import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/data/aws_application_repository.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/jobs/presentation/widgets/employer_avatar.dart';

final candidateHomeApplicationsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, userId) {
      return ref
          .watch(applicationRepositoryProvider)
          .getCandidateApplications(userId);
    });

class HomeCurrentJob {
  const HomeCurrentJob({
    required this.job,
    required this.applicationId,
    required this.status,
    required this.startedAt,
  });

  final JobPost job;
  final String applicationId;
  final String status;
  final DateTime startedAt;

  bool get isPendingCandidateConfirmation =>
      status == 'completed_pending_candidate';

  bool get isCompleted => status == 'completed';

  bool get isAwaitingCandidateRating => isCompleted;
}

HomeCurrentJob? resolveHomeCurrentJob({
  required List<Map<String, dynamic>> applications,
  required List<JobPost> jobs,
}) {
  final eligible =
      applications.where((application) {
          final status = application['status']?.toString().toLowerCase().trim();
          return status == 'accepted' ||
              status == 'completed_pending_candidate' ||
              (status == 'completed' && application['candidateRating'] == null);
        }).toList()
        ..sort((a, b) => _applicationDate(b).compareTo(_applicationDate(a)));

  for (final application in eligible) {
    final jobId = application['jobId']?.toString() ?? '';
    if (jobId.isEmpty) continue;

    JobPost? matchedJob;
    for (final job in jobs) {
      if (job.idJob == jobId || job.id == jobId) {
        matchedJob = job;
        break;
      }
    }
    if (matchedJob == null) continue;

    return HomeCurrentJob(
      job: matchedJob,
      applicationId: (application['applicationId'] ?? application['id'] ?? '')
          .toString(),
      status: application['status']?.toString().toLowerCase().trim() ?? '',
      startedAt: _applicationDate(application),
    );
  }

  return null;
}

DateTime _applicationDate(Map<String, dynamic> application) {
  final raw =
      application['appliedAt'] ??
      application['createdAt'] ??
      application['updatedAt'];
  return DateTime.tryParse(raw?.toString() ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

class HomeCurrentJobSection extends ConsumerWidget {
  const HomeCurrentJobSection({
    super.key,
    required this.userId,
    required this.onDetails,
    required this.onConfirmCompletion,
    required this.onRateEmployer,
  });

  final String? userId;
  final ValueChanged<JobPost> onDetails;
  final Future<void> Function(HomeCurrentJob current) onConfirmCompletion;
  final Future<void> Function(HomeCurrentJob current) onRateEmployer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();

    final applications = ref.watch(candidateHomeApplicationsProvider(id));
    final standardJobs = ref.watch(activeJobsProvider);
    final quickJobs = ref.watch(activeQuickJobsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.work_outline_rounded,
                color: Color(0xFF1E40AF),
                size: 23,
              ),
              SizedBox(width: 8),
              Text(
                'Công Việc Hiện Tại',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          applications.when(
            loading: () => const _LoadingCard(),
            error: (_, _) => _ErrorCard(
              onRetry: () =>
                  ref.invalidate(candidateHomeApplicationsProvider(id)),
            ),
            data: (items) {
              final jobs = <JobPost>[
                ...standardJobs.value ?? const <JobPost>[],
                ...quickJobs.value ?? const <JobPost>[],
              ];
              final current = resolveHomeCurrentJob(
                applications: items,
                jobs: jobs,
              );
              if (current == null) return const _EmptyCard();
              return _CurrentJobCard(
                current: current,
                onDetails: () => onDetails(current.job),
                onConfirmCompletion: () => onConfirmCompletion(current),
                onRateEmployer: () => onRateEmployer(current),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CurrentJobCard extends StatefulWidget {
  const _CurrentJobCard({
    required this.current,
    required this.onDetails,
    required this.onConfirmCompletion,
    required this.onRateEmployer,
  });

  final HomeCurrentJob current;
  final VoidCallback onDetails;
  final Future<void> Function() onConfirmCompletion;
  final Future<void> Function() onRateEmployer;

  @override
  State<_CurrentJobCard> createState() => _CurrentJobCardState();
}

class _CurrentJobCardState extends State<_CurrentJobCard> {
  bool _isConfirming = false;
  bool _isOpeningRating = false;

  Future<void> _confirmCompletion() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      await widget.onConfirmCompletion();
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Future<void> _rateEmployer() async {
    if (_isOpeningRating) return;
    setState(() => _isOpeningRating = true);
    try {
      await widget.onRateEmployer();
    } finally {
      if (mounted) setState(() => _isOpeningRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final job = current.job;
    final company = job.companyName?.trim().isNotEmpty == true
        ? job.companyName!.trim()
        : job.employerName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E2F7), width: 1.3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          final info = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  company,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (job.location.isNotEmpty)
                      _Meta(
                        icon: Icons.location_on_outlined,
                        text: job.location,
                      ),
                    if (job.shiftTime.isNotEmpty)
                      _Meta(icon: Icons.schedule_rounded, text: job.shiftTime),
                    _Meta(
                      icon: Icons.payments_outlined,
                      text: 'Thu nhập: ${job.salary}',
                    ),
                    _Meta(
                      icon: Icons.calendar_month_outlined,
                      text:
                          'Từ ${DateFormat('d/M/yyyy').format(current.startedAt)}',
                    ),
                  ],
                ),
              ],
            ),
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusBadge(current: current),
              if (current.isPendingCandidateConfirmation)
                FilledButton.icon(
                  onPressed: _isConfirming ? null : _confirmCompletion,
                  icon: _isConfirming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _isConfirming ? 'Đang xác nhận...' : 'Xác nhận hoàn thành',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (current.isAwaitingCandidateRating)
                FilledButton.icon(
                  onPressed: _isOpeningRating ? null : _rateEmployer,
                  icon: _isOpeningRating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.star_outline_rounded, size: 19),
                  label: Text(
                    _isOpeningRating ? 'Đang mở...' : 'Đánh giá Nhà tuyển dụng',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: widget.onDetails,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Xem chi tiết'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E40AF),
                  side: const BorderSide(color: Color(0xFFB8C6EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmployerAvatar(
                      employerName: company,
                      imageUrl: job.employerAvatarUrl,
                      size: 58,
                    ),
                    const SizedBox(width: 14),
                    info,
                  ],
                ),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [
              EmployerAvatar(
                employerName: company,
                imageUrl: job.employerAvatarUrl,
                size: 64,
              ),
              const SizedBox(width: 18),
              info,
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.current});

  final HomeCurrentJob current;

  @override
  Widget build(BuildContext context) {
    final pending = current.isPendingCandidateConfirmation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFFFF7E6) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pending ? const Color(0xFFF6C86E) : const Color(0xFFB7E4D2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pending ? Icons.schedule_rounded : Icons.check_circle_outline,
            size: 17,
            color: pending ? const Color(0xFFD97706) : const Color(0xFF10B981),
          ),
          const SizedBox(width: 5),
          if (current.isAwaitingCandidateRating)
            const Text(
              'Chờ bạn đánh giá',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          if (!current.isAwaitingCandidateRating)
            Text(
              pending ? 'Chờ bạn xác nhận' : 'Đang làm việc',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pending
                    ? const Color(0xFFD97706)
                    : const Color(0xFF10B981),
              ),
            ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1E40AF)),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 110,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Text(
        'Chưa có công việc tuyển gấp nào.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF6B7280)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Không tải được công việc hiện tại. Thử lại'),
      ),
    );
  }
}
