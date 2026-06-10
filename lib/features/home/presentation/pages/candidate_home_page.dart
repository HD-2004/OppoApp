import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/data/aws_application_repository.dart';
import '../../../../features/candidate/domain/application_repository.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/candidate/notifications/application/notification_controller.dart';
import '../../../../features/candidate/presentation/user_job_detail_screen.dart';
import '../../../../features/employer_packages/application/featured_employer_package_providers.dart';
import '../../../../features/employer_packages/presentation/widgets/featured_employer_banner.dart';
import '../../../../features/employer_packages/presentation/widgets/featured_employer_section.dart';
import '../../../../features/messaging/application/messaging_providers.dart';
import '../../../../features/messaging/presentation/pages/messages_screen.dart';
import '../../../../features/wallet/presentation/controllers/wallet_controller.dart';
import '../../../../shared/presentation/widgets/network_asset_image.dart';
import '../widgets/candidate_menu_drawer.dart';
import '../widgets/home_current_job_section.dart';
import '../widgets/home_hot_jobs_section.dart';
import '../widgets/home_latest_jobs_section.dart';
import '../widgets/home_s3_banner_carousel.dart';
import '../widgets/home_side_poster.dart';

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

  void _openCurrentJobDetail(JobPost job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserJobDetailScreen(
          job: job,
          onApplyPressed: () {},
          showApplyButton: false,
        ),
      ),
    );
  }

  Future<void> _confirmCurrentJobCompletion(HomeCurrentJob current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF10B981),
          size: 34,
        ),
        title: const Text('Xác nhận hoàn thành'),
        content: Text(
          'Bạn xác nhận đã hoàn thành công việc "${current.job.title}"? '
          'Sau khi xác nhận, cuộc trò chuyện sẽ được khóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(applicationRepositoryProvider)
          .confirmApplicationCompletion(
            applicationId: current.applicationId,
            confirmedAt: DateTime.now(),
          );
      if (!mounted) return;

      final userId = ref
          .read(authControllerProvider)
          .asData
          ?.value
          .user
          ?.userId;
      if (userId != null) {
        ref.invalidate(candidateHomeApplicationsProvider(userId));
      }
      ref.invalidate(candidateChatsProvider);
      ref.invalidate(walletControllerProvider);
      _showMessage(
        'Đã xác nhận hoàn thành công việc.',
        backgroundColor: const Color(0xFF10B981),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _rateCurrentJobEmployer(HomeCurrentJob current) async {
    final rating = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmployerRatingDialog(
        companyName: current.job.companyName ?? current.job.employerName,
      ),
    );
    if (rating == null || !mounted) return;

    try {
      await ref
          .read(applicationRepositoryProvider)
          .submitCandidateRating(
            applicationId: current.applicationId,
            candidateRating: rating,
          );
      if (!mounted) return;

      final userId = ref
          .read(authControllerProvider)
          .asData
          ?.value
          .user
          ?.userId;
      if (userId != null) {
        ref.invalidate(candidateHomeApplicationsProvider(userId));
      }
      ref.invalidate(candidateChatsProvider);
      _showMessage(
        'Đã gửi đánh giá. Công việc đã hoàn thành.',
        backgroundColor: const Color(0xFF10B981),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        backgroundColor: Colors.red,
      );
    }
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
    final chats = ref.watch(candidateChatsProvider);
    final unreadMessageCount = chats.value == null
        ? 0
        : ref
              .read(candidateChatsProvider.notifier)
              .totalUnreadCount(chats.value!);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      appBar: _HomeAppBar(onNotificationTap: widget.onNotificationTap),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return const HomeS3BannerCarousel();
                  }
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: HomeS3BannerCarousel()),
                      SizedBox(width: 240, child: HomeSidePoster()),
                    ],
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: FeaturedEmployerBanner(onViewJobs: widget.onSeeAllJobsTap),
            ),
            SliverToBoxAdapter(
              child: HomeCurrentJobSection(
                userId: user?.userId,
                onDetails: _openCurrentJobDetail,
                onConfirmCompletion: _confirmCurrentJobCompletion,
                onRateEmployer: _rateCurrentJobEmployer,
              ),
            ),
            SliverToBoxAdapter(
              child: HomeHotJobsSection(
                onSeeAll: widget.onSeeAllJobsTap,
                onJobTap: _openJobDetail,
              ),
            ),

            SliverToBoxAdapter(
              child: FeaturedEmployerSection(
                onViewJobs: widget.onSeeAllJobsTap,
              ),
            ),

            // ── Công việc mới nhất ──────────────────────────────────────
            SliverToBoxAdapter(
              child: HomeLatestJobsSection(
                onJobTap: _openJobDetail,
                onApplyTap: (job) {
                  final currentUser = ref
                      .read(authControllerProvider)
                      .asData
                      ?.value
                      .user;
                  _handleApply(job, currentUser);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        children: [
          FloatingActionButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            backgroundColor: const Color(0xFF1E3A8A),
            shape: const CircleBorder(),
            tooltip: 'Nhắn tin với nhà tuyển dụng',
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (unreadMessageCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: _ChatUnreadBadge(count: unreadMessageCount),
            ),
        ],
      ),
    );
  }
}

