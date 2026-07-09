import '../../candidate/domain/job_post.dart';

List<JobPost> sortJobsByPopularity(Iterable<JobPost> jobs) {
  final sorted = jobs.toList(growable: false);
  sorted.sort(compareJobsByPopularity);
  return sorted;
}

int compareJobsByPopularity(JobPost a, JobPost b) {
  final applicants = b.applicants.compareTo(a.applicants);
  if (applicants != 0) return applicants;

  final reputation = b.employerReputationScore.compareTo(
    a.employerReputationScore,
  );
  if (reputation != 0) return reputation;

  final rating = b.candidateRatingScore.compareTo(a.candidateRatingScore);
  if (rating != 0) return rating;

  return b.postedAt.compareTo(a.postedAt);
}
