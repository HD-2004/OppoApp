import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/application_repository.dart';

void main() {
  test('builds the same candidate completion payload as web', () {
    final confirmedAt = DateTime.parse('2026-06-09T10:30:00+07:00');

    expect(buildCompletionConfirmationPayload(confirmedAt), {
      'status': 'completed',
      'candidateConfirmed': true,
      'candidateConfirmedAt': '2026-06-09T03:30:00.000Z',
      'chatStatus': 'archived',
      'chatArchivedAt': '2026-06-09T03:30:00.000Z',
      'chatClosedAt': '2026-06-09T03:30:00.000Z',
    });
  });

  test('builds a soft archive payload for completed chat threads', () {
    final archivedAt = DateTime.parse('2026-06-14T15:45:00+07:00');

    expect(buildChatArchivePayload(archivedAt), {
      'status': 'archived',
      'chatStatus': 'archived',
      'archivedAt': '2026-06-14T08:45:00.000Z',
      'chatArchivedAt': '2026-06-14T08:45:00.000Z',
      'closedAt': '2026-06-14T08:45:00.000Z',
      'chatClosedAt': '2026-06-14T08:45:00.000Z',
    });
  });

  test('builds the same candidate employer rating payload as web', () {
    final candidateRating = {
      'overall': 5,
      'environment': 4,
      'attitude': 5,
      'accuracy': 4,
      'comment': 'Môi trường làm việc tốt.',
    };

    expect(buildCandidateRatingPayload(candidateRating), {
      'status': 'completed',
      'candidateRating': candidateRating,
    });
  });

  test('builds the same employer application notification payload as web', () {
    final payload =
        AwsApplicationRepository.buildEmployerApplicationNotification(
          jobId: 'job-1',
          details: const ApplicationNotificationDetails(
            employerId: 'employer-1',
            candidateId: 'candidate-1',
            candidateName: 'Nguyễn An',
            jobTitle: 'Nhân viên phục vụ',
            companyName: 'Quán Cà Phê',
            isQuickJob: false,
          ),
        );

    expect(payload['type'], 'application');
    expect(payload['recipientId'], 'employer-1');
    expect(payload['recipientRole'], 'employer');
    expect(payload['senderId'], 'candidate-1');
    expect(payload['actionUrl'], '/employer/standard-jobs');
    expect(payload['data'], {
      'jobId': 'job-1',
      'jobTitle': 'Nhân viên phục vụ',
      'companyName': 'Quán Cà Phê',
      'candidateId': 'candidate-1',
      'candidateName': 'Nguyễn An',
      'isQuickJob': false,
    });
  });

  test('builds application status payload with AI interview fields', () {
    final report = {
      'total_score': 72,
      'strengths': ['Thái độ tốt'],
      'weaknesses': ['Cần quen ca cao điểm'],
      'recommend_to_employer': true,
      'reason': 'Ứng viên phù hợp.',
    };

    expect(
      buildApplicationStatusPayload(
        status: 'approved',
        extraFields: {'aiInterviewScore': 72, 'aiInterviewReport': report},
      ),
      {
        'status': 'approved',
        'aiInterviewScore': 72,
        'aiInterviewReport': report,
      },
    );
  });
}
