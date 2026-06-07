abstract class ApplicationRepository {
  Future<List<Map<String, dynamic>>> getCandidateCVs(String userId);
  Future<void> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
  });
  Future<List<Map<String, dynamic>>> getCandidateApplications(String userId);
  Future<void> updateApplicationChat({
    required String applicationId,
    required String status,
    required List<Map<String, dynamic>> chatMessages,
  });
}
