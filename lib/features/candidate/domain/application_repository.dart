class ApplicationNotificationDetails {
  const ApplicationNotificationDetails({
    required this.employerId,
    required this.candidateId,
    required this.candidateName,
    required this.jobTitle,
    required this.companyName,
    required this.isQuickJob,
  });

  final String employerId;
  final String candidateId;
  final String candidateName;
  final String jobTitle;
  final String companyName;
  final bool isQuickJob;
}

class ExistingAiInterviewContinuation {
  const ExistingAiInterviewContinuation({
    required this.applicationId,
    required this.cvUrl,
    required this.cvFilename,
    this.cvS3Key,
    required this.aiScreeningScore,
    required this.aiScreeningResult,
    required this.aiScreeningReason,
  });

  final String applicationId;
  final String cvUrl;
  final String cvFilename;
  final String? cvS3Key;
  final int aiScreeningScore;
  final String aiScreeningResult;
  final String aiScreeningReason;
}

abstract class ApplicationRepository {
  Future<List<Map<String, dynamic>>> getCandidateCVs(String userId);
  Future<Map<String, dynamic>> uploadCandidateCV({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
  });
  Future<void> deleteCandidateCV({required String userId, String? cvId});
  Future<Map<String, dynamic>> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
    required ApplicationNotificationDetails notification,
    String? cvS3Key,
    Map<String, dynamic>? extraFields,
  });
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    Map<String, dynamic> extraFields = const {},
  });
  Future<List<Map<String, dynamic>>> getCandidateApplications(String userId);
  Future<void> confirmApplicationCompletion({
    required String applicationId,
    required DateTime confirmedAt,
  });
  Future<void> submitCandidateRating({
    required String applicationId,
    required Map<String, dynamic> candidateRating,
  });
  Future<void> updateApplicationChat({
    required String applicationId,
    required String status,
    required List<Map<String, dynamic>> chatMessages,
  });
  Future<void> archiveApplicationChat({
    required String applicationId,
    required DateTime archivedAt,
  });
  Future<void> sendCandidateAiScreeningPassedNotification({
    required String candidateId,
    required String jobTitle,
    required String companyName,
    required String jobId,
    required int score,
  });
  Future<void> sendCandidateAiScreeningRejectedNotification({
    required String candidateId,
    required String jobTitle,
    required String companyName,
    required String jobId,
  });
  Future<void> sendEmployerApplicationNotification({
    required String jobId,
    required ApplicationNotificationDetails details,
  });
}

bool isAlreadyAppliedApplicationError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('already_applied') ||
      message.contains('already applied') ||
      message.contains('đã ứng tuyển');
}

String? applicationIdFromSubmitResponse(Map<String, dynamic> response) {
  final id = response['applicationId'] ?? response['id'];
  if (id != null && id.toString().trim().isNotEmpty) {
    return id.toString();
  }

  final application = response['application'];
  if (application is Map) {
    final nestedId = application['applicationId'] ?? application['id'];
    if (nestedId != null && nestedId.toString().trim().isNotEmpty) {
      return nestedId.toString();
    }
  }

  return null;
}

String? existingApplicationIdForJob(
  List<Map<String, dynamic>> applications,
  String jobId,
) {
  final application = existingApplicationForJob(applications, jobId);
  if (application == null) return null;
  return applicationIdFromApplication(application);
}

Map<String, dynamic>? existingApplicationForJob(
  List<Map<String, dynamic>> applications,
  String jobId,
) {
  final target = jobId.trim();
  if (target.isEmpty) return null;
  for (final application in applications) {
    final applicationJobId =
        application['jobId'] ?? application['idJob'] ?? application['jobID'];
    if (applicationJobId?.toString().trim() != target) continue;

    return application;
  }

  return null;
}

String? applicationIdFromApplication(Map<String, dynamic> application) {
  final applicationId =
      application['applicationId'] ?? application['id'] ?? application['appId'];
  if (applicationId != null && applicationId.toString().trim().isNotEmpty) {
    return applicationId.toString();
  }
  return null;
}

