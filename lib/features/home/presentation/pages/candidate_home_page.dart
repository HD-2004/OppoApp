import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/s3_asset_config.dart';
import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/data/aws_application_repository.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/candidate/presentation/user_job_detail_screen.dart';
import '../../../../features/messaging/presentation/pages/messages_screen.dart';
import '../../../../features/wallet/presentation/controllers/wallet_controller.dart';
import '../../../../shared/presentation/widgets/network_asset_image.dart';
import '../widgets/candidate_menu_drawer.dart';
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
    ref.invalidate(walletControllerProvider);
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
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
      await ref
          .read(applicationRepositoryProvider)
          .submitApplication(
            jobId: job.idJob,
            cvUrl: cvUrl,
            cvFilename: cvFilename,
          );
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage(
        'Ứng tuyển thành công!',
        backgroundColor: const Color(0xFF1E3A8A),
      );
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
      appBar: _HomeAppBar(onNotificationTap: widget.onNotificationTap),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF1E3A8A),
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
              child: HomeHotJobsSection(
                onSeeAll: widget.onSeeAllJobsTap,
                onJobTap: _openJobDetail,
              ),
            ),
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
      floatingActionButton: FloatingActionButton(
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
    );
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HomeAppBar({required this.onNotificationTap});

  final VoidCallback onNotificationTap;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
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
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF1E293B),
            size: 24,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
