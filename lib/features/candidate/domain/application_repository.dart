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
  final target = jobId.trim();
  if (target.isEmpty) return null;

  for (final application in applications) {
    final applicationJobId =
        application['jobId'] ?? application['idJob'] ?? application['jobID'];
    if (applicationJobId?.toString().trim() != target) continue;

    final applicationId =
        application['applicationId'] ??
        application['id'] ??
        application['appId'];
    if (applicationId != null && applicationId.toString().trim().isNotEmpty) {
      return applicationId.toString();
    }
  }

  return null;
}
