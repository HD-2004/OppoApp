import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/ai_interview_models.dart';

void main() {
  test('parses CV screening response from shared cv-ai contract', () {
    final result = CvScreeningResult.fromJson({
      'score': 85,
      'result': 'pass',
      'strengths': ['Giao tiếp tốt'],
      'weaknesses': ['Cần học quy trình quán'],
      'reason': 'Phù hợp với vị trí phục vụ.',
    });

    expect(result.score, 85);
    expect(result.result, 'pass');
    expect(result.isFailed, isFalse);
    expect(result.canContinueToInterview, isTrue);
    expect(result.strengths, ['Giao tiếp tốt']);
    expect(result.weaknesses, ['Cần học quy trình quán']);
    expect(result.reason, 'Phù hợp với vị trí phục vụ.');
  });

  test(
    'treats review screening result as eligible for application creation',
    () {
      final result = CvScreeningResult.fromJson({
        'score': 61,
        'result': 'review',
        'strengths': <String>[],
        'weaknesses': <String>[],
        'reason': 'Cần xem xét thêm.',
      });

      expect(result.canContinueToInterview, isTrue);
    },
  );

  test('builds website-compatible mock screening fallback', () {
    final result = CvScreeningResult.websiteMockFallback(jobTitle: 'Phục vụ');

    expect(result.score, greaterThanOrEqualTo(60));
    expect(result.result, 'review');
    expect(result.canContinueToInterview, isTrue);
    expect(result.reason, contains('Phục vụ'));
    expect(result.toApplicationExtraFields()['aiScreeningResult'], 'review');
  });

  test('parses unfinished and finished interview responses', () {
    final next = InterviewAnswerResult.fromJson({
      'question': 'Bạn xử lý khách phàn nàn như thế nào?',
      'finished': false,
      'report': null,
    });
    expect(next.finished, isFalse);
    expect(next.question, 'Bạn xử lý khách phàn nàn như thế nào?');
    expect(next.report, isNull);

    final done = InterviewAnswerResult.fromJson({
      'question': null,
      'finished': true,
      'report': {
        'total_score': 72,
        'past_experience_score': 70,
        'situation_handling_score': 74,
        'operations_score': 73,
        'custom_questions_score': 71,
        'strengths': ['Thái độ tốt'],
        'weaknesses': ['Cần quen ca cao điểm'],
        'recommend_to_employer': true,
        'reason': 'Ứng viên phù hợp.',
      },
    });

    expect(done.finished, isTrue);
    expect(done.report?.totalScore, 72);
    expect(done.report?.isPassed, isTrue);
    expect(done.report?.pastExperienceScore, 70);
    expect(done.report?.toJson()['total_score'], 72);
  });

  test('uses website pass threshold of 60 for interview reports', () {
    final report = InterviewReport.fromJson({
      'total_score': 60,
      'strengths': <String>[],
      'weaknesses': <String>[],
      'recommend_to_employer': false,
      'reason': 'Đạt ngưỡng tối thiểu.',
    });

    expect(report.isPassed, isTrue);
  });

  test('builds website-compatible mock interview fallback', () {
    final start = InterviewStartResult.websiteMockFallback(jobTitle: 'Phục vụ');

    expect(start.sessionId, mockInterviewSessionId);
    expect(start.question, contains('Phục vụ'));

    final next = InterviewAnswerResult.websiteMockFallback(
      answeredQuestionNumber: 1,
      companyName: 'Katinat',
    );

    expect(next.finished, isFalse);
    expect(next.question, contains('khách hàng phàn nàn'));
    expect(next.report, isNull);

    final done = InterviewAnswerResult.websiteMockFallback(
      answeredQuestionNumber: 3,
      companyName: 'Katinat',
    );

    expect(done.finished, isTrue);
    expect(done.question, isNull);
    expect(done.report?.isPassed, isTrue);
    expect(done.report?.reason, contains('Katinat'));
  });
}
