import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../candidate/application/jobs_providers.dart';
import '../../../candidate/domain/job_post.dart';
import '../../application/messaging_providers.dart';
import '../../domain/candidate_application.dart';
import '../widgets/conversation_tile.dart';
import 'chat_room_screen.dart';

/// Màn hình danh sách tin nhắn của Candidate.
/// Dữ liệu được đồng bộ trực tiếp từ DynamoDB thông qua API & Lambda dùng chung với web.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _keyword = '';
  int _selectedTabIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(candidateChatsProvider);
    final standardAsync = ref.watch(activeJobsProvider);
    final quickAsync = ref.watch(activeQuickJobsProvider);
    final unreadTotal = chatsAsync.value == null
        ? 0
        : ref
              .read(candidateChatsProvider.notifier)
              .totalUnreadCount(chatsAsync.value!);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: _MessagesAppBar(
        onCompose: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tính năng soạn tin nhắn đang phát triển.'),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────
          _SearchBar(
            controller: _searchController,
            onChanged: (v) => setState(() => _keyword = v),
            onClear: () => setState(() {
              _searchController.clear();
              _keyword = '';
            }),
          ),

          // ── Filter tabs ────────────────────────────────────────────
          _FilterTabs(
            selectedIndex: _selectedTabIndex,
            unreadCount: unreadTotal,
            onTabSelected: (idx) => setState(() => _selectedTabIndex = idx),
          ),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: chatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _EmptyState(
                icon: err is ChatAccessException
                    ? Icons.lock_outline_rounded
                    : Icons.wifi_off_rounded,
                message: err is ChatAccessException
                    ? err.toString()
                    : 'Không tải được danh sách tin nhắn.',
                showRetryHint: err is! ChatAccessException,
              ),
              data: (chats) => _buildList(
                context,
                chats,
                standardAsync.value ?? [],
                quickAsync.value ?? [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<CandidateApplication> chats,
    List<JobPost> standardJobs,
    List<JobPost> quickJobs,
  ) {
    final allJobs = [...standardJobs, ...quickJobs];
    var conversations = chats
        .map(
          (chat) => _ResolvedConversation(
            chat: chat,
            job: _resolveJob(chat, allJobs),
          ),
        )
        .toList();

    // Job records are the source of truth for company/title, matching the web.
    if (_keyword.trim().isNotEmpty) {
      final kw = _keyword.toLowerCase();
      conversations = conversations
          .where(
            (item) =>
                item.companyName.toLowerCase().contains(kw) ||
                item.jobTitle.toLowerCase().contains(kw),
          )
          .toList();
    }

    if (_selectedTabIndex == 1) {
      conversations = conversations
          .where(
            (item) =>
                ref.read(candidateChatsProvider.notifier).isUnread(item.chat),
          )
          .toList();
    }

    if (conversations.isEmpty) {
      return const _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'Bạn chưa có cuộc trò chuyện nào trong mục này.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: conversations.length,
      itemBuilder: (_, i) {
        final conversation = conversations[i];
        final chat = conversation.chat;
        final job = conversation.job;

        final isUnread = ref
            .read(candidateChatsProvider.notifier)
            .isUnread(chat);
        final unreadCount = ref
            .read(candidateChatsProvider.notifier)
            .unreadCount(chat);
        final lastMsg = chat.chatMessages.isNotEmpty
            ? chat.chatMessages.last
            : null;
        final previewText = lastMsg != null
            ? (lastMsg.sender == 'them' ? 'Bạn: ${lastMsg.text}' : lastMsg.text)
            : 'Bắt đầu cuộc trò chuyện...';

        final status = chat.status == 'completed'
            ? ConversationStatus.hired
            : ConversationStatus.none;

        return ConversationTile(
          job: job,
          status: status,
          isOnline: i == 0,
          isUnread: isUnread,
          unreadCount: unreadCount,
          lastMessage: previewText,
          lastMessageTime: lastMsg != null
              ? DateTime.fromMillisecondsSinceEpoch(lastMsg.id)
              : chat.updatedAt,
          canDelete: canArchiveConversation(chat.status),
          onDelete: () => _requestArchiveConversation(chat),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                applicationId: chat.applicationId,
                employer: job,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestArchiveConversation(CandidateApplication chat) async {
    if (!canArchiveConversation(chat.status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuộc trò chuyện đang được sử dụng. Bạn chỉ có thể lưu trữ sau khi công việc hoàn thành.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.archive_outlined,
          color: AppColors.danger,
          size: 32,
        ),
        title: const Text('Lưu trữ cuộc trò chuyện'),
        content: const Text(
          'Cuộc trò chuyện sẽ được ẩn khỏi danh sách mặc định nhưng vẫn giữ dữ liệu cho audit/hỗ trợ khi cần.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(candidateChatsProvider.notifier).archiveConversation(chat);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  JobPost _resolveJob(CandidateApplication chat, List<JobPost> jobs) {
    for (final job in jobs) {
      if (job.idJob == chat.jobId || job.id == chat.jobId) {
        return job;
      }
    }

    final employerName = chat.employerName.trim().isNotEmpty
        ? chat.employerName.trim()
        : 'Nhà tuyển dụng';
    final title = chat.jobTitle.trim().isNotEmpty
        ? chat.jobTitle.trim()
        : 'Công việc';
    final isQuick = chat.jobType == 'quick' || chat.jobId.startsWith('QJOB-');

    return JobPost(
      id: chat.jobId,
      idJob: chat.jobId,
      employerId: chat.employerId,
      employerName: employerName,
      companyName: employerName,
      title: title,
      jobType: isQuick ? JobPostType.urgent : JobPostType.partTime,
      location: '',
      salary: '',
      shiftTime: '',
      description: '',
      tags: const [],
      postedAt: chat.appliedAt,
      isQuickJob: isQuick,
    );
  }
}

class _ResolvedConversation {
  const _ResolvedConversation({required this.chat, required this.job});

  final CandidateApplication chat;
  final JobPost job;

  String get companyName => job.companyName ?? job.employerName;
  String get jobTitle => job.title;
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _MessagesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MessagesAppBar({required this.onCompose});

  final VoidCallback onCompose;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface(context),
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Text(
        'Tin nhắn',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimaryFor(context),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_square, color: AppColors.primary),
          onPressed: onCompose,
          tooltip: 'Soạn tin nhắn',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.fieldFill(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search_rounded,
              color: AppColors.disabledFor(context),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cuộc trò chuyện...',
                  hintStyle: TextStyle(
                    color: AppColors.disabledFor(context),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.disabledFor(context),
                  ),
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

// ── Filter tabs ───────────────────────────────────────────────────────────────

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _Tab(
            label: 'Tất cả',
            isActive: selectedIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: unreadCount > 0 ? 'Chưa đọc ($unreadCount)' : 'Chưa đọc',
            isActive: selectedIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.onTap, this.isActive = false});

  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.borderFor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textPrimaryFor(context),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.showRetryHint = false,
  });

  final IconData icon;
  final String message;
  final bool showRetryHint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryFor(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
