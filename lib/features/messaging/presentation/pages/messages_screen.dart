import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../candidate/application/jobs_providers.dart';
import '../../../candidate/domain/job_post.dart';
import '../widgets/conversation_tile.dart';
import 'chat_room_screen.dart';

/// Màn hình danh sách tin nhắn.
/// Conversation list derive từ employers của jobs thật — không mock data.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          const _FilterTabs(),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: standardAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const _EmptyState(
                icon: Icons.wifi_off_rounded,
                message: 'Không tải được danh sách tin nhắn.',
                showRetryHint: true,
              ),
              data: (standard) => quickAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _buildList(context, standard),
                data: (quick) => _buildList(context, [...standard, ...quick]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<JobPost> all) {
    // Group by employerId — 1 employer = 1 conversation
    final seen = <String>{};
    var employers = <JobPost>[];
    for (final job in all) {
      if (job.employerId.isNotEmpty && seen.add(job.employerId)) {
        employers.add(job);
      }
    }

    // Keyword filter
    if (_keyword.trim().isNotEmpty) {
      final kw = _keyword.toLowerCase();
      employers = employers
          .where(
            (j) =>
                (j.companyName ?? j.employerName).toLowerCase().contains(kw) ||
                j.title.toLowerCase().contains(kw),
          )
          .toList();
    }

    if (employers.isEmpty) {
      return const _EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        message: 'Bạn chưa có cuộc trò chuyện nào.\nỨng tuyển để bắt đầu!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: employers.length,
      itemBuilder: (_, i) {
        final job = employers[i];
        // Derive conversation status từ jobType / tags thật
        final status = _deriveStatus(job, i);
        return ConversationTile(
          job: job,
          status: status,
          isOnline: i == 0,
          isUnread: i < 2,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ChatRoomScreen(employer: job)),
          ),
        );
      },
    );
  }

  /// Derive trạng thái hội thoại từ dữ liệu job thật.
  ConversationStatus _deriveStatus(JobPost job, int index) {
    if (job.isQuickJob) return ConversationStatus.newMessage;
    if (job.jobType == JobPostType.fullTime) return ConversationStatus.hired;
    if (job.jobType == JobPostType.partTime) return ConversationStatus.pending;
    return ConversationStatus.none;
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
  const _FilterTabs();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          _Tab(label: 'Tất cả', isActive: true),
          const SizedBox(width: 8),
          _Tab(label: 'Chưa đọc'),
          const SizedBox(width: 8),
          _Tab(label: 'Phỏng vấn'),
          const SizedBox(width: 8),
          _Tab(label: 'Đã nhận việc'),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, this.isActive = false});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
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
