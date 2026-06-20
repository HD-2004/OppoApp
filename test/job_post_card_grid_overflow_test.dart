import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/widgets/job_post_card.dart';

void main() {
  testWidgets('grid card with very long requirements does not overflow', (
    tester,
  ) async {
    final job = JobPost(
      id: 'job-long',
      idJob: 'job-long',
      employerId: 'employer-1',
      employerName: 'Katinat Quận Cam',
      companyName: 'Katinat Quận Cam',
      title: 'Nhân viên pha chế thức uống cao cấp full time',
      jobType: JobPostType.partTime,
      description: 'Pha chế thức uống cho khách tại quầy.',
      requirements:
          'Đam mê lĩnh vực pha chế và mong muốn phát triển kỹ năng trong '
          'ngành dịch vụ. Ưu tiên các ứng viên đã có kinh nghiệm làm việc tại '
          'các quán cà phê hoặc nhà hàng tương đương, làm việc theo ca sáng '
          'từ 07:00 đến 11:30 một cách ổn định và lâu dài.',
      location: 'Nhà Văn hóa Sinh Viên, Quận 5, TP. Hồ Chí Minh',
      salary: '30.000 VND / giờ',
      shiftTime: '07:00 - 11:30',
      tags: const ['F&B'],
      postedAt: DateTime(2026, 6, 10, 18),
    );

    // Emulate a narrow grid column (half of a ~360px phone minus spacing).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 170,
                  child: JobPostCard(
                    job: job,
                    layout: JobCardLayout.grid,
                    onDetailsPressed: () {},
                    onApplyPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ứng tuyển ngay'), findsOneWidget);
  });
}
