import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/data/aws_application_repository.dart';
import '../../../../features/candidate/domain/application_repository.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/candidate/presentation/user_job_detail_screen.dart';
import '../../../../features/candidate/presentation/widgets/candidate_intent_input.dart';
import '../../../../features/candidate/presentation/widgets/featured_jobs_section.dart';
import '../../../../features/candidate/presentation/widgets/job_post_card.dart';
import '../../../../features/employer_packages/application/featured_employer_package_providers.dart';
import '../../../../features/messaging/presentation/pages/messages_screen.dart';
import '../../../../features/wallet/presentation/controllers/wallet_controller.dart';
import '../widgets/candidate_menu_drawer.dart';
import '../widgets/home_s3_banner_carousel.dart';
import '../widgets/home_current_job_section.dart';
import '../widgets/oppo_home_header.dart';

class CandidateHomePage extends ConsumerStatefulWidget {
  const CandidateHomePage({
    super.key,
    required this.onNotificationTap,
    required this.onSeeAllJobsTap,
    required this.onWalletTap,
    required this.onJobsTap,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onSupportTap,
    required this.onSignOutTap,
  });

  final VoidCallback onNotificationTap;
  final VoidCallback onSeeAllJobsTap;
  final VoidCallback onWalletTap;
  final VoidCallback onJobsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSupportTap;
  final VoidCallback onSignOutTap;

  @override
  ConsumerState<CandidateHomePage> createState() => _CandidateHomePageState();
}

class _CandidateHomePageState extends ConsumerState<CandidateHomePage> {
  Future<void> _onRefresh() async {
    ref.invalidate(activeQuickJobsProvider);
    ref.invalidate(activeJobsProvider);
    ref.invalidate(featuredEmployersProvider);
    ref.invalidate(walletControllerProvider);
    final userId = ref.read(authControllerProvider).asData?.value.user?.userId;
    if (userId != null) {
      ref.invalidate(candidateHomeApplicationsProvider(userId));
    }
    await Future.wait([
      ref.read(activeQuickJobsProvider.future),
      ref.read(activeJobsProvider.future),
    ]);
  }