class _EmployerRatingDialog extends StatefulWidget {
  const _EmployerRatingDialog({required this.companyName});

  final String companyName;

  @override
  State<_EmployerRatingDialog> createState() => _EmployerRatingDialogState();
}

class _EmployerRatingDialogState extends State<_EmployerRatingDialog> {
  final _commentController = TextEditingController();
  final Map<String, int> _ratings = {
    'overall': 0,
    'environment': 0,
    'attitude': 0,
    'accuracy': 0,
  };

  bool get _canSubmit => _ratings.values.every((rating) => rating > 0);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(<String, dynamic>{
      ..._ratings,
      'comment': _commentController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Đánh Giá Nhà Tuyển Dụng',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.companyName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy đánh giá đầy đủ các tiêu chí để hoàn tất công việc.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _RatingCategory(
                icon: Icons.star_rounded,
                label: 'Đánh giá tổng quan',
                value: _ratings['overall']!,
                highlighted: true,
                onChanged: (value) =>
                    setState(() => _ratings['overall'] = value),
              ),
              _RatingCategory(
                icon: Icons.business_rounded,
                label: 'Môi trường làm việc',
                value: _ratings['environment']!,
                onChanged: (value) =>
                    setState(() => _ratings['environment'] = value),
              ),
              _RatingCategory(
                icon: Icons.groups_2_outlined,
                label: 'Thái độ nhà tuyển dụng',
                value: _ratings['attitude']!,
                onChanged: (value) =>
                    setState(() => _ratings['attitude'] = value),
              ),
              _RatingCategory(
                icon: Icons.fact_check_outlined,
                label: 'Công việc đúng với mô tả',
                value: _ratings['accuracy']!,
                onChanged: (value) =>
                    setState(() => _ratings['accuracy'] = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Nhận xét của bạn',
                  hintText: 'Chia sẻ trải nghiệm làm việc của bạn...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 72),
                    child: Icon(Icons.edit_outlined),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Để sau'),
        ),
        FilledButton.icon(
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: const Text('Gửi đánh giá'),
        ),
      ],
    );
  }
}

class _RatingCategory extends StatelessWidget {
  const _RatingCategory({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF7E6) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFF6C86E)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: highlighted
                    ? const Color(0xFFD97706)
                    : const Color(0xFF1E3A8A),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(),
                  tooltip: '$star sao',
                  onPressed: () => onChanged(star),
                  icon: Icon(
                    star <= value
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 30,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatUnreadBadge extends StatelessWidget {
  const _ChatUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HomeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.onNotificationTap});

  final VoidCallback onNotificationTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final unreadCount =
        ref
            .watch(candidateNotificationControllerProvider)
            .asData
            ?.value
            .summary
            .unread ??
        0;

    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CandidateMenuButton(),
      titleSpacing: 4,
      title: const SizedBox(
        width: 92,
        height: 44,
        child: NetworkAssetImage(
          url: S3AssetConfig.logo,
          fit: BoxFit.contain,
          semanticLabel: 'Logo Ốp Pờ',
          placeholder: SizedBox.shrink(),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onNotificationTap,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF1E293B),
                size: 24,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -7,
                  right: -9,
                  child: IgnorePointer(
                    child: _NotificationUnreadBadge(count: unreadCount),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _NotificationUnreadBadge extends StatelessWidget {
  const _NotificationUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
