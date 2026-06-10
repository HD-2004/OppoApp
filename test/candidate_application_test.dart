import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';

void main() {
  test('maps web application chat schema and preserves database order', () {
    final application = CandidateApplication.fromJson({
      'applicationId': 'APP-1',
      'jobId': 'QJOB-1',
      'companyName': 'Katinat Quận Cam',
      'status': 'ACCEPTED',
      'appliedAt': '2026-06-09T08:00:00Z',
      'chatMessages': [
        {'id': 2, 'sender': 'them', 'text': 'Em chào anh', 'time': '03:01 PM'},
        {'id': 1, 'sender': 'me', 'text': 'Xin chào', 'time': '03:00 PM'},
      ],
    });

    expect(application.employerName, 'Katinat Quận Cam');
    expect(application.status, 'accepted');
    expect(application.chatMessages.map((message) => message.id), [2, 1]);
    expect(application.chatMessages.last.sender, 'me');
  });

  test('maps message aliases returned by compatible chat records', () {
    final message = ChatMessage.fromJson({
      'messageId': '1717920000000',
      'sender': 'me',
      'message': 'Đã nhận được tin nhắn',
      'sentAt': '10:30 AM',
    });

    expect(message.id, 1717920000000);
    expect(message.text, 'Đã nhận được tin nhắn');
    expect(message.time, '10:30 AM');
  });
}
