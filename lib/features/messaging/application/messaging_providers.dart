import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/application/auth_controller.dart';
import '../../candidate/data/aws_application_repository.dart';
import '../../candidate/domain/application_repository.dart';
import '../domain/candidate_application.dart';

const candidateChatAvailabilityMessage =
    'Bạn cần bật trạng thái Sẵn sàng làm việc để sử dụng Chatting.';
const chatCompletedMessage =
    'Cuộc trò chuyện đã kết thúc vì ca làm đã hoàn thành.';

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

bool canArchiveConversation(String status) {
  return status.trim().toLowerCase() == 'completed';
}

bool canDeleteConversation(String status) => canArchiveConversation(status);

String? candidateChatAccessMessage({
  required bool isSignedIn,
  bool isActive = true,
}) {
  if (!isSignedIn) return 'login_required';
  if (!isActive) return 'availability_off';
  return null;
}

String chatAccessUiMessage(String code) {
  return switch (code) {
    'login_required' => 'Vui lòng đăng nhập để sử dụng Chatting.',
    'availability_off' => candidateChatAvailabilityMessage,
    'chat_completed' => chatCompletedMessage,
    _ => 'Không thể mở cuộc trò chuyện này.',
  };
}

bool isVisibleInCandidateChatList(Map<String, dynamic> app) {
  final status = app['status']?.toString().trim().toLowerCase() ?? '';
  if (status != 'accepted') return false;
  return !_isClosedChatRecord(app);
}

bool _isClosedChatRecord(Map<String, dynamic> app) {
  final status = app['status']?.toString().trim().toLowerCase() ?? '';
  final chatStatus = app['chatStatus']?.toString().trim().toLowerCase() ?? '';
  const closedStatuses = {'completed', 'archived', 'deleted'};
  return closedStatuses.contains(status) ||
      closedStatuses.contains(chatStatus) ||
      _hasValue(app['archivedAt']) ||
      _hasValue(app['chatArchivedAt']) ||
      _hasValue(app['closedAt']) ||
      _hasValue(app['chatClosedAt']) ||
      _hasValue(app['deletedAt']);
}

bool _hasValue(Object? value) => value?.toString().trim().isNotEmpty == true;

class ChatAccessException implements Exception {
  const ChatAccessException(this.code);

  final String code;

  @override
  String toString() => chatAccessUiMessage(code);
}

class CandidateChatsNotifier extends AsyncNotifier<List<CandidateApplication>> {
  static const _standardJobsUrl =
      'https://dlidp35x33.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _quickJobsUrl =
      'https://6zw89pkuxb.execute-api.ap-southeast-1.amazonaws.com/prod';
  static final Map<String, Map<String, dynamic>?> _jobDetailsCache = {};

  Timer? _timer;
  Map<String, int> _lastReadIds = {};

  @override
  FutureOr<List<CandidateApplication>> build() async {
    final authState = ref.watch(authControllerProvider).value;
    final user = authState?.user;
    final accessCode = candidateChatAccessMessage(
      isSignedIn: user != null,
      isActive: user?.isActive == true,
    );
    if (accessCode == 'login_required') return [];
    if (accessCode != null) {
      throw ChatAccessException(accessCode);
    }

    final userId = user!.userId;

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

    // Clean up preferences for completed apps
    try {
      final completedApps = rawApps.where((app) {
        return app['status']?.toString().trim().toLowerCase() == 'completed';
      });
      if (completedApps.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        for (final app in completedApps) {
          final appId = app['applicationId']?.toString() ?? '';
          if (appId.isNotEmpty) {
            await prefs.remove('chat_read_$appId');
          }
        }
      }
    } catch (_) {}

    final validRawApps = rawApps.where(isVisibleInCandidateChatList).toList();

    final List<Map<String, dynamic>> enrichedApps = [];

    for (final app in validRawApps) {
      final jobId = app['jobId']?.toString() ?? app['idJob']?.toString() ?? app['jobID']?.toString() ?? '';
      if (jobId.isEmpty) {
        enrichedApps.add(app);
        continue;
      }

      Map<String, dynamic>? jobData;
      if (_jobDetailsCache.containsKey(jobId)) {
        jobData = _jobDetailsCache[jobId];
      } else {
        final isQuick = jobId.startsWith('QJOB-');
        final url = isQuick
            ? '$_quickJobsUrl/quick-jobs/$jobId'
            : '$_standardJobsUrl/jobs/$jobId';
        try {
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic> && decoded['success'] == true) {
              final data = decoded['data'];
              if (data is Map<String, dynamic>) {
                jobData = data;
                _jobDetailsCache[jobId] = data;
              } else {
                _jobDetailsCache[jobId] = null;
              }
            } else {
              _jobDetailsCache[jobId] = null;
            }
          } else if (response.statusCode == 404) {
            _jobDetailsCache[jobId] = null;
          }
        } catch (_) {
          // Temporarily skip on network errors to avoid caching null permanently,
          // but do not add to current tick so we don't display a broken tile.
        }
      }

      // If the job is confirmed deleted (cached as null), filter out
      if (_jobDetailsCache.containsKey(jobId) && _jobDetailsCache[jobId] == null) {
        continue;
      }

