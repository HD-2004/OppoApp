import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/job_post.dart';
import '../domain/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return AwsJobRepository();
});

class AwsJobRepository implements JobRepository {
  static const _standardJobsUrl = 'https://dlidp35x33.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _quickJobsUrl = 'https://6zw89pkuxb.execute-api.ap-southeast-1.amazonaws.com/prod';

  String _formatSalaryFromDB(dynamic raw, {String fallback = 'Thỏa thuận'}) {
    if (raw == null) return fallback;
    final str = raw.toString().trim();
    if (str.isEmpty) return fallback;
    if (str.contains('VNĐ') || str.contains('VND') || str.contains('đ')) return str;
    final num = int.tryParse(str.replaceAll(RegExp(r'\D'), ''));
    if (num == null || num == 0) return fallback;

    final formatted = num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return '$formatted VNĐ/giờ';
  }

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Future<List<JobPost>> getActiveJobs() async {
    try {
      final response = await http.get(Uri.parse('$_standardJobsUrl/jobs/active'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final list = body['data'] as List;
          return list.map((item) {
            final job = item as Map<String, dynamic>;
            final idJob = job['idJob'] as String? ?? '';
            final lat = double.tryParse(job['latitude']?.toString() ?? '') ??
                double.tryParse(job['lat']?.toString() ?? '') ?? 10.7769;
            final lng = double.tryParse(job['longitude']?.toString() ?? '') ??
                double.tryParse(job['lng']?.toString() ?? '') ?? 106.7009;

            List<String> tagsList = [];
            if (job['tags'] != null && job['tags'].toString().isNotEmpty) {
              tagsList = job['tags'].toString().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
            }

            final jobTypeStr = (job['jobType'] as String? ?? '').toLowerCase();
            final jobType = jobTypeStr == 'part-time' ? JobPostType.partTime : JobPostType.fullTime;

            return JobPost(
              id: 'dynamo-$idJob',
              idJob: idJob,
              employerId: job['employerId'] as String? ?? '',
              employerName: job['employerName'] as String? ?? job['employerEmail'] as String? ?? 'Công ty',
              title: job['title'] as String? ?? 'Untitled Job',
              jobType: jobType,
              location: job['location'] as String? ?? '',
              latitude: lat,
              longitude: lng,
              salary: _formatSalaryFromDB(job['salary']),
              shiftTime: job['workHours'] as String? ?? '',
              description: job['description'] as String? ?? '',
              tags: tagsList,
              postedAt: DateTime.tryParse(job['createdAt']?.toString() ?? '') ?? DateTime.now(),
              applicants: int.tryParse(job['applicants']?.toString() ?? '0') ?? 0,
              views: int.tryParse(job['views']?.toString() ?? '0') ?? 0,
              workHours: job['workHours'] as String?,
              workDays: job['workDays'] as String?,
              responsibilities: job['responsibilities'] as String?,
              requirements: job['requirements'] as String?,
              benefits: job['benefits'] as String?,
              isQuickJob: false,
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching standard active jobs: $e');
      return [];
    }
  }

  @override
  Future<List<JobPost>> getActiveQuickJobs() async {
    try {
      final response = await http.get(Uri.parse('$_quickJobsUrl/quick-jobs/active'));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final list = body['data'] as List;
          return list.map((item) {
            final job = item as Map<String, dynamic>;
            final idJob = job['jobID'] as String? ?? job['idJob'] as String? ?? '';
            final hourlyRate = int.tryParse(job['hourlyRate']?.toString() ?? '0') ?? 0;
            final totalHours = double.tryParse(job['totalHours']?.toString() ?? '0') ?? 0.0;
            final totalSalary = int.tryParse(job['totalSalary']?.toString() ?? '0') ?? (hourlyRate * totalHours).round();

            final candidateIncome = (totalSalary * 0.85).round();
            final lat = double.tryParse(job['latitude']?.toString() ?? '') ??
                double.tryParse(job['lat']?.toString() ?? '') ?? 10.7769;
            final lng = double.tryParse(job['longitude']?.toString() ?? '') ??
                double.tryParse(job['lng']?.toString() ?? '') ?? 106.7009;

            final hoursStr = totalHours.toStringAsFixed(totalHours.truncateToDouble() == totalHours ? 0 : 1);
            final salaryStr = candidateIncome > 0
                ? '${_formatMoney(candidateIncome)} VNĐ/${hoursStr}h'
                : '${_formatMoney((hourlyRate * 0.85).round())} VNĐ/giờ';

            final startTime = job['startTime'] as String? ?? '';
            final endTime = job['endTime'] as String? ?? '';
            final shiftTime = (startTime.isNotEmpty && endTime.isNotEmpty) ? '$startTime - $endTime' : '';

            return JobPost(
              id: 'quick-$idJob',
              idJob: idJob,
              employerId: job['employerId'] as String? ?? '',
              employerName: job['companyName'] as String? ?? 'Công ty',
              title: job['title'] as String? ?? 'Untitled Job',
              jobType: JobPostType.urgent,
              location: job['location'] as String? ?? '',
              latitude: lat,
              longitude: lng,
              salary: salaryStr,
              shiftTime: shiftTime,
              description: job['description'] as String? ?? '',
              tags: const ['Tuyển gấp', 'Làm ngay'],
              postedAt: DateTime.tryParse(job['createdAt']?.toString() ?? '') ?? DateTime.now(),
              applicants: int.tryParse(job['applicants']?.toString() ?? '0') ?? 0,
              views: int.tryParse(job['views']?.toString() ?? '0') ?? 0,
              workDate: job['workDate'] as String?,
              companyName: job['companyName'] as String?,
              hourlyRate: hourlyRate,
              totalHours: totalHours,
              totalSalary: totalSalary,
              startTime: startTime,
              endTime: endTime,
              requirements: job['requirements'] as String?,
              isQuickJob: true,
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching active quick jobs: $e');
      return [];
    }
  }

  @override
  Future<void> incrementJobViews(String jobId, {required bool isQuickJob}) async {
    try {
      final baseUrl = isQuickJob ? _quickJobsUrl : _standardJobsUrl;
      final endpoint = isQuickJob ? '/quick-jobs/$jobId/views' : '/jobs/$jobId/views';
      await http.post(Uri.parse('$baseUrl$endpoint'));
    } catch (e) {
      print('Error incrementing job views: $e');
    }
  }
}
