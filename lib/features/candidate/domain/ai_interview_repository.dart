import 'ai_interview_models.dart';

abstract class AiInterviewRepository {
  Future<CvScreeningResult> screenCv({
    required String jobDescription,
    required String cvText,
    String? cvUrl,
  });

  Future<InterviewStartResult> startInterview({
    required String jobTitle,
    required String jobDescription,
    required String cvText,
    String? cvUrl,
    List<String> customQuestions = const [],
  });

  Future<InterviewAnswerResult> respondInterview({
    required String sessionId,
    required String answer,
  });
}

class AiInterviewException implements Exception {
  const AiInterviewException(this.message, {this.code = 'AI_INTERVIEW_ERROR'});

  final String message;
  final String code;

  @override
  String toString() => message;
}
