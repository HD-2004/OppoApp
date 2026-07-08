import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_recruitment_window.dart';

void main() {
  group('job recruitment window', () {
    final today = DateTime(2026, 7, 15, 12);

    test('formats recruitment range as Vietnamese date range', () {
      final job = _job(
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(
        recruitmentWindowLabel(job),
        'Tuyển dụng: 01/07/2026 - 15/07/2026',
      );
      expect(recruitmentWindowValue(job), '01/07/2026 - 15/07/2026');
    });

    test('omits recruitment copy when backend does not provide dates', () {
      expect(recruitmentWindowLabel(_job()), 'Tuyển dụng');
      expect(recruitmentWindowValue(_job()), '');
    });

    test('keeps job recruitable through the full end date', () {
      final job = _job(
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(isJobPostExpired(job, now: today), isFalse);
      expect(isJobPostRecruitable(job, now: today), isTrue);
    });

    test('expires after the end date has passed', () {
      final job = _job(
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(isJobPostExpired(job, now: DateTime(2026, 7, 16)), isTrue);
      expect(isJobPostRecruitable(job, now: DateTime(2026, 7, 16)), isFalse);
    });

    test(
      'status expired or archived blocks recruitment even inside date range',
      () {
        final expired = _job(
          recruitmentStartDate: DateTime(2026, 7, 1),
          recruitmentEndDate: DateTime(2026, 7, 30),
          status: 'expired',
        );
        final archived = expired.copyWith(status: 'archived');

        expect(isJobPostRecruitable(expired, now: today), isFalse);
        expect(isJobPostRecruitable(archived, now: today), isFalse);
      },
    );

    test('future start date is not recruitable yet', () {
      final job = _job(
        recruitmentStartDate: DateTime(2026, 7, 20),
        recruitmentEndDate: DateTime(2026, 7, 30),
      );

      expect(isJobPostRecruitable(job, now: today), isFalse);
    });
  });
}

JobPost _job({
  DateTime? recruitmentStartDate,
  DateTime? recruitmentEndDate,
  String status = 'active',
}) {
  return JobPost(
    id: 'job-1',
    idJob: 'job-1',
    employerId: 'employer-1',
    employerName: 'Công ty Demo',
    title: 'Nhân viên phục vụ',
    jobType: JobPostType.partTime,
    location: 'Quận 1',
    salary: '30.000 VNĐ/giờ',
    shiftTime: '08:00 - 12:00',
    description: 'Phục vụ khách hàng.',
    tags: const ['F&B'],
    postedAt: DateTime(2026, 6, 1),
    recruitmentStartDate: recruitmentStartDate,
    recruitmentEndDate: recruitmentEndDate,
    status: status,
  );
}
