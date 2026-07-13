import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/jobs/presentation/widgets/job_card.dart';
import 'package:oppo_temp_jobs/shared/presentation/widgets/network_asset_image.dart';

void main() {
  testWidgets('jobs page card matches compact mobile recruitment reference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const logoUrl =
        'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/system/katinatlogo.jpg';
    final job = JobPost(
      id: 'job-1',
      idJob: 'job-1',
      employerId: 'employer-1',
      employerName: 'Katinat Quận Cam',
      companyName: 'Katinat Quận Cam',
      employerAvatarUrl: logoUrl,
      title: 'THU NGÂN QUÁN',
      jobType: JobPostType.partTime,
      location: 'Quận 2',
      salary: '25.000 VNĐ/giờ',
      shiftTime: 'T2,T3,T4,T5,T6 @ 07:00 - 12:00 | T7,CN @ 12:00 - 17:30',
      description: 'Thu ngân tại quán.',
      tags: const ['Thu ngân', 'F&B', 'Coffee'],
      postedAt: DateTime(2026, 7, 1),
      recruitmentEndDate: DateTime(2026, 7, 11),
      views: 43,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobCard(job: job, onTap: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('THU NGÂN QUÁN'), findsOneWidget);
    expect(find.text('Katinat Quận Cam'), findsOneWidget);
    expect(find.text('Tiêu chuẩn'), findsOneWidget);
    expect(find.text('Quận 2'), findsOneWidget);
    expect(find.text('Part-time'), findsOneWidget);
    expect(find.text('43 lượt xem'), findsOneWidget);
    expect(find.text('Thu ngân'), findsOneWidget);
    expect(find.text('F&B'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Thu nhập: 25.000 VNĐ/giờ'), findsOneWidget);
    expect(find.text('Ngày làm: T2 - T6 | T7 - CN'), findsOneWidget);
    expect(
      find.text('Thời gian: 07:00 - 12:00 | 12:00 - 17:30'),
      findsOneWidget,
    );
    expect(find.textContaining('@'), findsNothing);
    expect(find.text('Hạn nộp: 11/07/2026'), findsOneWidget);
    expect(find.text('Vị trí này có thể phù hợp với bạn'), findsOneWidget);

    final logo = tester.widget<NetworkAssetImage>(
      find.byType(NetworkAssetImage),
    );
    expect(logo.url, logoUrl);
  });
}
