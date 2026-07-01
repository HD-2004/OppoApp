import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_job_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_recruitment_window.dart';
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

  testWidgets('job detail renders work schedule as a selectable calendar', (
    tester,
  ) async {
    const rawSchedule = 'T2,T3,T4,T5,T6 @ 07:00 - 11:30';
    final job = _jobFixture(shiftTime: rawSchedule);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobRepositoryProvider.overrideWithValue(_FakeJobRepo())],
        child: MaterialApp(
          home: UserJobDetailScreen(job: job, onApplyPressed: () {}),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Thời gian tuyển dụng'), findsOneWidget);
    expect(find.text(recruitmentWindowValue(job)), findsOneWidget);
    expect(find.text('Lịch làm việc'), findsOneWidget);
    expect(find.text(rawSchedule), findsNothing);
    expect(find.text('07:00 - 11:30'), findsOneWidget);
    expect(find.text('THỜI GIAN'), findsNothing);
  });

  testWidgets('job detail shows all shifts for the selected work date', (
    tester,
  ) async {
    final job = _jobFixture(
      shiftTime: 'T2,T3,T4,T5 @ 06:30 - 11:00 | T5,T6,T7 @ 08:00 - 11:30',
      recruitmentStartDate: DateTime(2026, 7),
      recruitmentEndDate: DateTime(2026, 7, 15),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobRepositoryProvider.overrideWithValue(_FakeJobRepo())],
        child: MaterialApp(
          home: UserJobDetailScreen(job: job, onApplyPressed: () {}),
        ),
      ),
    );

    await tester.pump();
    await tester.ensureVisible(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();

    expect(find.text('02/07/2026'), findsOneWidget);
    expect(find.text('06:30 - 11:00'), findsOneWidget);
    expect(find.text('08:00 - 11:30'), findsOneWidget);
  });

  testWidgets(
    'job detail marks every recruitment date and ignores weekday labels',
    (tester) async {
      final job = _jobFixture(
        shiftTime: 'T2 @ 06:30 - 11:00 | T5 @ 08:00 - 11:30',
        recruitmentStartDate: DateTime(2026, 7, 10),
        recruitmentEndDate: DateTime(2026, 7, 12),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jobRepositoryProvider.overrideWithValue(_FakeJobRepo())],
          child: MaterialApp(
            home: UserJobDetailScreen(job: job, onApplyPressed: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.ensureVisible(find.text('9'));
      await tester.pump();

      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));

      await tester.tap(find.text('9'));
      await tester.pump();

      expect(find.text('09/07/2026'), findsNothing);

      await tester.tap(find.text('10'));
      await tester.pump();

      expect(find.text('10/07/2026'), findsOneWidget);
      expect(find.text('06:30 - 11:00'), findsOneWidget);
      expect(find.text('08:00 - 11:30'), findsOneWidget);
    },
  );

  testWidgets('expired job detail shows notice and disables apply', (
    tester,
  ) async {
    var applyTapCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jobRepositoryProvider.overrideWithValue(_FakeJobRepo())],
        child: MaterialApp(
          home: UserJobDetailScreen(
            job: _job.copyWith(status: 'expired'),
            onApplyPressed: () => applyTapCount++,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Tin tuyển dụng đã hết hạn'), findsOneWidget);
    expect(find.text('Đã hết hạn'), findsOneWidget);

    await tester.tap(find.text('Đã hết hạn'));
    await tester.pump();

    expect(applyTapCount, 0);
  });
}

final _openRecruitmentStart = DateTime.now().subtract(const Duration(days: 1));
final _openRecruitmentEnd = DateTime.now().add(const Duration(days: 30));

final _job = _jobFixture();

JobPost _jobFixture({
  String shiftTime = 'T2,T3,T4,T5,T6 @ 07:00 - 11:30',
  DateTime? recruitmentStartDate,
  DateTime? recruitmentEndDate,
}) {
  return JobPost(
    id: 'job-1',
    idJob: 'job-1',
    employerId: 'employer-1',
    employerName: 'Công ty cổ phần cafe Katinat',
    title: 'Nhân viên phục vụ',
    jobType: JobPostType.partTime,
    location: 'Quận 1',
    salary: '24.000 VNĐ/giờ',
    shiftTime: shiftTime,
    description: 'Phục vụ khách hàng tại quầy.',
    requirements: 'Nhanh nhẹn',
    benefits: 'Lương theo ca',
    tags: const ['F&B'],
    postedAt: DateTime(2026, 6, 1),
    recruitmentStartDate: recruitmentStartDate ?? _openRecruitmentStart,
    recruitmentEndDate: recruitmentEndDate ?? _openRecruitmentEnd,
  );
}

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
