import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_job_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/user_job_detail_screen.dart';

void main() {
  testWidgets('job detail header keeps back button and hides right actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobRepositoryProvider.overrideWithValue(_FakeJobRepo())],
        child: MaterialApp(
          home: UserJobDetailScreen(job: _job, onApplyPressed: () {}),
        ),
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
    expect(find.text('Ứng tuyển ngay'), findsOneWidget);
  });
}

final _job = JobPost(
  id: 'job-1',
  idJob: 'job-1',
  employerId: 'employer-1',
  employerName: 'Công ty cổ phần cafe Katinat',
  title: 'Nhân viên phục vụ',
  jobType: JobPostType.partTime,
  location: 'Quận 1',
  salary: '24.000 VNĐ/giờ',
  shiftTime: '17:00 - 22:00',
  description: 'Phục vụ khách hàng tại quầy.',
  requirements: 'Nhanh nhẹn',
  benefits: 'Lương theo ca',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 6, 1),
);

class _FakeJobRepo implements JobRepository {
  @override
  Future<List<JobPost>> getActiveJobs() async => const [];

  @override
  Future<List<JobPost>> getActiveQuickJobs() async => const [];

  @override
  Future<void> incrementJobViews(
    String jobId, {
    required bool isQuickJob,
  }) async {}
}
