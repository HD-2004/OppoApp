import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/messaging/application/messaging_providers.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';

void main() {
  test('counts only unread messages sent by employer', () {
    final messages = [
      ChatMessage(id: 1, sender: 'me', text: 'Tin cũ', time: '08:00 AM'),
      ChatMessage(id: 2, sender: 'them', text: 'Ứng viên', time: '08:01 AM'),
      ChatMessage(id: 3, sender: 'me', text: 'Tin mới 1', time: '08:02 AM'),
      ChatMessage(id: 4, sender: 'me', text: 'Tin mới 2', time: '08:03 AM'),
    ];

    expect(countUnreadEmployerMessages(messages, lastReadId: 1), 2);
    expect(countUnreadEmployerMessages(messages, lastReadId: 4), 0);
  });

  test('supports backend employer sender aliases', () {
    final messages = [
      ChatMessage(id: 10, sender: 'them', text: 'Candidate', time: '08:00 AM'),
      ChatMessage(
        id: 11,
        sender: 'employer',
        text: 'Employer',
        time: '08:01 AM',
      ),
      ChatMessage(
        id: 12,
        sender: 'recruiter',
        text: 'Recruiter',
        time: '08:02 AM',
      ),
    ];

    expect(countUnreadEmployerMessages(messages, lastReadId: 10), 2);
  });

  test('uses message order when ids are duplicated', () {
    final messages = [
      ChatMessage(id: 20, sender: 'me', text: 'Read', time: '08:00 AM'),
      ChatMessage(id: 20, sender: 'them', text: 'Candidate', time: '08:01 AM'),
      ChatMessage(id: 21, sender: 'me', text: 'Unread', time: '08:02 AM'),
    ];

    expect(countUnreadEmployerMessages(messages, lastReadId: 20), 1);
  });

  test('does not depend on clocks being synchronized between devices', () {
    final messages = [
      ChatMessage(id: 100, sender: 'them', text: 'Read', time: '08:00 AM'),
      ChatMessage(
        id: 90,
        sender: 'me',
        text: 'New employer message',
        time: '08:01 AM',
      ),
    ];

    expect(countUnreadEmployerMessages(messages, lastReadId: 100), 1);
  });

  test('allows archiving conversations only after the job is completed', () {
    expect(canArchiveConversation('accepted'), isFalse);
    expect(canArchiveConversation('completed_pending_candidate'), isFalse);
    expect(canArchiveConversation(' COMPLETED '), isTrue);
  });

  test('default candidate chat list excludes closed conversations', () {
    expect(isVisibleInCandidateChatList({'status': 'accepted'}), isTrue);
    expect(isVisibleInCandidateChatList({'status': 'pending'}), isFalse);
    expect(isVisibleInCandidateChatList({'status': 'completed'}), isFalse);
    expect(isVisibleInCandidateChatList({'status': 'archived'}), isFalse);
    expect(isVisibleInCandidateChatList({'status': 'deleted'}), isFalse);
    expect(
      isVisibleInCandidateChatList({
        'status': 'accepted',
        'chatStatus': 'archived',
      }),
      isFalse,
    );
    expect(
      isVisibleInCandidateChatList({
        'status': 'accepted',
        'archivedAt': '2026-06-14T10:00:00.000Z',
      }),
      isFalse,
    );
  });

  test('chat access requires sign-in and active availability only', () {
    expect(candidateChatAccessMessage(isSignedIn: false), 'login_required');
    expect(
      candidateChatAccessMessage(isSignedIn: true, isActive: false),
      'availability_off',
    );
    expect(
      candidateChatAccessMessage(isSignedIn: true, isActive: true),
      isNull,
    );
  });
}
