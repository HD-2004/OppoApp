import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_user_profile.dart';
import '../../../candidate/application/jobs_providers.dart';
import '../../../candidate/data/aws_application_repository.dart';
import '../../../candidate/domain/job_post.dart';
import '../../../candidate/notifications/application/notification_controller.dart';
import '../../../candidate/presentation/application_flow_navigation.dart';
import '../../../candidate/presentation/user_job_detail_screen.dart';
import '../../../employer_packages/application/featured_employer_package_providers.dart';
import '../../../employer_packages/domain/employer_package.dart';
import '../../../jobs/application/popular_jobs.dart';
import '../../../messaging/application/messaging_providers.dart';
import '../../../messaging/domain/candidate_application.dart';
import '../../../messaging/presentation/pages/messages_screen.dart';
import '../widgets/candidate_home_marketplace_sections.dart';
import '../widgets/candidate_menu_drawer.dart';

final candidateRecentApplicationsProvider =
    FutureProvider.autoDispose<List<CandidateApplication>>((ref) async {
      final user = ref.watch(authControllerProvider).asData?.value.user;
      if (user == null) return const <CandidateApplication>[];

      final repository = ref.watch(applicationRepositoryProvider);
      final rawApplications = await repository.getCandidateApplications(
        user.userId,
      );
      final applications = rawApplications
          .whereType<Map>()
          .map(
            (item) =>
                CandidateApplication.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      applications.sort((a, b) {
        final updatedComparison = b.updatedAt.compareTo(a.updatedAt);
        if (updatedComparison != 0) return updatedComparison;
        return b.appliedAt.compareTo(a.appliedAt);
      });
      return applications;
    });

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
    ref.invalidate(bannersProvider);
    ref.invalidate(candidateRecentApplicationsProvider);

    final userId = ref.read(authControllerProvider).asData?.value.user?.userId;
    if (userId != null) {
      ref.invalidate(candidateChatsProvider);
      ref
          .read(candidateNotificationControllerProvider.notifier)
          .refreshNotifications();
    }

    await Future.wait([
      ref.read(activeJobsProvider.future).catchError((_) => const <JobPost>[]),
      ref
          .read(activeQuickJobsProvider.future)
          .catchError((_) => const <JobPost>[]),
      ref.read(bannersProvider.future).catchError((_) => const <BannerAd>[]),
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

  /// Opens the recruiting post linked to a tapped banner. The job is resolved
  /// from real, already-loaded job data — never fabricated. If the banner has
  /// no resolvable job, the user is informed instead of showing fake content.
  void _openBannerJob(BannerAd banner, List<JobPost> allJobs) {
    final jobId = banner.jobId?.trim() ?? '';
    final employerId = banner.employerId?.trim() ?? '';

    JobPost? match;
    if (jobId.isNotEmpty) {
      for (final job in allJobs) {
        if (job.idJob == jobId || job.id == jobId) {
          match = job;
          break;
        }
      }
    }
    // Fall back to the employer's most recent active post when the banner only
    // links a company (still real data, just a broader target).
    if (match == null && employerId.isNotEmpty) {
      for (final job in allJobs) {
        if (job.employerId == employerId) {
          match = job;
          break;
        }
      }
    }

    if (match != null) {
      _openJobDetail(match);
      return;
    }

    _showMessage('Tin tuyển dụng cho banner này hiện không khả dụng.');
  }

  void _openRecentApplication(
    CandidateApplication application,
    List<JobPost> allJobs,
  ) {
    for (final job in allJobs) {
      if (job.id == application.jobId || job.idJob == application.jobId) {
        _openJobDetail(job);
        return;
      }
    }

    _showMessage('Tin tuyển dụng cho đơn này hiện không khả dụng.');
  }

  Future<void> _handleApply(JobPost job, AuthUserProfile? user) async {
    if (user == null) {
      _showMessage('Vui lòng đăng nhập để ứng tuyển.');
      return;
    }

    _showLoading();
    try {
      // Check if an existing application already exists → skip CV picker
      final handled = await checkExistingApplicationBeforeApply(
        context: context,
        ref: ref,
        job: job,
        user: user,
      );
      if (!mounted) return;
      if (handled) {
        Navigator.of(context).pop(); // Dismiss loading
        return;
      }

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
                  : () async {
                      Navigator.pop(dialogContext);
                      final chosen = cvs.firstWhere(
                        (cv) => cv['id']?.toString() == selectedId,
                      );
                      final cvUrl =
                          chosen['cvUrl']?.toString() ??
                          chosen['cvS3Key']?.toString() ??
                          '';
                      final cvFilename =
                          chosen['cvFileName']?.toString() ?? 'CV.pdf';
                      final cvS3Key = chosen['cvS3Key']?.toString();

                      if (job.isAiScreeningEnabled) {
                        final flowUser = ref
                            .read(authControllerProvider)
                            .asData
                            ?.value
                            .user;
                        if (flowUser == null) {
                          _showMessage('Vui lòng đăng nhập để ứng tuyển.');
                          return;
                        }
                        await openAiApplicationFlow(
                          context: context,
                          ref: ref,
                          job: job,
                          user: flowUser,
                          selectedCvUrl: cvUrl,
                          selectedCvFilename: cvFilename,
                          selectedCvS3Key: cvS3Key,
                        );
                      } else {
                        _submitApplication(
                          job,
                          cvUrl,
                          cvFilename,
                          cvS3Key: cvS3Key,
                        );
                      }
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
    String cvFilename, {
    String? cvS3Key,
  }) async {
    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) {
      _showMessage('Vui lòng đăng nhập để ứng tuyển.');
      return;
    }

    await submitApplicationWithBackgroundEval(
      context: context,
      ref: ref,
      job: job,
      user: user,
      cvUrl: cvUrl,
      cvFilename: cvFilename,
      cvS3Key: cvS3Key,
      onSuccess: () {
        if (mounted) {
          _showMessage('Ứng tuyển thành công!', backgroundColor: AppColors.primary);
        }
      },
      onError: (msg) async {
        if (!mounted) return;
        if (msg.contains('ALREADY_APPLIED') ||
            msg.contains('already applied') ||
            msg.contains('đã ứng tuyển')) {
          final openedInterview =
              await openExistingAiInterviewForDuplicateApplication(
                context: context,
                ref: ref,
                job: job,
                user: user,
                selectedCvUrl: cvUrl,
                selectedCvFilename: cvFilename,
                selectedCvS3Key: cvS3Key,
              );
          if (openedInterview || !mounted) return;
          _showMessage('Bạn đã ứng tuyển công việc này rồi!', backgroundColor: Colors.red);
        } else {
          _showMessage(msg.replaceAll('Exception: ', ''), backgroundColor: Colors.red);
        }
      },
    );
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
    final bannersAsync = ref.watch(bannersProvider);
    final recentApplicationsAsync = ref.watch(
      candidateRecentApplicationsProvider,
    );
    final notificationCount =
        ref
            .watch(candidateNotificationControllerProvider)
            .asData
            ?.value
            .summary
            .unread ??
        0;
    final chats = ref.watch(candidateChatsProvider).asData?.value;
    final chatCount = chats == null
        ? 0
        : ref.read(candidateChatsProvider.notifier).totalUnreadCount(chats);

    final allJobs = _uniqueJobs([
      ...(quickJobsAsync.value ?? const <JobPost>[]),
      ...(standardJobsAsync.value ?? const <JobPost>[]),
    ]);
    final popularJobs = sortJobsByPopularity(
      allJobs,
    ).take(6).toList(growable: false);
    final dataLoading =
        (standardJobsAsync.isLoading || quickJobsAsync.isLoading) &&
        allJobs.isEmpty;
    final jobsError = standardJobsAsync.hasError && quickJobsAsync.hasError;
    return Scaffold(
      backgroundColor: AppColors.background(context),
      drawer: CandidateMenuDrawer(
        displayName: displayName,
        email: email,
        profileImage: user?.profileImage,
        currentDestination: CandidateMenuDestination.home,
        onHomeTap: () => Navigator.of(context).pop(),
        onProfileTap: () => _closeDrawerAndRun(widget.onProfileTap),
        onJobsTap: () => _closeDrawerAndRun(widget.onJobsTap),
        onWalletTap: () => _closeDrawerAndRun(widget.onWalletTap),
        onNotificationsTap: () => _closeDrawerAndRun(widget.onNotificationTap),
        onSettingsTap: () => _closeDrawerAndRun(widget.onSettingsTap),
        onSupportTap: () => _closeDrawerAndRun(widget.onSupportTap),
        onSignOutTap: () => _closeDrawerAndRun(widget.onSignOutTap),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _PageWidth(
                child: HomeHeader(
                  displayName: displayName,
                  onNotificationTap: widget.onNotificationTap,
                  onChatTap: () {
                    if (user?.isActive != true) {
                      _showMessage(candidateChatAvailabilityMessage);
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MessagesScreen()),
                    );
                  },
                  notificationCount: notificationCount,
                  chatCount: chatCount,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PageWidth(
                child: SponsoredBannerSection(
                  banners: bannersAsync.value ?? const <BannerAd>[],
                  isLoading: bannersAsync.isLoading,
                  onBannerTap: (banner) => _openBannerJob(banner, allJobs),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PageWidth(
                child: PopularJobsSection(
                  jobs: popularJobs,
                  isLoading: dataLoading,
                  hasError: jobsError,
                  onRetry: () {
                    ref.invalidate(activeQuickJobsProvider);
                    ref.invalidate(activeJobsProvider);
                  },
                  onSeeAll: widget.onSeeAllJobsTap,
                  onJobTap: _openJobDetail,
                  onApply: (job) => _handleApply(job, user),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PageWidth(
                child: RecentApplicationsSection(
                  applications:
                      (recentApplicationsAsync.value ??
                              const <CandidateApplication>[])
                          .take(5)
                          .toList(growable: false),
                  isLoading:
                      recentApplicationsAsync.isLoading &&
                      !recentApplicationsAsync.hasValue,
                  onApplicationTap: (application) =>
                      _openRecentApplication(application, allJobs),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 92)),
          ],
        ),
      ),
    );
  }

  List<JobPost> _uniqueJobs(List<JobPost> jobs) {
    final byId = <String, JobPost>{for (final job in jobs) job.id: job};
    final unique = byId.values.toList(growable: false);
    return sortJobsByVisibilityThenCreatedAt(unique);
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: child,
      ),
    );
  }
}
