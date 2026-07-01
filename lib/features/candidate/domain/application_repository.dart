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
