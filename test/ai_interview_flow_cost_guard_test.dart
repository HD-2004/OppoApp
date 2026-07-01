import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/ai_interview_models.dart';

bool shouldCreateApplicationAfterScreening(CvScreeningResult result) {
  return result.canContinueToInterview;
}

bool shouldApproveApplicationAfterInterview(InterviewReport? report) {
  return report?.isPassed == true;
}

void main() {
  test('Round 1 fail does not create application', () {
    final result = CvScreeningResult.fromJson({
      'score': 0,
      'result': 'fail',
      'strengths': <String>[],
      'weaknesses': ['Không phải CV'],
      'reason': 'Tài liệu không hợp lệ.',
    });

    expect(shouldCreateApplicationAfterScreening(result), isFalse);
  });

  test('Round 1 pass and review create application', () {
    final pass = CvScreeningResult.fromJson({
      'score': 80,
      'result': 'pass',
      'strengths': <String>[],
      'weaknesses': <String>[],
      'reason': 'Đạt.',
    });
    final review = CvScreeningResult.fromJson({
      'score': 60,
      'result': 'review',
      'strengths': <String>[],
      'weaknesses': <String>[],
      'reason': 'Cần xem xét.',
    });

    expect(shouldCreateApplicationAfterScreening(pass), isTrue);
    expect(shouldCreateApplicationAfterScreening(review), isTrue);
  });

  test('Round 2 only approves when website threshold passes', () {
    final failed = InterviewReport.fromJson({
      'total_score': 59,
      'strengths': <String>[],
      'weaknesses': <String>[],
      'recommend_to_employer': false,
      'reason': 'Chưa đạt.',
    });
    final passed = InterviewReport.fromJson({
      'total_score': 60,
      'strengths': <String>[],
      'weaknesses': <String>[],
      'recommend_to_employer': false,
      'reason': 'Đạt ngưỡng.',
    });

    expect(shouldApproveApplicationAfterInterview(failed), isFalse);
    expect(shouldApproveApplicationAfterInterview(passed), isTrue);
  });
}
