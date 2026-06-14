import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_user_profile.dart';
import '../../../candidate/application/jobs_providers.dart';
import '../../../candidate/data/aws_application_repository.dart';
import '../../../candidate/domain/application_repository.dart';
import '../../../candidate/domain/job_post.dart';
import '../../../candidate/notifications/application/notification_controller.dart';
import '../../../candidate/presentation/user_job_detail_screen.dart';
import '../../../employer_packages/application/featured_employer_package_providers.dart';
import '../../../employer_packages/domain/employer_package.dart';
import '../../../messaging/application/messaging_providers.dart';
import '../../../messaging/presentation/pages/messages_screen.dart';
import '../../../recommendations/application/job_recommendation_providers.dart';
import '../../../recommendations/domain/job_recommendation.dart';
import '../widgets/candidate_home_marketplace_sections.dart';
import '../widgets/candidate_menu_drawer.dart';

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
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(activeQuickJobsProvider);
    ref.invalidate(activeJobsProvider);
    ref.invalidate(featuredEmployersProvider);
    ref.invalidate(personalizedJobRecommendationsProvider);

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
      ref
          .read(featuredEmployersProvider.future)
          .catchError((_) => const <FeaturedEmployer>[]),
      ref
          .read(personalizedJobRecommendationsProvider.future)
          .catchError((_) => const <JobRecommendation>[]),
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

  Future<void> _handleApply(JobPost job, AuthUserProfile? user) async {
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
    final recommendationsAsync = ref.watch(
      personalizedJobRecommendationsProvider,
    );
    final featuredEmployersAsync = ref.watch(featuredEmployersProvider);
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
    final filteredJobs = _filterJobs(allJobs, _keyword);
    final filteredRecommendations = _filterRecommendations(
      recommendationsAsync.value ?? const <JobRecommendation>[],
      _keyword,
    );
    final topCompanies = _buildCompanyRanking(filteredJobs);
    final dataLoading =
        (standardJobsAsync.isLoading || quickJobsAsync.isLoading) &&
        allJobs.isEmpty;
    final dataError =
        (standardJobsAsync.hasError || quickJobsAsync.hasError) &&
        allJobs.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background(context),
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
                  searchController: _searchController,
                  onSearchChanged: (value) {
                    setState(() => _keyword = value);
                  },
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
                child: GenZFeedSection(
                  jobs: filteredJobs.take(6).toList(growable: false),
                  isLoading: dataLoading,
                  hasError: dataError,
                  onRetry: () {
                    ref.invalidate(activeJobsProvider);
                    ref.invalidate(activeQuickJobsProvider);
                  },
                  onSeeAll: widget.onSeeAllJobsTap,
                  onJobTap: _openJobDetail,
                  onApply: (job) => _handleApply(job, user),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PageWidth(
                child: RecommendedJobsSection(
                  recommendations: filteredRecommendations
                      .take(6)
                      .toList(growable: false),
                  isLoading: recommendationsAsync.isLoading,
                  hasError: recommendationsAsync.hasError,
                  onRetry: () =>
                      ref.invalidate(personalizedJobRecommendationsProvider),
                  onSeeAll: widget.onSeeAllJobsTap,
                  onJobTap: _openJobDetail,
                  onApply: (job) => _handleApply(job, user),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PageWidth(
                child: SponsoredBannerSection(
                  employers:
                      featuredEmployersAsync.value ??
                      const <FeaturedEmployer>[],
                  isLoading: featuredEmployersAsync.isLoading,
                  onViewJobs: widget.onSeeAllJobsTap,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PageWidth(
                child: TopCompaniesSection(
                  companies: topCompanies.take(5).toList(growable: false),
                  isLoading: dataLoading,
                  onSeeAll: widget.onSeeAllJobsTap,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _PageWidth(
                child: DirectionJobsSection(
                  jobs: filteredJobs.take(8).toList(growable: false),
                  isLoading: dataLoading,
                  hasError: dataError,
                  onRetry: () {
                    ref.invalidate(activeJobsProvider);
                    ref.invalidate(activeQuickJobsProvider);
                  },
                  onSeeAll: widget.onSeeAllJobsTap,
                  onJobTap: _openJobDetail,
                  onApply: (job) => _handleApply(job, user),
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

  List<JobPost> _filterJobs(List<JobPost> jobs, String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return jobs;
    return jobs
        .where((job) {
          final haystack = [
            job.title,
            job.description,
            job.employerName,
            job.companyName ?? '',
            job.location,
            job.salary,
            job.shiftTime,
            job.tags.join(' '),
          ].join(' ').toLowerCase();
          return haystack.contains(normalized);
        })
        .toList(growable: false);
  }

  List<JobRecommendation> _filterRecommendations(
    List<JobRecommendation> recommendations,
    String keyword,
  ) {
    final normalized = keyword.trim().toLowerCase();
    if (normalized.isEmpty) return recommendations;
    return recommendations
        .where((item) {
          final job = item.job;
          final haystack = [
            job.title,
            job.description,
            job.employerName,
            job.companyName ?? '',
            job.location,
            job.salary,
            job.shiftTime,
            job.tags.join(' '),
          ].join(' ').toLowerCase();
          return haystack.contains(normalized);
        })
        .toList(growable: false);
  }

  List<CompanyRankItem> _buildCompanyRanking(List<JobPost> jobs) {
    final grouped = <String, _CompanyBucket>{};
    for (final job in jobs) {
      final name = companyNameOf(job);
      final key = job.employerId.trim().isNotEmpty
          ? job.employerId.trim()
          : name.toLowerCase();
      grouped.update(
        key,
        (bucket) => bucket.copyWith(count: bucket.count + 1),
        ifAbsent: () => _CompanyBucket(
          name: name,
          logoUrl: job.employerAvatarUrl,
          count: 1,
        ),
      );
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) {
        final countComparison = b.count.compareTo(a.count);
        if (countComparison != 0) return countComparison;
        return a.name.compareTo(b.name);
      });

    return [
      for (var index = 0; index < sorted.length; index++)
        CompanyRankItem(
          rank: index + 1,
          name: sorted[index].name,
          logoUrl: sorted[index].logoUrl,
          activeJobCount: sorted[index].count,
        ),
    ];
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

class _CompanyBucket {
  const _CompanyBucket({required this.name, required this.count, this.logoUrl});

  final String name;
  final int count;
  final String? logoUrl;

  _CompanyBucket copyWith({int? count}) {
    return _CompanyBucket(
      name: name,
      count: count ?? this.count,
      logoUrl: logoUrl,
    );
  }
}
