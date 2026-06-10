import '../../candidate/domain/job_post.dart';

class JobRecommendation {
  const JobRecommendation({
    required this.job,
    required this.matchScore,
    required this.reasons,
  });

  final JobPost job;
  final int matchScore;
  final List<String> reasons;
}
