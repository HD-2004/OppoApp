import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

    test('expands relative employer logo S3 keys to asset URLs', () {
      final logo = AwsJobRepository.employerLogoFrom({
        'companyLogo': 'employers/katinat-logo.png',
      });

      expect(
        logo,
        'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/employers/katinat-logo.png',
      );
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

    test('maps popular job metrics and defaults missing values to zero', () {
      final standard = AwsJobRepository.mapStandardJob({
        'idJob': 'job-popular',
        'applicants': 12,
        'employerReputationScore': 88.5,
        'candidateRatingScore': 4.7,
      });
      final quick = AwsJobRepository.mapQuickJob({
        'jobID': 'quick-popular',
        'applicationCount': 9,
        'employer_reputation_score': 76,
        'candidate_rating_score': 4.3,
      });
      final missing = AwsJobRepository.mapStandardJob({'idJob': 'job-missing'});

      expect(standard.applicants, 12);
      expect(standard.employerReputationScore, 88.5);
      expect(standard.candidateRatingScore, 4.7);
      expect(quick.applicants, 9);
      expect(quick.employerReputationScore, 76);
      expect(quick.candidateRatingScore, 4.3);
      expect(missing.employerReputationScore, 0);
      expect(missing.candidateRatingScore, 0);
    });

    test('maps standard job recruitment window and status', () {
      final job = AwsJobRepository.mapStandardJob({
        'idJob': 'job-window',
        'recruitmentStartDate': '2026-07-01',
        'recruitmentEndDate': '2026-07-15',
        'status': 'active',
      });

      expect(job.recruitmentStartDate, DateTime(2026, 7, 1));
      expect(job.recruitmentEndDate, DateTime(2026, 7, 15));
      expect(job.status, 'active');
    });

    test('maps web AI interview fields to mobile screening flag', () {
      final explicitAiJob = AwsJobRepository.mapStandardJob({
        'idJob': 'job-ai-explicit',
        'aiInterviewEnabled': true,
      });
      final customQuestionJob = AwsJobRepository.mapStandardJob({
        'idJob': 'job-ai-questions',
        'customQuestions': ['Bạn xử lý khách phàn nàn thế nào?'],
      });

      expect(explicitAiJob.isAiScreeningEnabled, isTrue);
      expect(customQuestionJob.isAiScreeningEnabled, isTrue);
      expect(customQuestionJob.customQuestions, [
        'Bạn xử lý khách phàn nàn thế nào?',
      ]);
    });

    test('maps alternate web AI interview field shapes', () {
      final nestedAiJob = AwsJobRepository.mapStandardJob({
        'idJob': 'job-ai-nested',
        'aiInterview': {'enabled': true},
      });
      final interviewQuestionJob = AwsJobRepository.mapStandardJob({
        'idJob': 'job-ai-interview-questions',
        'interviewQuestions': ['Bạn làm ca tối được không?'],
      });

      expect(nestedAiJob.isAiScreeningEnabled, isTrue);
      expect(interviewQuestionJob.isAiScreeningEnabled, isTrue);
      expect(interviewQuestionJob.customQuestions, [
        'Bạn làm ca tối được không?',
      ]);
    });

    test('maps snake case web AI interview field shapes', () {
      final snakeCaseAiJob = AwsJobRepository.mapStandardJob({
        'idJob': 'job-ai-snake-case',
        'ai_interview_enabled': true,
      });
      final nestedSnakeCaseAiJob = AwsJobRepository.mapStandardJob({
        'idJob': 'job-ai-nested-snake-case',
        'ai_interview': {'is_enabled': true},
      });

      expect(snakeCaseAiJob.isAiScreeningEnabled, isTrue);
      expect(nestedSnakeCaseAiJob.isAiScreeningEnabled, isTrue);
    });

    test('maps quick job AI interview fields to mobile screening flag', () {
      final quickAiJob = AwsJobRepository.mapQuickJob({
        'jobID': 'quick-ai',
        'title': 'Ca phục vụ có phỏng vấn AI',
        'ai_interview_enabled': true,
        'custom_questions': ['Bạn có thể làm ca tối không?'],
      });

      expect(quickAiJob.isQuickJob, isTrue);
      expect(quickAiJob.isAiScreeningEnabled, isTrue);
      expect(quickAiJob.customQuestions, ['Bạn có thể làm ca tối không?']);
    });

    test('maps quick job recruitment window from alternate backend keys', () {
      final job = AwsJobRepository.mapQuickJob({
        'jobID': 'quick-window',
        'validFrom': '2026-07-03',
        'deadline': '2026-07-10',
        'jobStatus': 'expired',
      });

      expect(job.recruitmentStartDate, DateTime(2026, 7, 3));
      expect(job.recruitmentEndDate, DateTime(2026, 7, 10));
      expect(job.status, 'expired');
    });

    test('maps requirements from alternate backend field names', () {
      final standard = AwsJobRepository.mapStandardJob({
        'idJob': 'job-requirements',
        'jobRequirements': 'Giao tiếp tốt\nCó thể làm cuối tuần',
      });
      final quick = AwsJobRepository.mapQuickJob({
        'jobID': 'quick-requirements',
        'qualification': 'Không yêu cầu kinh nghiệm, được đào tạo tại chỗ',
      });

      expect(standard.requirements, 'Giao tiếp tốt\nCó thể làm cuối tuần');
      expect(
        quick.requirements,
        'Không yêu cầu kinh nghiệm, được đào tạo tại chỗ',
      );
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

  group('AwsJobRepository active listings', () {
    test('getActiveJobs removes expired standard jobs from API data', () async {
      final repository = AwsJobRepository(
        client: MockClient(
          (_) async => _jsonResponse({
            'success': true,
            'data': [
              _standardJobPayload(
                idJob: 'job-open',
                recruitmentEndDate: DateTime.now().add(const Duration(days: 3)),
              ),
              _standardJobPayload(
                idJob: 'job-expired-date',
                recruitmentEndDate: DateTime.now().subtract(
                  const Duration(days: 1),
                ),
              ),
              _standardJobPayload(
                idJob: 'job-expired-status',
                recruitmentEndDate: DateTime.now().add(const Duration(days: 3)),
                status: 'expired',
              ),
            ],
          }),
        ),
      );

      final jobs = await repository.getActiveJobs();

      expect(jobs.map((job) => job.idJob), ['job-open']);
    });

    test(
      'getActiveQuickJobs removes expired quick jobs from API data',
      () async {
        final repository = AwsJobRepository(
          client: MockClient(
            (_) async => _jsonResponse({
              'success': true,
              'data': [
                _quickJobPayload(
                  jobID: 'quick-open',
                  deadline: DateTime.now().add(const Duration(days: 3)),
                ),
                _quickJobPayload(
                  jobID: 'quick-expired',
                  deadline: DateTime.now().subtract(const Duration(days: 1)),
                ),
              ],
            }),
          ),
        );

        final jobs = await repository.getActiveQuickJobs();

        expect(jobs.map((job) => job.idJob), ['quick-open']);
      },
    );
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> _standardJobPayload({
  required String idJob,
  required DateTime recruitmentEndDate,
  String status = 'active',
}) {
  return {
    'idJob': idJob,
    'employerId': 'employer-1',
    'employerName': 'Quán cà phê',
    'title': 'Nhân viên phục vụ',
    'jobType': 'part-time',
    'location': 'Quận 1',
    'salary': '25000',
    'workHours': '08:00 - 12:00',
    'description': 'Phục vụ khách hàng',
    'createdAt': DateTime.now().toIso8601String(),
    'recruitmentEndDate': recruitmentEndDate.toIso8601String(),
    'status': status,
  };
}

Map<String, dynamic> _quickJobPayload({
  required String jobID,
  required DateTime deadline,
}) {
  return {
    'jobID': jobID,
    'companyName': 'Quán cà phê',
    'title': 'Ca phục vụ',
    'location': 'Quận 1',
    'hourlyRate': 25000,
    'totalHours': 4,
    'createdAt': DateTime.now().toIso8601String(),
    'deadline': deadline.toIso8601String(),
    'jobStatus': 'active',
  };
}
