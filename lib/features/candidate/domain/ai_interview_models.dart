class CvScreeningResult {
  const CvScreeningResult({
    required this.score,
    required this.result,
    required this.strengths,
    required this.weaknesses,
    required this.reason,
  });

  factory CvScreeningResult.fromJson(Map<String, dynamic> json) {
    final result = _string(json['result']);
    return CvScreeningResult(
      score: _int(json['score']).clamp(0, 100),
      result: result.isEmpty ? 'review' : result,
      strengths: _stringList(json['strengths']),
      weaknesses: _stringList(json['weaknesses']),
      reason: _string(json['reason']),
    );
  }

  final int score;
  final String result;
  final List<String> strengths;
  final List<String> weaknesses;
  final String reason;

  bool get isFailed => result.toLowerCase().trim() == 'fail';
  bool get canContinueToInterview => !isFailed;

  Map<String, dynamic> toApplicationExtraFields() {
    return {
      'aiScreeningScore': score,
      'aiScreeningResult': result,
      'aiScreeningReason': reason,
      'aiScreeningStrengths': strengths,
      'aiScreeningWeaknesses': weaknesses,
    };
  }
}

class InterviewStartResult {
  const InterviewStartResult({required this.sessionId, required this.question});

  factory InterviewStartResult.fromJson(Map<String, dynamic> json) {
    return InterviewStartResult(
      sessionId: _string(json['session_id']),
      question: _string(json['question']),
    );
  }

  final String sessionId;
  final String question;
}

class InterviewAnswerResult {
  const InterviewAnswerResult({
    required this.question,
    required this.finished,
    required this.report,
  });

  factory InterviewAnswerResult.fromJson(Map<String, dynamic> json) {
    final rawReport = json['report'];
    return InterviewAnswerResult(
      question: _nullableString(json['question']),
      finished: json['finished'] == true,
      report: rawReport is Map
          ? InterviewReport.fromJson(Map<String, dynamic>.from(rawReport))
          : null,
    );
  }

  final String? question;
  final bool finished;
  final InterviewReport? report;
}

class InterviewReport {
  const InterviewReport({
    required this.totalScore,
    required this.strengths,
    required this.weaknesses,
    required this.recommendToEmployer,
    required this.reason,
    this.pastExperienceScore,
    this.situationHandlingScore,
    this.operationsScore,
    this.customQuestionsScore,
  });

  factory InterviewReport.fromJson(Map<String, dynamic> json) {
    return InterviewReport(
      totalScore: _int(json['total_score']).clamp(0, 100),
      pastExperienceScore: _nullableInt(json['past_experience_score']),
      situationHandlingScore: _nullableInt(json['situation_handling_score']),
      operationsScore: _nullableInt(json['operations_score']),
      customQuestionsScore: _nullableInt(json['custom_questions_score']),
      strengths: _stringList(json['strengths']),
      weaknesses: _stringList(json['weaknesses']),
      recommendToEmployer: json['recommend_to_employer'] == true,
      reason: _string(json['reason']),
    );
  }

  final int totalScore;
  final int? pastExperienceScore;
  final int? situationHandlingScore;
  final int? operationsScore;
  final int? customQuestionsScore;
  final List<String> strengths;
  final List<String> weaknesses;
  final bool recommendToEmployer;
  final String reason;

  bool get isPassed => recommendToEmployer || totalScore >= 60;

  Map<String, dynamic> toJson() {
    return {
      'total_score': totalScore,
      if (pastExperienceScore != null)
        'past_experience_score': pastExperienceScore,
      if (situationHandlingScore != null)
        'situation_handling_score': situationHandlingScore,
      if (operationsScore != null) 'operations_score': operationsScore,
      if (customQuestionsScore != null)
        'custom_questions_score': customQuestionsScore,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'recommend_to_employer': recommendToEmployer,
      'reason': reason,
    };
  }
}

String _string(dynamic value) => value?.toString().trim() ?? '';

String? _nullableString(dynamic value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value));
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}
