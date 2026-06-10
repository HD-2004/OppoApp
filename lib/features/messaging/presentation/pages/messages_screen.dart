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
      backgroundColor: const Color(0xFFF7F8FC),
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
              error: (err, _) => const _EmptyState(
                icon: Icons.wifi_off_rounded,
                message: 'Không tải được danh sách tin nhắn.',
                showRetryHint: true,
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
    } else if (_selectedTabIndex == 2) {
      conversations = conversations
          .where((item) => item.chat.status == 'completed')
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
          canDelete: canDeleteConversation(chat.status),
          onDelete: () => _requestDeleteConversation(chat),
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

  Future<void> _requestDeleteConversation(CandidateApplication chat) async {
    if (!canDeleteConversation(chat.status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuộc trò chuyện đang được sử dụng. Bạn chỉ có thể xóa sau khi công việc hoàn thành.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFDC2626),
          size: 32,
        ),
        title: const Text('Xóa cuộc trò chuyện'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa cuộc trò chuyện này khỏi danh sách không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(candidateChatsProvider.notifier).deleteConversation(chat);
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
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: const Text(
        'Tin nhắn',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Color(0xFF111827),
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
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF9CA3AF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm cuộc trò chuyện...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF9CA3AF),
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
          _Tab(
            label: 'Đã nhận việc',
            isActive: selectedIndex == 2,
            onTap: () => onTabSelected(2),
          ),
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
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF374151),
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
