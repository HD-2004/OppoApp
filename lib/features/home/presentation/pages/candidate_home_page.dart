import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/application/jobs_providers.dart';
import '../../../../features/candidate/data/aws_application_repository.dart';
import '../../../../features/candidate/domain/job_post.dart';
import '../../../../features/candidate/presentation/user_job_detail_screen.dart';
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
        ).push(MaterialPageRoute(builder: (_) => const _ChatListSheet())),
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

// ── Chat List Sheet ───────────────────────────────────────────────────────────
// UI shell cho chức năng chat giữa ứng viên và nhà tuyển dụng.
// TODO: Kết nối backend real-time (WebSocket / AWS AppSync Subscriptions)
// khi chức năng chat được phát triển đầy đủ.

class _ChatListSheet extends ConsumerWidget {
  const _ChatListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lấy danh sách employer từ jobs thật — mỗi employer là 1 conversation
    final jobsAsync = ref.watch(activeJobsProvider);
    final quickAsync = ref.watch(activeQuickJobsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(color: Color(0xFF1E293B)),
        title: const Text(
          'Tin nhắn',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
            tooltip: 'Soạn tin nhắn mới',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng nhắn tin đang được phát triển.'),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 12),
                  Icon(
                    Icons.search_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Tìm kiếm cuộc trò chuyện...',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Conversation list — derive từ employers của jobs thật
          Expanded(
            child: jobsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const _ChatEmptyState(
                icon: Icons.wifi_off_rounded,
                message: 'Không tải được danh sách.',
              ),
              data: (standardJobs) {
                return quickAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      _buildConversationList(context, standardJobs),
                  data: (quickJobs) => _buildConversationList(context, [
                    ...standardJobs,
                    ...quickJobs,
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(BuildContext context, List<JobPost> jobs) {
    // Group theo employerId — mỗi employer = 1 conversation thread
    final seen = <String>{};
    final employers = <JobPost>[];
    for (final job in jobs) {
      if (job.employerId.isNotEmpty && seen.add(job.employerId)) {
        employers.add(job);
      }
    }

    if (employers.isEmpty) {
      return const _ChatEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'Bạn chưa có cuộc trò chuyện nào.\nỨng tuyển để bắt đầu!',
      );
    }

    return ListView.separated(
      itemCount: employers.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 80, color: Color(0xFFF3F4F6)),
      itemBuilder: (_, i) => _ConversationTile(
        job: employers[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _ChatRoomScreen(employer: employers[i]),
          ),
        ),
      ),
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.job, required this.onTap});

  final JobPost job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = job.companyName ?? job.employerName;
    final avatarUrl = job.employerAvatarUrl;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFFDBEAFE),
        backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? NetworkImage(avatarUrl)
            : null,
        child: (avatarUrl == null || avatarUrl.isEmpty)
            ? Text(
                initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                  fontSize: 16,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Color(0xFF111827),
        ),
      ),
      subtitle: Text(
        job.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

// ── Chat room screen ──────────────────────────────────────────────────────────
// UI shell — sẵn sàng để kết nối WebSocket / AppSync Subscriptions.
// TODO: Implement real-time messaging với AWS AppSync hoặc API Gateway WebSocket.

class _ChatRoomScreen extends StatefulWidget {
  const _ChatRoomScreen({required this.employer});

  final JobPost employer;

  @override
  State<_ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<_ChatRoomScreen> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String get _employerName =>
      widget.employer.companyName ?? widget.employer.employerName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: const BackButton(color: Color(0xFF1E293B)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFDBEAFE),
              backgroundImage:
                  (widget.employer.employerAvatarUrl != null &&
                      widget.employer.employerAvatarUrl!.isNotEmpty)
                  ? NetworkImage(widget.employer.employerAvatarUrl!)
                  : null,
              child:
                  (widget.employer.employerAvatarUrl == null ||
                      widget.employer.employerAvatarUrl!.isEmpty)
                  ? Text(
                      _employerName.isNotEmpty
                          ? _employerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _employerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Nhà tuyển dụng',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF6B7280),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages area — empty state vì chưa có backend chat
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF1E3A8A),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bắt đầu trò chuyện với\n$_employerName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhắn tin để hỏi về công việc\nhoặc lịch phỏng vấn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // TODO badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.construction_rounded,
                          size: 14,
                          color: Color(0xFFD97706),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tính năng đang phát triển',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Input bar — UI shell
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Attachment button
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: Color(0xFF9CA3AF),
                    ),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // Text input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _inputController,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Nhắn tin...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tính năng nhắn tin đang được phát triển.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E3A8A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chat empty state ──────────────────────────────────────────────────────────

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: const Color(0xFFD1D5DB)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
