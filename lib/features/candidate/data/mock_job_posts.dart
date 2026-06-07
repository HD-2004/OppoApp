import '../domain/job_post.dart';

/// DEPRECATED — Mock data không còn được dùng trong production.
/// Tất cả job data phải lấy từ [AwsJobRepository] qua [activeJobsProvider]
/// và [activeQuickJobsProvider].
/// Giữ lại file này để tránh break references cũ. Đừng thêm data mới vào đây.
@Deprecated(
  'Use activeJobsProvider or activeQuickJobsProvider instead. '
  'This mock data must not be used in production builds.',
)
List<JobPost> get mockJobPosts {
  return const <JobPost>[];
}
