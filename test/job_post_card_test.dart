import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
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
    expect(find.text('18:00 - 22:00'), findsOneWidget);
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
}

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
);
