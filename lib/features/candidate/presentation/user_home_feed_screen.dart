import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user_profile.dart';
import '../application/jobs_providers.dart';
import '../data/aws_application_repository.dart';
import '../domain/application_repository.dart';
import '../domain/job_post.dart';
import 'user_job_detail_screen.dart';
import 'widgets/home_filter_chips.dart';
import 'widgets/job_post_card.dart';

class UserHomeFeedScreen extends ConsumerStatefulWidget {
  const UserHomeFeedScreen({super.key});

  @override
  ConsumerState<UserHomeFeedScreen> createState() => _UserHomeFeedScreenState();
}

class _UserHomeFeedScreenState extends ConsumerState<UserHomeFeedScreen> {
  Future<void> _refreshFeed() async {
    ref.invalidate(activeJobsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _handleApply(JobPost job, AuthUserProfile? user) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để ứng tuyển.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repository = ref.read(applicationRepositoryProvider);
      final cvs = await repository.getCandidateCVs(user.userId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading

      if (cvs.isEmpty) {
        _showNoCVDialog();
      } else {
        _showCVSelectionDialog(job, cvs);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading
      _showErrorDialog('Không thể tải danh sách CV. Vui lòng thử lại.');
    }
  }

  void _showNoCVDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Chưa có CV',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn chưa có CV. Vui lòng tải CV lên trong phần Hồ sơ của tôi trước khi ứng tuyển.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showCVSelectionDialog(JobPost job, List<Map<String, dynamic>> cvList) {
    String? selectedCvId = cvList.first['id']?.toString();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text(
                'Chọn CV ứng tuyển',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: RadioGroup<String>(
                  groupValue: selectedCvId,
                  onChanged: (val) {
                    setModalState(() {
                      selectedCvId = val;
                    });
                  },
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: cvList.length,
                    itemBuilder: (context, index) {
                      final cv = cvList[index];
                      final id = cv['id']?.toString();
                      final name = cv['cvFileName']?.toString() ?? 'CV.pdf';
                      final date = cv['cvUploadDate']?.toString() ?? '';

                      return RadioListTile<String>(
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: date.isNotEmpty
                            ? Text('Tải lên ngày: $date')
                            : null,
                        value: id!,
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final chosen = cvList.firstWhere(
                      (c) => c['id']?.toString() == selectedCvId,
                    );
                    _submitApplication(
                      job,
                      chosen['cvUrl'] ?? chosen['cvS3Key'] ?? '',
                      chosen['cvFileName'] ?? 'CV.pdf',
                    );
                  },
                  child: const Text('Nộp đơn'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitApplication(
    JobPost job,
    String cvUrl,
    String cvFilename,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repository = ref.read(applicationRepositoryProvider);
      final user = ref.read(authControllerProvider).asData?.value.user;
      if (user == null) {
        throw Exception('Vui lòng đăng nhập để ứng tuyển.');
      }
      await repository.submitApplication(
        jobId: job.idJob,
        cvUrl: cvUrl,
        cvFilename: cvFilename,
        notification: ApplicationNotificationDetails(
          employerId: job.employerId,
          candidateId: user.userId,
          candidateName: user.fullName,
          jobTitle: job.title,
          companyName: job.companyName ?? job.employerName,
          isQuickJob: job.isQuickJob,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Dismiss loading
      final msg = e.toString();
      if (msg.contains('ALREADY_APPLIED') ||
          msg.contains('already applied') ||
          msg.contains('đã ứng tuyển')) {
        _showErrorDialog('Bạn đã ứng tuyển công việc này rồi!');
      } else {
        _showErrorDialog(msg.replaceAll('Exception: ', ''));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Thành công', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Hồ sơ ứng tuyển của bạn đã được gửi đi thành công!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _openDetails(JobPost job) {
    final user = ref.read(authControllerProvider).asData?.value.user;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserJobDetailScreen(
          job: job,
          onApplyPressed: () {
            Navigator.of(context).pop(); // close detail
            _handleApply(job, user);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : l10n.text('candidate').toLowerCase();

    final jobsAsync = ref.watch(activeJobsProvider);

    final filters = [
      l10n.text('nearby'),
      l10n.text('highSalary'),
      l10n.text('todayShift'),
      l10n.partTime,
      l10n.text('urgentJobs'),
    ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: jobsAsync.when(
          data: (jobs) {
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.isEmpty ? 4 : jobs.length + 3,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.format('homeGreeting', {
                                'name': displayName,
                              }),
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.text('homeSubtitle'),
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  );
                }

                if (index == 1) {
                  return SearchBar(
                    hintText: l10n.text('searchJobsOrEmployers'),
                    leading: const Icon(Icons.search),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.text('searchWillBeBuilt'))),
                      );
                    },
                  );
                }

                if (index == 2) {
                  return HomeFilterChips(filters: filters);
                }

                if (jobs.isEmpty) {
                  return const _EmptyFeedState();
                }

                final job = jobs[index - 3];
                return JobPostCard(
                  job: job,
                  onDetailsPressed: () => _openDetails(job),
                  onApplyPressed: () => _handleApply(job, user),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Lỗi tải công việc: $err')),
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.work_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            l10n.text('noJobsFound'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(l10n.text('tryChangeFilters'), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
