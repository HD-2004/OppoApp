import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/application/auth_controller.dart';
import '../../candidate/data/aws_application_repository.dart';
import '../../candidate/domain/application_repository.dart';
import '../domain/candidate_application.dart';

int countUnreadEmployerMessages(List<ChatMessage> messages, {int? lastReadId}) {
  final lastReadIndex = lastReadId == null
      ? -1
      : messages.lastIndexWhere((message) => message.id == lastReadId);
  final unreadMessages = messages.skip(lastReadIndex + 1);

  return unreadMessages.where(_isEmployerMessage).length;
}

bool _isEmployerMessage(ChatMessage message) {
  final sender = message.sender.trim().toLowerCase();
  return sender == 'me' ||
      sender == 'employer' ||
      sender == 'recruiter' ||
      sender == 'company';
}

bool canDeleteConversation(String status) {
  return status.trim().toLowerCase() == 'completed';
}

class CandidateChatsNotifier extends AsyncNotifier<List<CandidateApplication>> {
  static const _deletedChatsKey = 'deleted_chats';

  Timer? _timer;
  Map<String, int> _lastReadIds = {};
  Set<String> _deletedChatIds = {};

  @override
  FutureOr<List<CandidateApplication>> build() async {
    final authState = ref.watch(authControllerProvider).value;
    final userId = authState?.user?.userId;
    if (userId == null) return [];

    final repository = ref.watch(applicationRepositoryProvider);

    // Load read IDs from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastReadIds = {};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('chat_read_')) {
          final appId = key.replaceFirst('chat_read_', '');
          final val = prefs.getInt(key);
          if (val != null) {
            _lastReadIds[appId] = val;
          }
        }
      }
      _deletedChatIds = prefs.getStringList(_deletedChatsKey)?.toSet() ?? {};
    } catch (_) {}

    _startPolling(userId);

    ref.onDispose(() {
      _timer?.cancel();
    });

    return _fetch(userId, repository);
  }

  void _startPolling(String userId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final repository = ref.read(applicationRepositoryProvider);
      try {
        final data = await _fetch(userId, repository);
        state = AsyncData(data);
      } catch (e) {
        // Keep the old state on error
      }
    });
  }

  Future<List<CandidateApplication>> _fetch(
    String userId,
    ApplicationRepository repo,
  ) async {
    final rawApps = await repo.getCandidateApplications(userId);
    // Filter accepted or completed apps
    final validApps = rawApps.where((app) {
      final status = app['status']?.toString().trim().toLowerCase() ?? '';
      final applicationId = app['applicationId']?.toString() ?? '';
      return (status == 'accepted' || status == 'completed') &&
          !_deletedChatIds.contains(applicationId);
    }).toList();

    // Sort by updatedAt or appliedAt desc
    validApps.sort((a, b) {
      final bTime = b['updatedAt'] ?? b['appliedAt'] ?? '';
      final aTime = a['updatedAt'] ?? a['appliedAt'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });

    return validApps
        .map((json) => CandidateApplication.fromJson(json))
        .toList();
  }

  // Method to mark a chat as read
  Future<void> markAsRead(String applicationId, int lastMessageId) async {
    _lastReadIds[applicationId] = lastMessageId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('chat_read_$applicationId', lastMessageId);
    } catch (_) {}

    // Re-emit state to trigger UI update
    final current = state.value;
    if (current != null) {
      state = AsyncData(List.from(current));
    }
  }

  bool isUnread(CandidateApplication chat) {
    return unreadCount(chat) > 0;
  }

  int unreadCount(CandidateApplication chat) {
    return countUnreadEmployerMessages(
      chat.chatMessages,
      lastReadId: _lastReadIds[chat.applicationId],
    );
  }

  int totalUnreadCount(List<CandidateApplication> chats) {
    return chats.fold<int>(0, (total, chat) => total + unreadCount(chat));
  }

  Future<void> deleteConversation(CandidateApplication chat) async {
    if (!canDeleteConversation(chat.status)) {
      throw StateError(
        'Chỉ có thể xóa cuộc trò chuyện sau khi công việc đã hoàn thành.',
      );
    }

    _deletedChatIds.add(chat.applicationId);
    _lastReadIds.remove(chat.applicationId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _deletedChatsKey,
      _deletedChatIds.toList()..sort(),
    );
    await prefs.remove('chat_read_${chat.applicationId}');

    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current
            .where((item) => item.applicationId != chat.applicationId)
            .toList(),
      );
    }
  }

  Future<void> refresh() async {
    final authState = ref.read(authControllerProvider).value;
    final userId = authState?.user?.userId;
    if (userId == null) return;
    state = const AsyncLoading();
    try {
      final repository = ref.read(applicationRepositoryProvider);
      final data = await _fetch(userId, repository);
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final candidateChatsProvider =
    AsyncNotifierProvider.autoDispose<
      CandidateChatsNotifier,
      List<CandidateApplication>
    >(CandidateChatsNotifier.new);

class ActiveChatNotifier extends AsyncNotifier<List<ChatMessage>> {
  final String applicationId;
  ActiveChatNotifier(this.applicationId);

  Timer? _timer;

  @override
  FutureOr<List<ChatMessage>> build() async {
    final repository = ref.watch(applicationRepositoryProvider);
    final authState = ref.watch(authControllerProvider).value;
    final userId = authState?.user?.userId;

    if (userId == null) return [];

    _startPolling(userId);

    ref.onDispose(() {
      _timer?.cancel();
    });

    final messages = await _fetch(userId, repository);
    if (messages.isNotEmpty) {
      await ref
          .read(candidateChatsProvider.notifier)
          .markAsRead(applicationId, messages.last.id);
    }
    return messages;
  }

  void _startPolling(String userId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final repository = ref.read(applicationRepositoryProvider);
      try {
        final messages = await _fetch(userId, repository);
        state = AsyncData(messages);

        // Auto mark as read if screen is open and there are messages
        if (messages.isNotEmpty) {
          ref
              .read(candidateChatsProvider.notifier)
              .markAsRead(applicationId, messages.last.id);
        }
      } catch (e) {
        // Silent
      }
    });
  }

  Future<List<ChatMessage>> _fetch(
    String userId,
    ApplicationRepository repo,
  ) async {
    final rawApps = await repo.getCandidateApplications(userId);
    final app = rawApps.firstWhere(
      (a) => a['applicationId']?.toString() == applicationId,
      orElse: () => throw Exception('Không tìm thấy cuộc trò chuyện'),
    );

    return CandidateApplication.fromJson(app).chatMessages;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final currentMessages = state.value ?? [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Format time: e.g. "02:30 PM"
    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '${hour.toString().padLeft(2, '0')}:$minute $period';

    // On shared storage, candidate is 'them'
    final newMessage = ChatMessage(
      id: timestamp,
      sender: 'them',
      text: text.trim(),
      time: timeStr,
    );

    final updated = [...currentMessages, newMessage];

    // Optimistic update. Roll back if the shared application API rejects it.
    state = AsyncData(updated);

    final repository = ref.read(applicationRepositoryProvider);
    final authState = ref.read(authControllerProvider).value;
    final userId = authState?.user?.userId;
    if (userId == null) {
      state = AsyncData(currentMessages);
      throw Exception('Vui lòng đăng nhập để gửi tin nhắn.');
    }

    try {
      // Fetch full application to preserve the current workflow status.
      final rawApps = await repository.getCandidateApplications(userId);
      final app = rawApps.firstWhere(
        (a) => a['applicationId']?.toString() == applicationId,
        orElse: () => throw Exception('Không tìm thấy cuộc trò chuyện.'),
      );
      final status = app['status']?.toString() ?? 'accepted';

      await repository.updateApplicationChat(
        applicationId: applicationId,
        status: status,
        chatMessages: updated.map((m) => m.toJson()).toList(),
      );
      ref.invalidate(candidateChatsProvider);
    } catch (_) {
      state = AsyncData(currentMessages);
      rethrow;
    }
  }
}

final activeChatProvider = AsyncNotifierProvider.autoDispose
    .family<ActiveChatNotifier, List<ChatMessage>, String>(
      ActiveChatNotifier.new,
    );
