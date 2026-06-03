import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/data/mock_job_posts.dart';

void main() {
  test('mock job posts include backend identifiers', () {
    for (final job in mockJobPosts) {
      expect(job.idJob, isNotEmpty);
      expect(job.employerId, isNotEmpty);
    }
  });
}
