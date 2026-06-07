import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../candidate/domain/job_post.dart';
import '../../application/messaging_providers.dart';
import '../../domain/candidate_application.dart';

/// Màn hình phòng chat của Candidate.
/// Nhận tin nhắn trong thời gian thực (sync 3 giây) từ DynamoDB qua API & Lambda.
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.applicationId,
    required this.employer,
  });

  final String applicationId;
  final JobPost employer;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _scrollToBottomAnimated() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String get _name =>
      widget.employer.companyName ?? widget.employer.employerName;

  String get _avatarUrl => widget.employer.employerAvatarUrl ?? '';

  @override
  Widget build(BuildContext context) {
    // Watch active chat messages
    final messagesAsync = ref.watch(activeChatProvider(widget.applicationId));

    // Listen for updates to automatically scroll down
    ref.listen(activeChatProvider(widget.applicationId), (prev, next) {
      if (next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomAnimated();
        });
      }
    });

    // Check status of the application
    final chats = ref.watch(candidateChatsProvider).value ?? [];
    final currentApp = chats.firstWhere(
      (a) => a.applicationId == widget.applicationId,
      orElse: () => CandidateApplication(
        applicationId: widget.applicationId,
        jobId: widget.employer.id,
        jobTitle: widget.employer.title,
        jobType: widget.employer.isQuickJob ? 'quick' : 'standard',
        candidateId: '',
        candidateEmail: '',
        employerId: widget.employer.employerId,
        employerEmail: '',
        employerName: _name,
        status: 'accepted',
        appliedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        chatMessages: [],
      ),
    );
    final isCompleted = currentApp.status == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: _ChatAppBar(
        name: _name,
        avatarUrl: _avatarUrl,
        isOnline: true,
        isCompleted: isCompleted,
      ),
      body: Column(
        children: [
          // ── Messages area ─────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Lỗi tải tin nhắn: $err'),
              ),
              data: (messages) => _MessagesArea(
                messages: messages,
                scrollController: _scrollController,
                name: _name,
                avatarUrl: _avatarUrl,
                isCompleted: isCompleted,
              ),
            ),
          ),

          // ── Input bar ─────────────────────────────────────────
          _InputBar(
            controller: _inputController,
            isCompleted: isCompleted,
            onSend: () async {
              final text = _inputController.text;
              if (text.trim().isEmpty) return;

              _inputController.clear();
              try {
                await ref
                    .read(activeChatProvider(widget.applicationId).notifier)
                    .sendMessage(text);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Không gửi được tin nhắn: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
    this.isCompleted = false,
  });

  final String name;
  final String avatarUrl;
  final bool isOnline;
  final bool isCompleted;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: const BackButton(color: Color(0xFF1E293B)),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: avatarUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _AvatarFallback(name: name),
                        ),
                      )
                    : _AvatarFallback(name: name),
              ),
              if (isOnline && !isCompleted)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF9CA3AF)),
                    ]
                  ],
                ),
                Text(
                  isCompleted
                      ? 'Công việc đã kết thúc'
                      : (isOnline ? 'Đang hoạt động' : 'Nhà tuyển dụng'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isCompleted
                        ? const Color(0xFF9CA3AF)
                        : (isOnline
                            ? const Color(0xFF22C55E)
                            : const Color(0xFF9CA3AF)),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.phone_outlined,
            color: Color(0xFF1E3A8A),
            size: 22,
          ),
          onPressed: isCompleted ? null : () {},
        ),
        IconButton(
          icon: const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF6B7280),
            size: 22,
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Messages area ─────────────────────────────────────────────────────────────

class _MessagesArea extends StatelessWidget {
  const _MessagesArea({
    required this.messages,
    required this.scrollController,
    required this.name,
    required this.avatarUrl,
    required this.isCompleted,
  });

  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final String name;
  final String avatarUrl;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length + (isCompleted ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _buildCompletedBanner();
        }

        final message = messages[index];
        final isMe = message.sender == 'them'; // candidate is 'them' (me in the app)

        return _buildMessageRow(message, isMe);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF1E3A8A),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bắt đầu trò chuyện\nvới $name',
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
        ],
      ),
    );
  }

  Widget _buildCompletedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hội thoại đã kết thúc do công việc đã hoàn thành.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _SmallAvatar(avatarUrl: avatarUrl, name: name),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF1E3A8A) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border:
                        isMe ? null : Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : const Color(0xFF111827),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.time,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 32),
          if (!isMe) const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.avatarUrl, required this.name});

  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: avatarUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _Initial(name: name),
              ),
            )
          : _Initial(name: name),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    this.isCompleted = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.attach_file_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
            onPressed: isCompleted ? null : () {},
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                enabled: !isCompleted,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isCompleted
                      ? 'Hội thoại đã kết thúc và bị khóa'
                      : 'Nhắn tin...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isCompleted ? null : onSend,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF9CA3AF) : const Color(0xFF1E3A8A),
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
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