      final enrichedApp = Map<String, dynamic>.from(app);
      if (jobData != null) {
        final companyName = jobData['employerName'] ?? jobData['companyName'] ?? jobData['employerEmail'] ?? '';
        final title = jobData['title'] ?? '';
        String? logo = jobData['companyLogo'] ?? jobData['employerAvatarUrl'] ?? jobData['logoUrl'] ?? jobData['avatarUrl'] ?? jobData['profileImage'];
        if (logo == null || logo.trim().isEmpty) {
          logo = 'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/system/katinatlogo.jpg';
        }

        if (companyName.toString().trim().isNotEmpty && companyName.toString().trim().toLowerCase() != 'none') {
          enrichedApp['employerName'] = companyName.toString().trim();
        }
        if (title.toString().trim().isNotEmpty) {
          enrichedApp['jobTitle'] = title.toString().trim();
        }
        enrichedApp['employerAvatarUrl'] = logo;
      }

      // Handle fallback and clean up "None" values in employerName
      final currentEmpName = enrichedApp['employerName']?.toString() ?? '';
      if (currentEmpName.isEmpty || currentEmpName.toLowerCase() == 'none') {
        final email = enrichedApp['employerEmail']?.toString() ?? '';
        if (email.toLowerCase().contains('hr.oppo')) {
          enrichedApp['employerName'] = 'Công ty cổ phần cafe Katinat';
        } else if (email.toLowerCase().contains('quangnhm')) {
          enrichedApp['employerName'] = 'Katinat Quận Cam';
        } else if (email.toLowerCase().contains('hieudh')) {
          enrichedApp['employerName'] = 'Công ty cổ phần cafe August';
        } else if (email.toLowerCase().contains('hd.sg.0011')) {
          enrichedApp['employerName'] = 'Highlands Coffee';
        } else {
          enrichedApp['employerName'] = 'Nhà tuyển dụng';
        }
      }

      if (enrichedApp['employerAvatarUrl'] == null) {
        final empName = enrichedApp['employerName']?.toString().toLowerCase() ?? '';
        if (empName.contains('katinat')) {
          enrichedApp['employerAvatarUrl'] = 'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/system/katinatlogo.jpg';
        } else if (empName.contains('august')) {
          enrichedApp['employerAvatarUrl'] = 'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/system/bamos.png';
        } else if (empName.contains('highlands')) {
          enrichedApp['employerAvatarUrl'] = 'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/system/highlands.jpg';
        } else {
          enrichedApp['employerAvatarUrl'] = 'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/system/katinatlogo.jpg';
        }
      }
      enrichedApps.add(enrichedApp);
    }

    // Sort by updatedAt or appliedAt desc
    enrichedApps.sort((a, b) {
      final bTime = b['updatedAt'] ?? b['appliedAt'] ?? '';
      final aTime = a['updatedAt'] ?? a['appliedAt'] ?? '';
      return bTime.toString().compareTo(aTime.toString());
    });

    return enrichedApps
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

  Future<void> archiveConversation(CandidateApplication chat) async {
    if (!canArchiveConversation(chat.status)) {
      throw StateError(
        'Chỉ có thể lưu trữ cuộc trò chuyện sau khi công việc đã hoàn thành.',
      );
    }

    final repository = ref.read(applicationRepositoryProvider);
    await repository.archiveApplicationChat(
      applicationId: chat.applicationId,
      archivedAt: DateTime.now(),
    );

    _lastReadIds.remove(chat.applicationId);

    final prefs = await SharedPreferences.getInstance();
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

  Future<void> deleteConversation(CandidateApplication chat) {
    return archiveConversation(chat);
  }

  Future<void> refresh() async {
    final authState = ref.read(authControllerProvider).value;
    final user = authState?.user;
    final accessCode = candidateChatAccessMessage(
      isSignedIn: user != null,
      isActive: user?.isActive == true,
    );
    if (accessCode == 'login_required') return;
    if (accessCode != null) {
      state = AsyncError(ChatAccessException(accessCode), StackTrace.current);
      return;
    }

    final userId = user!.userId;
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
    final user = authState?.user;
    final accessCode = candidateChatAccessMessage(
      isSignedIn: user != null,
      isActive: user?.isActive == true,
    );

    if (accessCode == 'login_required') return [];
    if (accessCode != null) {
      throw ChatAccessException(accessCode);
    }

    final userId = user!.userId;
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
    if (_isClosedChatRecord(app)) {
      throw const ChatAccessException('chat_completed');
    }

    return CandidateApplication.fromJson(app).chatMessages;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final authState = ref.read(authControllerProvider).value;
    final user = authState?.user;
    final accessCode = candidateChatAccessMessage(
      isSignedIn: user != null,
      isActive: user?.isActive == true,
    );
    if (accessCode != null) {
      throw ChatAccessException(accessCode);
    }

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
    final userId = user!.userId;

    try {
      // Fetch full application to preserve the current workflow status.
      final rawApps = await repository.getCandidateApplications(userId);
      final app = rawApps.firstWhere(
        (a) => a['applicationId']?.toString() == applicationId,
        orElse: () => throw Exception('Không tìm thấy cuộc trò chuyện.'),
      );
      if (_isClosedChatRecord(app)) {
        throw const ChatAccessException('chat_completed');
      }
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
