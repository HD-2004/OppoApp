import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_recruitment_window.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/widgets/job_post_card.dart';

void main() {
  testWidgets('job post card is a recruiting card with one apply CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: _job,
            onDetailsPressed: () {},
            onApplyPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Katinat Quận Cam'), findsOneWidget);
    expect(find.text('Nhân viên phục vụ'), findsOneWidget);
    expect(find.text('Yêu cầu'), findsOneWidget);
    expect(find.text('Có kinh nghiệm phục vụ'), findsOneWidget);
    expect(find.textContaining('Nhà Văn hóa Sinh Viên'), findsOneWidget);
    expect(find.text('Tuyển dụng'), findsOneWidget);
    expect(find.text(recruitmentWindowValue(_job)), findsOneWidget);
    expect(find.text('18:00 - 22:00'), findsNothing);
    expect(find.text('425.000 VND / ca'), findsOneWidget);
    expect(find.text('Ứng tuyển ngay'), findsOneWidget);

    final requirementsTop = tester.getTopLeft(find.text('Yêu cầu')).dy;
    final addressTop = tester.getTopLeft(find.text('Địa chỉ')).dy;
    expect(requirementsTop, lessThan(addressTop));

    expect(find.text('Lưu'), findsNothing);
    expect(find.text('Chi tiết'), findsNothing);
    expect(find.text('Hot deal'), findsNothing);
    expect(find.text('Nhiều ứng viên đang quan tâm'), findsNothing);
  });

  testWidgets('job post card deducts 15% platform fee from totalSalary', (
    tester,
  ) async {
    final jobWithTotalSalary = JobPost(
      id: 'job-2',
      idJob: 'job-2',
      employerId: 'employer-1',
      employerName: 'Katinat Quận Cam',
      title: 'Nhân viên phục vụ',
      jobType: JobPostType.partTime,
      location: 'Nhà Văn hóa Sinh Viên, Khu đô thị Đại học Quốc gia',
      salary: '500.000 VND / ca',
      totalSalary: 500000,
      shiftTime: '18:00 - 22:00',
      description: 'Phục vụ khách hàng tại quầy.',
      requirements: 'Có kinh nghiệm phục vụ',
      tags: const ['F&B'],
      postedAt: DateTime(2026, 6, 10, 18),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: jobWithTotalSalary,
            onDetailsPressed: () {},
            onApplyPressed: () {},
          ),
        ),
      ),
    );

    // 500.000 * 0.85 = 425.000 VND / ca
    expect(find.text('425.000 VND / ca'), findsOneWidget);
  });

  testWidgets('job post card has a saved icon that does not open details', (
    tester,
  ) async {
    var detailsTapCount = 0;
    var saveTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: _job,
            isSaved: false,
            onDetailsPressed: () => detailsTapCount++,
            onApplyPressed: () {},
            onSavePressed: () => saveTapCount++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);

    await tester.tap(find.byTooltip('Lưu công việc'));
    await tester.pump();

    expect(saveTapCount, 1);
    expect(detailsTapCount, 0);
  });

  testWidgets('job post card shows filled saved icon when job is saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: _job,
            isSaved: true,
            onDetailsPressed: () {},
            onApplyPressed: () {},
            onSavePressed: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
  });

  testWidgets('job post card shows employer avatar image when available', (
    tester,
  ) async {
    const transparentPng =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
        'AAAADUlEQVR42mP8z8BQDwAFgwJ/luzwVwAAAABJRU5ErkJggg==';

    final jobWithAvatar = JobPost(
      id: 'job-avatar',
      idJob: 'job-avatar',
      employerId: 'employer-1',
      employerName: 'Katinat Quáº­n Cam',
      employerAvatarUrl: transparentPng,
      title: 'NhĂ¢n viĂªn phá»¥c vá»¥',
      jobType: JobPostType.partTime,
      location:
          'NhĂ  VÄƒn hĂ³a Sinh ViĂªn, Khu Ä‘Ă´ thá»‹ Äáº¡i há»c Quá»‘c gia',
      salary: '425.000 VND / ca',
      shiftTime: '18:00 - 22:00',
      description: 'Phá»¥c vá»¥ khĂ¡ch hĂ ng táº¡i quáº§y.',
      requirements: 'CĂ³ kinh nghiá»‡m phá»¥c vá»¥',
      tags: const ['F&B'],
      postedAt: DateTime(2026, 6, 10, 18),
      recruitmentStartDate: _openRecruitmentStart,
      recruitmentEndDate: _openRecruitmentEnd,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: jobWithAvatar,
            onDetailsPressed: () {},
            onApplyPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Katinat Quáº­n Cam'), findsOneWidget);
  });

  testWidgets('job post card shows AI interview tag only for AI jobs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: _job.copyWith(isAiScreeningEnabled: true),
            onDetailsPressed: () {},
            onApplyPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Phỏng vấn AI'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Phỏng vấn AI')).dy,
      closeTo(tester.getTopLeft(find.text('Nhân viên phục vụ')).dy, 8),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: _job,
            onDetailsPressed: () {},
            onApplyPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Phỏng vấn AI'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
  });

  testWidgets('job post card disables apply CTA for expired stale data', (
    tester,
  ) async {
    var applyTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPostCard(
            job: _job.copyWith(status: 'expired'),
            onDetailsPressed: () {},
            onApplyPressed: () => applyTapCount++,
          ),
        ),
      ),
    );

    expect(find.text('Đã hết hạn'), findsOneWidget);
    expect(find.text('Ứng tuyển ngay'), findsNothing);

    await tester.tap(find.text('Đã hết hạn'));
    await tester.pump();

    expect(applyTapCount, 0);
  });
}

final _openRecruitmentStart = DateTime.now().subtract(const Duration(days: 1));
final _openRecruitmentEnd = DateTime.now().add(const Duration(days: 30));

final _job = JobPost(
  id: 'job-1',
  idJob: 'job-1',
  employerId: 'employer-1',
  employerName: 'Katinat Quận Cam',
  title: 'Nhân viên phục vụ',
  jobType: JobPostType.partTime,
  location: 'Nhà Văn hóa Sinh Viên, Khu đô thị Đại học Quốc gia',
  salary: '425.000 VND / ca',
  shiftTime: '18:00 - 22:00',
  description: 'Phục vụ khách hàng tại quầy.',
  requirements: 'Có kinh nghiệm phục vụ',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 6, 10, 18),
  recruitmentStartDate: _openRecruitmentStart,
  recruitmentEndDate: _openRecruitmentEnd,
);
