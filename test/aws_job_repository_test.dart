import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_job_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';

void main() {
  group('AwsJobRepository mapper', () {
    test('does not invent coordinates and uses Vietnamese fallbacks', () {
      final job = AwsJobRepository.mapStandardJob({
        'idJob': 'job-1',
        'employerId': 'employer-1',
        'title': '',
        'employerName': '',
      });

      expect(job.latitude, isNull);
      expect(job.longitude, isNull);
      expect(job.title, 'Công việc chưa đặt tên');
      expect(job.employerName, 'Nhà tuyển dụng');
      expect(job.salary, 'Thỏa thuận');
      expect(job.postedAt.millisecondsSinceEpoch, 0);
    });

    test('uses the first supported employer logo field', () {
      final logo = AwsJobRepository.employerLogoFrom({
        'companyLogo': 'https://example.com/company.png',
        'logoUrl': 'https://example.com/secondary.png',
      });

      expect(logo, 'https://example.com/company.png');
    });

    test('maps quick job salary and Vietnamese tags', () {
      final job = AwsJobRepository.mapQuickJob({
        'jobID': 'quick-1',
        'companyName': 'Quán cà phê',
        'title': 'Phục vụ',
        'hourlyRate': 100000,
        'totalHours': 4,
        'totalSalary': 400000,
      });

      expect(job.jobType, JobPostType.urgent);
      expect(job.salary, '340.000 VNĐ/4 giờ');
      expect(job.tags, ['Tuyển gấp', 'Làm ngay']);
      expect(job.totalSalary, 400000);
    });

    test('rejects invalid coordinate ranges', () {
      final job = AwsJobRepository.mapStandardJob({
        'idJob': 'job-2',
        'latitude': 120,
        'longitude': 220,
      });

      expect(job.latitude, isNull);
      expect(job.longitude, isNull);
    });
  });
}