  void _closeDrawerAndRun(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  void _openJobDetail(JobPost job) {
    final user = ref.read(authControllerProvider).asData?.value.user;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserJobDetailScreen(
          job: job,
          onApplyPressed: () {
            Navigator.of(context).pop();
            _handleApply(job, user);
          },
        ),
      ),
    );
  }

  Future<void> _handleApply(JobPost job, dynamic user) async {
    if (user == null) {
      _showMessage('Vui lòng đăng nhập để ứng tuyển.');
      return;
    }

    _showLoading();
    try {
      final repository = ref.read(applicationRepositoryProvider);
      final cvs = await repository.getCandidateCVs(user.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (cvs.isEmpty) {
        _showMessage(
          'Bạn chưa có CV. Vui lòng tải CV lên trong phần Hồ sơ trước.',
        );
      } else {
        _showCVPicker(job, cvs);
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage('Không thể tải danh sách CV.');
    }
  }

  void _showLoading() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  void _showCVPicker(JobPost job, List<Map<String, dynamic>> cvs) {
    String? selectedId = cvs.first['id']?.toString();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setModalState) => AlertDialog(
          title: const Text(
            'Chọn CV ứng tuyển',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: RadioGroup<String>(
              groupValue: selectedId,
              onChanged: (value) {
                setModalState(() => selectedId = value);
              },
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cvs.length,
                itemBuilder: (_, index) {
                  final cv = cvs[index];
                  final id = cv['id']?.toString();
                  if (id == null) return const SizedBox.shrink();
                  return RadioListTile<String>(
                    value: id,
                    title: Text(cv['cvFileName']?.toString() ?? 'CV.pdf'),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: selectedId == null
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      final chosen = cvs.firstWhere(
                        (cv) => cv['id']?.toString() == selectedId,
                      );
                      _submitApplication(
                        job,
                        chosen['cvUrl']?.toString() ??
                            chosen['cvS3Key']?.toString() ??
                            '',
                        chosen['cvFileName']?.toString() ?? 'CV.pdf',
                      );
                    },
              child: const Text('Nộp đơn'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitApplication(
    JobPost job,
    String cvUrl,
    String cvFilename,
  ) async {
    _showLoading();
    try {
      final user = ref.read(authControllerProvider).asData?.value.user;
      if (user == null) {
        throw Exception('Vui lòng đăng nhập để ứng tuyển.');
      }
      await ref
          .read(applicationRepositoryProvider)
          .submitApplication(
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
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('Ứng tuyển thành công!', backgroundColor: AppColors.primary);
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      final message = error.toString();
      _showMessage(
        message.contains('ALREADY_APPLIED') || message.contains('đã ứng tuyển')
            ? 'Bạn đã ứng tuyển công việc này rồi!'
            : message.replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Bạn';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'Chưa có email';
    final standardJobsAsync = ref.watch(activeJobsProvider);
    final quickJobsAsync = ref.watch(activeQuickJobsProvider);
    final feedJobs = <JobPost>[
      ...(quickJobsAsync.value ?? const <JobPost>[]),
      ...(standardJobsAsync.value ?? const <JobPost>[]),
    ];
    final uniqueFeedJobs = <String, JobPost>{
      for (final job in feedJobs) job.id: job,
    }.values.toList();
    final featuredJobs = uniqueFeedJobs
        .where((job) => job.visibilityScore > 0)
        .map(FeaturedJobItem.fromJob)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CandidateMenuDrawer(
        displayName: displayName,
        email: email,
        profileImage: user?.profileImage,
        onProfileTap: () => _closeDrawerAndRun(widget.onProfileTap),
        onJobsTap: () => _closeDrawerAndRun(widget.onJobsTap),
        onWalletTap: () => _closeDrawerAndRun(widget.onWalletTap),
        onNotificationsTap: () => _closeDrawerAndRun(widget.onNotificationTap),
        onSettingsTap: () => _closeDrawerAndRun(widget.onSettingsTap),
        onSupportTap: () => _closeDrawerAndRun(widget.onSupportTap),
        onSignOutTap: () => _closeDrawerAndRun(widget.onSignOutTap),
      ),
      appBar: OppoHomeHeader(
        onSearchChanged: (_) {},
        onChatPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CandidateIntentInput(
                avatarUrl: user?.profileImage,
                onChanged: (_) {},
                onSubmitted: (_) {},
              ),
            ),
            const SliverToBoxAdapter(child: HomeS3BannerCarousel()),
            SliverToBoxAdapter(
              child: FeaturedJobsSection(
                items: featuredJobs,
                onSeeAllPressed: widget.onSeeAllJobsTap,
                onJobPressed: (jobId) {
                  final selectedJob = uniqueFeedJobs.firstWhere(
                    (job) => job.id == jobId,
                  );
                  _openJobDetail(selectedJob);
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _FeedSectionHeader(
                  onSeeAllJobsTap: widget.onSeeAllJobsTap,
                ),
              ),
            ),
            if (standardJobsAsync.isLoading && uniqueFeedJobs.isEmpty)
              const SliverToBoxAdapter(child: _FeedLoadingState())
            else if (standardJobsAsync.hasError && uniqueFeedJobs.isEmpty)
              SliverToBoxAdapter(
                child: _FeedErrorState(
                  onRetry: () {
                    ref.invalidate(activeJobsProvider);
                    ref.invalidate(activeQuickJobsProvider);
                  },
                ),
              )
            else if (uniqueFeedJobs.isEmpty)
              SliverToBoxAdapter(
                child: _FeedEmptyState(onSeeAllJobsTap: widget.onSeeAllJobsTap),
              )
            else
              SliverList.separated(
                itemCount: uniqueFeedJobs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final job = uniqueFeedJobs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: JobPostCard(
                      job: job,
                      onDetailsPressed: () => _openJobDetail(job),
                      onApplyPressed: () => _handleApply(job, user),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }
}

class _FeedSectionHeader extends StatelessWidget {
  const _FeedSectionHeader({required this.onSeeAllJobsTap});

  final VoidCallback onSeeAllJobsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Bảng tin việc làm',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: onSeeAllJobsTap,
            child: const Text('Xem tất cả'),
          ),
        ],
      ),
    );
  }
}

class _FeedLoadingState extends StatelessWidget {
  const _FeedLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: CircularProgressIndicator(color: Color(0xFF0866FF))),
    );
  }
}

class _FeedErrorState extends StatelessWidget {
  const _FeedErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _DarkNotice(
      icon: Icons.wifi_off_rounded,
      title: 'Không thể tải bảng tin',
      message: 'Vui lòng kiểm tra kết nối rồi thử lại.',
      actionLabel: 'Tải lại',
      onAction: onRetry,
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState({required this.onSeeAllJobsTap});

  final VoidCallback onSeeAllJobsTap;

  @override
  Widget build(BuildContext context) {
    return _DarkNotice(
      icon: Icons.work_outline_rounded,
      title: 'Chưa có bài tuyển dụng',
      message: 'Khi có việc phù hợp, bảng tin sẽ hiển thị ở đây.',
      actionLabel: 'Khám phá công việc',
      onAction: onSeeAllJobsTap,
    );
  }
}

class _DarkNotice extends StatelessWidget {
  const _DarkNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 42),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
