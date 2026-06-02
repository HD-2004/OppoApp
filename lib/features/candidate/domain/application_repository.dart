abstract class ApplicationRepository {
  Future<List<Map<String, dynamic>>> getCandidateCVs(String userId);
  Future<void> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
  });
}