ExistingAiInterviewContinuation? aiInterviewContinuationForExistingApplication({
  required List<Map<String, dynamic>> applications,
  required String jobId,
  String? alternateJobId,
  required String selectedCvUrl,
  required String selectedCvFilename,
  String? selectedCvS3Key,
  bool jobRequiresAiInterview = false,
}) {
  final application =
      existingApplicationForJob(applications, jobId) ??
      (alternateJobId == null
          ? null
          : existingApplicationForJob(applications, alternateJobId));
  if (application == null ||
      !isApplicationReadyForAiInterview(
        application,
        jobRequiresAiInterview: jobRequiresAiInterview,
      )) {
    return null;
  }

  final applicationId = applicationIdFromApplication(application);
  if (applicationId == null) return null;

  final cvUrl = _firstApplicationText(application, const [
    'cvUrl',
    'cvURL',
    'candidateCvUrl',
    'candidateCVUrl',
    'cvS3Key',
  ], fallback: selectedCvUrl);
  final cvFilename = _firstApplicationText(application, const [
    'cvFilename',
    'cvFileName',
    'candidateCvFilename',
    'candidateCVFilename',
  ], fallback: selectedCvFilename);
  final cvS3Key = _firstApplicationTextOrNull(application, const [
    'cvS3Key',
    'cvKey',
    'candidateCvS3Key',
    'candidateCVS3Key',
  ], fallback: selectedCvS3Key);
  final result = _firstApplicationText(application, const [
    'aiScreeningResult',
    'cvScreeningResult',
    'screeningResult',
    'roundOneResult',
  ], fallback: 'pass');

  return ExistingAiInterviewContinuation(
    applicationId: applicationId,
    cvUrl: cvUrl,
    cvFilename: cvFilename.isEmpty ? 'CV.pdf' : cvFilename,
    cvS3Key: cvS3Key,
    aiScreeningScore: _applicationInt(application['aiScreeningScore']),
    aiScreeningResult: result.isEmpty ? 'pass' : result,
    aiScreeningReason: _firstApplicationText(application, const [
      'aiScreeningReason',
      'cvScreeningReason',
      'screeningReason',
      'roundOneReason',
    ], fallback: 'CV đã được chấp nhận; tiếp tục vòng phỏng vấn AI.'),
  );
}

bool isApplicationReadyForAiInterview(
  Map<String, dynamic> application, {
  bool jobRequiresAiInterview = true,
}) {
  final status = _normalizedApplicationValue(application['status']);
  const terminalStatuses = {
    'rejected',
    'completed',
    'completed_pending_candidate',
    'archived',
    'deleted',
    'cancelled',
    'canceled',
  };
  if (terminalStatuses.contains(status)) return false;
  if (_hasApplicationAiInterviewReport(application)) return false;

  if (status == 'approved') {
    return jobRequiresAiInterview ||
        _hasApplicationAiInterviewEvidence(application) ||
        _hasPositiveApplicationScreeningResult(application);
  }

  const aiSpecificReadyStatuses = {
    'cv_accepted',
    'cv_approved',
    'cv_screening_passed',
    'screening_passed',
    'interview_pending',
    'ai_interview_pending',
    'pending_ai_interview',
    'awaiting_ai_interview',
  };
  if (aiSpecificReadyStatuses.contains(status)) return true;

  if ((status == 'accepted' || status == 'shortlisted') &&
      (jobRequiresAiInterview ||
          _hasApplicationAiInterviewEvidence(application))) {
    return true;
  }

  return false;
}

bool _hasPositiveApplicationScreeningResult(Map<String, dynamic> application) {
  final screeningResult = _normalizedApplicationValue(
    application['aiScreeningResult'] ??
        application['cvScreeningResult'] ??
        application['screeningResult'] ??
        application['roundOneResult'],
  );
  return screeningResult == 'pass' ||
      screeningResult == 'review' ||
      screeningResult == 'accepted' ||
      screeningResult == 'approved';
}

bool _hasApplicationAiInterviewReport(Map<String, dynamic> application) {
  for (final key in const [
    'aiInterviewReport',
    'interviewReport',
    'ai_interview_report',
  ]) {
    final value = application[key];
    if (value == null) continue;
    if (value is Map || value is List) return value.isNotEmpty;
    if (value.toString().trim().isNotEmpty) return true;
  }

  return false;
}

bool _hasApplicationAiInterviewEvidence(Map<String, dynamic> application) {
  for (final key in const [
    'requiresAiInterview',
    'requireAiInterview',
    'aiInterviewRequired',
    'aiInterviewEnabled',
    'isAiInterviewEnabled',
    'isAIInterviewEnabled',
    'isAiScreeningEnabled',
    'aiScreeningEnabled',
  ]) {
    if (_applicationTruthy(application[key])) return true;
  }

  for (final key in const [
    'aiScreeningScore',
    'aiScreeningReason',
    'aiInterviewSessionId',
    'aiInterviewStatus',
    'cvScreeningResult',
    'screeningResult',
    'roundOneResult',
  ]) {
    final value = application[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return true;
  }

  return false;
}

String _firstApplicationText(
  Map<String, dynamic> application,
  List<String> keys, {
  String fallback = '',
}) {
  return _firstApplicationTextOrNull(application, keys, fallback: fallback) ??
      '';
}

String? _firstApplicationTextOrNull(
  Map<String, dynamic> application,
  List<String> keys, {
  String? fallback,
}) {
  for (final key in keys) {
    final text = application[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  final fallbackText = fallback?.trim() ?? '';
  return fallbackText.isEmpty ? null : fallbackText;
}

String _normalizedApplicationValue(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  final separated = raw.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match[1]}_${match[2]}',
  );
  return separated.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
}

int _applicationInt(dynamic value) {
  if (value is num) return value.toInt();
  return double.tryParse(value?.toString().trim() ?? '')?.round() ?? 0;
}

bool _applicationTruthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = _normalizedApplicationValue(value);
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'enabled' ||
      normalized == 'on';
}
