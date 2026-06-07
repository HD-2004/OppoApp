import 'package:flutter/material.dart';
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
    // 1. Filter out conversations without clear Employer name
    var filteredChats = chats.where((c) {
      final name = c.employerName.trim();
      return name.isNotEmpty &&
          name != '?' &&
          name.toLowerCase() != 'null' &&
          name.toLowerCase() != 'unknown' &&
          name.toLowerCase() != 'anonymous';
    }).toList();

    // 2. Keyword filter
    if (_keyword.trim().isNotEmpty) {
      final kw = _keyword.toLowerCase();
      filteredChats = filteredChats
          .where((c) =>
              c.employerName.toLowerCase().contains(kw) ||
              c.jobTitle.toLowerCase().contains(kw))
          .toList();
    }

    // 3. Tab filter
    if (_selectedTabIndex == 1) {
      // Unread
      filteredChats = filteredChats
          .where((c) => ref.read(candidateChatsProvider.notifier).isUnread(c))
          .toList();
    } else if (_selectedTabIndex == 2) {
      // Đã nhận việc / Completed
      filteredChats = filteredChats.where((c) => c.status == 'completed').toList();
    }

    if (filteredChats.isEmpty) {
      return const _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'Bạn chưa có cuộc trò chuyện nào trong mục này.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredChats.length,
      itemBuilder: (_, i) {
        final chat = filteredChats[i];

        // Tìm JobPost tương thích để lấy các metadata (như logo)
        JobPost? resolvedJob;
        for (final job in [...standardJobs, ...quickJobs]) {
          if (job.idJob == chat.jobId || job.id == chat.jobId) {
            resolvedJob = job;
            break;
          }
        }

        // Tạo fallback JobPost nếu không tìm thấy trong list active jobs
        final job = resolvedJob ??
            JobPost(
              id: chat.jobId,
              idJob: chat.jobId,
              employerId: chat.employerId,
              employerName: chat.employerName,
              title: chat.jobTitle,
              jobType: chat.jobType == 'quick' ? JobPostType.urgent : JobPostType.partTime,
              location: '',
              salary: '',
              shiftTime: '',
              description: '',
              tags: const [],
              postedAt: chat.appliedAt,
              isQuickJob: chat.jobType == 'quick',
            );

        final isUnread = ref.read(candidateChatsProvider.notifier).isUnread(chat);
        final lastMsg = chat.chatMessages.isNotEmpty ? chat.chatMessages.last : null;
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
          lastMessage: previewText,
          lastMessageTime: lastMsg != null
              ? DateTime.fromMillisecondsSinceEpoch(lastMsg.id)
              : chat.updatedAt,
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
          icon: const Icon(Icons.edit_square, color: Color(0xFF1E3A8A)),
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
    required this.onTabSelected,
  });

  final int selectedIndex;
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
            label: 'Chưa đọc',
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
  const _Tab({
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

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
          color: isActive ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF1E3A8A) : const Color(0xFFE5E7EB),
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
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF1E3A8A)),
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
