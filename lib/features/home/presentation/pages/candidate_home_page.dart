import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/data/aws_application_repository.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/candidate/presentation/user_job_detail_screen.dart';
import '../../../../features/messaging/presentation/pages/messages_screen.dart';
import '../../../../features/wallet/presentation/controllers/wallet_controller.dart';
import '../widgets/home_hot_jobs_section.dart';
import '../widgets/home_latest_jobs_section.dart';

class CandidateHomePage extends ConsumerStatefulWidget {
  const CandidateHomePage({
    super.key,
    required this.onNotificationTap,
    required this.onSeeAllJobsTap,
    required this.onWalletTap,
    required this.onSearchTap,
  });

  final VoidCallback onNotificationTap;
  final VoidCallback onSeeAllJobsTap;
  final VoidCallback onWalletTap;
  final VoidCallback onSearchTap;

  @override
  ConsumerState<CandidateHomePage> createState() => _CandidateHomePageState();
}

class _CandidateHomePageState extends ConsumerState<CandidateHomePage> {
  Future<void> _onRefresh() async {
    ref.invalidate(activeQuickJobsProvider);
    ref.invalidate(activeJobsProvider);
    ref.invalidate(walletControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 600));
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
      if (!mounted) return;
      Navigator.of(context).pop();
      if (cvs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn chưa có CV. Vui lòng tải CV lên trong phần Hồ sơ trước.',
            ),
          ),
        );
      } else {
        _showCVPicker(job, cvs);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải danh sách CV.')),
      );
    }
  }

  void _showCVPicker(JobPost job, List<Map<String, dynamic>> cvs) {
    String? selectedId = cvs.first['id']?.toString();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => AlertDialog(
          title: const Text(
            'Chọn CV ứng tuyển',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cvs.length,
              itemBuilder: (_, i) {
                final cv = cvs[i];
                final id = cv['id']?.toString();
                return RadioListTile<String>(
                  value: id!,
                  groupValue: selectedId,
                  onChanged: (v) => setModal(() => selectedId = v),
                  title: Text(cv['cvFileName']?.toString() ?? 'CV.pdf'),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                final chosen = cvs.firstWhere(
                  (c) => c['id']?.toString() == selectedId,
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
        ),
      ),
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
      await ref
          .read(applicationRepositoryProvider)
          .submitApplication(
            jobId: job.idJob,
            cvUrl: cvUrl,
            cvFilename: cvFilename,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ứng tuyển thành công!'),
          backgroundColor: Color(0xFF1E3A8A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('ALREADY_APPLIED') || msg.contains('đã ứng tuyển')
                ? 'Bạn đã ứng tuyển công việc này rồi!'
                : msg.replaceAll('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _HomeAppBar(onNotificationTap: widget.onNotificationTap),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF1E3A8A),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search bar ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HomeSearchBar(onTap: widget.onSearchTap),
            ),

            // ── Hot Jobs ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: HomeHotJobsSection(
                onSeeAll: widget.onSeeAllJobsTap,
                onJobTap: _openJobDetail,
              ),
            ),

            // ── Công việc mới nhất ──────────────────────────────────────
            SliverToBoxAdapter(
              child: HomeLatestJobsSection(
                onJobTap: _openJobDetail,
                onApplyTap: (job) {
                  final user = ref
                      .read(authControllerProvider)
                      .asData
                      ?.value
                      .user;
                  _handleApply(job, user);
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
      floatingActionButton: _ChatFAB(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

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
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(
          Icons.menu_rounded,
          color: const Color(0xFF1E293B),
          size: 24,
        ),
      ),
      title: const Text(
        'Ốp Pờ',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E3A8A),
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
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

// ── Search bar ────────────────────────────────────────────────────────────────

class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tìm kiếm công việc F&B n...',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                ),
              ),
              Container(
                margin: const EdgeInsets.all(6),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chat FAB ──────────────────────────────────────────────────────────────────

class _ChatFAB extends StatelessWidget {
  const _ChatFAB({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: const Color(0xFF1E3A8A),
      shape: const CircleBorder(),
      tooltip: 'Nhắn tin với nhà tuyển dụng',
      child: const Icon(
        Icons.chat_bubble_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

