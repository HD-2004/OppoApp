import 'dart:convert';
import 'dart:developer' as developer;

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/config/s3_asset_config.dart';
import '../domain/job_post.dart';
import '../domain/job_repository.dart';
import '../domain/job_recruitment_window.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AwsJobRepository(client: client);
});

typedef AuthTokenProvider = Future<String?> Function();

class AwsJobRepository implements JobRepository {
  AwsJobRepository({http.Client? client, AuthTokenProvider? tokenProvider})
    : _client = client ?? http.Client(),
      _tokenProvider = tokenProvider ?? _getCognitoIdToken;

  static const _standardJobsUrl =
      'https://dlidp35x33.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _quickJobsUrl =
      'https://6zw89pkuxb.execute-api.ap-southeast-1.amazonaws.com/prod';

  final http.Client _client;
  final AuthTokenProvider _tokenProvider;

  @override
  Future<List<JobPost>> getActiveJobs() async {
    final response = await _client.get(
      Uri.parse('$_standardJobsUrl/jobs/active'),
    );
    final data = _decodeJobList(response, source: 'danh sách công việc');
    final jobs = _visibleActiveJobs(data.map(mapStandardJob))
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return _withEmployerProfileLogos(jobs);
  }

  @override
  Future<List<JobPost>> getActiveQuickJobs() async {
    final response = await _client.get(
      Uri.parse('$_quickJobsUrl/quick-jobs/active'),
    );
    final data = _decodeJobList(response, source: 'danh sách tuyển gấp');
    final jobs = _visibleActiveJobs(data.map(mapQuickJob))
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return _withEmployerProfileLogos(jobs);
  }

  Future<List<JobPost>> _withEmployerProfileLogos(List<JobPost> jobs) async {
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) return jobs;

    final logoByEmployerId = <String, String?>{};
    final enriched = <JobPost>[];

    for (final job in jobs) {
      final currentLogo = job.employerAvatarUrl?.trim();
      if (currentLogo != null && currentLogo.isNotEmpty) {
        enriched.add(job);
        continue;
      }

      final employerId = job.employerId.trim();
      if (employerId.isEmpty) {
        enriched.add(job);
        continue;
      }

      final logo = logoByEmployerId.containsKey(employerId)
          ? logoByEmployerId[employerId]
          : await _fetchEmployerProfileLogo(employerId, token.trim());
      logoByEmployerId[employerId] = logo;

      if (logo != null && logo.isNotEmpty) {
        enriched.add(job.copyWith(employerAvatarUrl: logo));
      } else {
        enriched.add(job);
      }
    }

    return enriched;
  }

  Future<String?> _fetchEmployerProfileLogo(
    String employerId,
    String token,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(resolveUrl('$_standardJobsUrl/profile/$employerId')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;

      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return employerLogoFrom(data);
      }
      return employerLogoFrom(decoded);
    } catch (error, stackTrace) {
      developer.log(
        'Could not load employer profile logo for job card',
        name: 'AwsJobRepository',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<String?> _getCognitoIdToken() async {
    try {
      final plugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
      final session = await plugin.fetchAuthSession();
      final tokens = session.userPoolTokensResult.valueOrNull;
      return tokens?.idToken.raw;
    } catch (error) {
      safePrint('Error getting employer profile auth token: $error');
      return null;
    }
  }

  static List<JobPost> _visibleActiveJobs(Iterable<JobPost> jobs) {
    final now = DateTime.now();
    return jobs
        .where((job) => isJobPostRecruitable(job, now: now))
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _decodeJobList(
    http.Response response, {
    required String source,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JobRepositoryException(
        'Không tải được $source (HTTP ${response.statusCode}).',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw JobRepositoryException('Dữ liệu $source không hợp lệ.', error);
    }

    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw JobRepositoryException('API $source trả về trạng thái thất bại.');
    }

    final rawData = decoded['data'];
    if (rawData == null) return const [];
    if (rawData is! List) {
      throw JobRepositoryException('$source không đúng định dạng.');
    }

    return rawData
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static JobPost mapStandardJob(Map<String, dynamic> job) {
    final idJob = _string(job['idJob']);
    final customQuestions = _firstCustomQuestions(job);
    return JobPost(
      id: 'dynamo-$idJob',
      idJob: idJob,
      employerId: _string(job['employerId']),
      employerName: _firstNonEmpty([
        job['employerName'],
        job['companyName'],
        job['employerEmail'],
      ], fallback: 'Nhà tuyển dụng'),
      employerAvatarUrl: employerLogoFrom(job),
      title: _firstNonEmpty([job['title']], fallback: 'Công việc chưa đặt tên'),
      jobType: _jobType(job['jobType']),
      location: _string(job['location']),
      latitude: _coordinate(job['latitude'] ?? job['lat'], latitude: true),
      longitude: _coordinate(job['longitude'] ?? job['lng'], latitude: false),
      salary: formatSalary(job['salary']),
      shiftTime: _string(job['workHours']),
      description: _string(job['description']),
      tags: _tags(job['tags']),
      postedAt: _date(job['createdAt']),
      recruitmentStartDate: _firstDate([
        job['recruitmentStartDate'],
        job['recruitmentStartDateTime'],
        job['applicationStartDate'],
        job['validFrom'],
      ]),
      recruitmentEndDate: _firstDate([
        job['recruitmentEndDate'],
        job['recruitmentEndDateTime'],
        job['applicationDeadline'],
        job['deadline'],
        job['expiresAt'],
        job['expiryDate'],
      ]),
      status: _statusFrom(job),
      applicants: _firstInt([
        job['applicants'],
        job['applicationCount'],
        job['applicationsCount'],
        job['cvCount'],
        job['submittedCvCount'],
      ]),
      views: _int(job['views']),
      employerReputationScore: _firstDouble([
        job['employerReputationScore'],
        job['employer_reputation_score'],
        job['reputationScore'],
        job['employerRating'],
        job['employer_rating'],
      ]),
      candidateRatingScore: _firstDouble([
        job['candidateRatingScore'],
        job['candidate_rating_score'],
        job['candidateReviewScore'],
        job['candidate_review_score'],
        job['averageCandidateRating'],
        job['average_candidate_rating'],
      ]),
      workHours: _nullableString(job['workHours']),
      workDays: _nullableString(job['workDays']),
      responsibilities: _nullableString(job['responsibilities']),
      requirements: _requirementsFrom(job),
      benefits: _nullableString(job['benefits']),
      isAiScreeningEnabled: _aiWorkflowEnabled(job, customQuestions),
      customQuestions: customQuestions,
    );
  }

  static JobPost mapQuickJob(Map<String, dynamic> job) {
    final idJob = _firstNonEmpty([job['jobID'], job['idJob']]);
    final customQuestions = _firstCustomQuestions(job);
    final hourlyRate = _int(job['hourlyRate']);
    final totalHours = _double(job['totalHours']);
    final suppliedTotal = _int(job['totalSalary']);
    final totalSalary = suppliedTotal > 0
        ? suppliedTotal
        : (hourlyRate * totalHours).round();
    final candidateIncome = (totalSalary * 0.85).round();
    final candidateHourlyRate = (hourlyRate * 0.85).round();
    final salary = candidateIncome > 0
        ? '${_formatMoney(candidateIncome)} VNĐ/${_formatHours(totalHours)} giờ'
        : candidateHourlyRate > 0
        ? '${_formatMoney(candidateHourlyRate)} VNĐ/giờ'
        : 'Thỏa thuận';
    final startTime = _string(job['startTime']);
    final endTime = _string(job['endTime']);

    return JobPost(
      id: 'quick-$idJob',
      idJob: idJob,
      employerId: _string(job['employerId']),
      employerName: _firstNonEmpty([
        job['companyName'],
        job['employerName'],
      ], fallback: 'Nhà tuyển dụng'),
      employerAvatarUrl: employerLogoFrom(job),
      title: _firstNonEmpty([job['title']], fallback: 'Công việc chưa đặt tên'),
      jobType: JobPostType.urgent,
      location: _string(job['location']),
      latitude: _coordinate(job['latitude'] ?? job['lat'], latitude: true),
      longitude: _coordinate(job['longitude'] ?? job['lng'], latitude: false),
      salary: salary,
      shiftTime: startTime.isNotEmpty && endTime.isNotEmpty
          ? '$startTime - $endTime'
          : '',
      description: _string(job['description']),
      tags: const ['Tuyển gấp', 'Làm ngay'],
      postedAt: _date(job['createdAt']),
      recruitmentStartDate: _firstDate([
        job['recruitmentStartDate'],
        job['recruitmentStartDateTime'],
        job['applicationStartDate'],
        job['validFrom'],
      ]),
      recruitmentEndDate: _firstDate([
        job['recruitmentEndDate'],
        job['recruitmentEndDateTime'],
        job['applicationDeadline'],
        job['deadline'],
        job['expiresAt'],
        job['expiryDate'],
      ]),
      status: _statusFrom(job),
      applicants: _firstInt([
        job['applicants'],
        job['applicationCount'],
        job['applicationsCount'],
        job['cvCount'],
        job['submittedCvCount'],
      ]),
      views: _int(job['views']),
      employerReputationScore: _firstDouble([
        job['employerReputationScore'],
        job['employer_reputation_score'],
        job['reputationScore'],
        job['employerRating'],
        job['employer_rating'],
      ]),
      candidateRatingScore: _firstDouble([
        job['candidateRatingScore'],
        job['candidate_rating_score'],
        job['candidateReviewScore'],
        job['candidate_review_score'],
        job['averageCandidateRating'],
        job['average_candidate_rating'],
      ]),
      workDate: _nullableString(job['workDate']),
      companyName: _nullableString(job['companyName']),
      hourlyRate: hourlyRate,
      totalHours: totalHours,
      totalSalary: totalSalary,
      startTime: startTime,
      endTime: endTime,
      requirements: _requirementsFrom(job),
      isQuickJob: true,
      isAiScreeningEnabled: _aiWorkflowEnabled(job, customQuestions),
      customQuestions: customQuestions,
    );
  }

  static String? employerLogoFrom(Map<String, dynamic> job) {
    for (final key in const [
      'employerAvatarUrl',
      'companyLogo',
      'logoUrl',
      'avatarUrl',
      'profileImage',
      'logo',
      'companyLogoUrl',
      'businessLogo',
      'businessLogoUrl',
      'company_logo',
      'profile_image',
    ]) {
      final value = _nullableString(job[key]);
      if (value != null) return _resolveEmployerLogoUrl(value);
    }
    return null;
  }

  static String _resolveEmployerLogoUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final key = value.replaceFirst(RegExp(r'^/+'), '');
    return '${S3AssetConfig.baseUrl}/$key';
  }

  static String formatSalary(dynamic raw, {String fallback = 'Thỏa thuận'}) {
    final value = _nullableString(raw);
    if (value == null || value == '0') return fallback;
    if (RegExp(r'[^\d.,\s]').hasMatch(value)) {
      return value
          .replaceAll('VND', 'VNĐ')
          .replaceAll('/hour', '/giờ')
          .replaceAll('/hr', '/giờ');
    }

    final amount = int.tryParse(value.replaceAll(RegExp(r'\D'), ''));
    if (amount == null || amount == 0) return fallback;
    return '${_formatMoney(amount)} VNĐ/giờ';
  }

  static JobPostType _jobType(dynamic raw) {
    final value = _string(
      raw,
    ).toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
    if (value.contains('part')) return JobPostType.partTime;
    if (value.contains('quick') || value.contains('urgent')) {
      return JobPostType.urgent;
    }
    return JobPostType.fullTime;
  }

  static List<String> _tags(dynamic raw) {
    if (raw is List) {
      return raw
          .map(_string)
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false);
    }
    return _string(raw)
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _customQuestions(dynamic raw) {
    if (raw is List) {
      return raw
          .map(_string)
          .where((question) => question.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static List<String> _firstCustomQuestions(Map<String, dynamic> job) {
    for (final key in const [
      'customQuestions',
      'custom_questions',
      'interviewQuestions',
      'interview_questions',
      'aiInterviewQuestions',
      'ai_interview_questions',
      'aiQuestions',
      'ai_questions',
      'customInterviewQuestions',
      'custom_interview_questions',
      'screeningQuestions',
      'screening_questions',
    ]) {
      final questions = _customQuestions(job[key]);
      if (questions.isNotEmpty) return questions;
    }

    for (final key in const [
      'aiInterview',
      'ai_interview',
      'aiInterviewConfig',
      'ai_interview_config',
      'aiInterviewSettings',
      'ai_interview_settings',
      'interviewConfig',
      'interview_config',
      'screeningConfig',
      'screening_config',
    ]) {
      final nested = job[key];
      if (nested is Map) {
        final questions = _firstCustomQuestions(
          Map<String, dynamic>.from(nested),
        );
        if (questions.isNotEmpty) return questions;
      }
    }

    return const [];
  }

  static String? _requirementsFrom(Map<String, dynamic> job) {
    for (final key in const [
      'requirements',
      'requirement',
      'jobRequirements',
      'jobRequirement',
      'job_requirements',
      'job_requirement',
      'candidateRequirements',
      'candidate_requirements',
      'qualifications',
      'qualification',
      'requiredSkills',
      'required_skills',
      'skillsRequired',
      'skills_required',
    ]) {
      final value = _nullableText(job[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _nullableText(dynamic raw) {
    if (raw is List) {
      final values = raw
          .map(_string)
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (values.isEmpty) return null;
      return values.join('\n');
    }
    return _nullableString(raw);
  }

  static bool _aiWorkflowEnabled(
    Map<String, dynamic> job,
    List<String> customQuestions,
  ) {
    if (customQuestions.isNotEmpty) return true;

    for (final key in const [
      'isAiScreeningEnabled',
      'is_ai_screening_enabled',
      'aiScreeningEnabled',
      'ai_screening_enabled',
      'enableAiScreening',
      'enable_ai_screening',
      'requiresAiScreening',
      'requires_ai_screening',
      'aiScreeningRequired',
      'ai_screening_required',
      'isAIInterviewEnabled',
      'isAiInterviewEnabled',
      'is_ai_interview_enabled',
      'aiInterviewEnabled',
      'ai_interview_enabled',
      'enableAiInterview',
      'enable_ai_interview',
      'requiresAiInterview',
      'requires_ai_interview',
      'requireAiInterview',
      'require_ai_interview',
      'aiInterviewRequired',
      'ai_interview_required',
      'hasAiInterview',
      'has_ai_interview',
      'useAiInterview',
      'use_ai_interview',
      'aiInterview',
      'ai_interview',
      'aiScreening',
      'ai_screening',
    ]) {
      if (_truthy(job[key])) return true;
    }

    for (final key in const [
      'aiInterview',
      'ai_interview',
      'aiInterviewConfig',
      'ai_interview_config',
      'aiInterviewSettings',
      'ai_interview_settings',
      'interviewConfig',
      'interview_config',
      'screeningConfig',
      'screening_config',
    ]) {
      final nested = job[key];
      if (nested is Map &&
          (_truthy(nested['enabled']) ||
              _truthy(nested['isEnabled']) ||
              _truthy(nested['is_enabled']) ||
              _truthy(nested['required']) ||
              _truthy(nested['isRequired']) ||
              _truthy(nested['is_required']) ||
              _aiWorkflowEnabled(
                Map<String, dynamic>.from(nested),
                customQuestions,
              ))) {
        return true;
      }
    }

    for (final key in const [
      'interviewType',
      'screeningType',
      'selectionFlow',
      'applicationFlow',
      'interviewMode',
      'interviewMethod',
      'applicationProcess',
      'selectionProcess',
      'recruitmentFlow',
    ]) {
      final value = _string(job[key]).toLowerCase();
      if (value == 'ai' ||
          value.contains('ai_screening') ||
          value.contains('ai_interview') ||
          value.contains('ai-interview') ||
          value.contains('ai interview') ||
          value.contains('ai-screening') ||
          value.contains('ai screening') ||
          value.contains('phỏng vấn ai')) {
        return true;
      }
    }

    return false;
  }

  static bool _truthy(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final value = _string(raw).toLowerCase();
    return value == 'true' ||
        value == '1' ||
        value == 'yes' ||
        value == 'y' ||
        value == 'enabled' ||
        value == 'on';
  }

  static double? _coordinate(dynamic raw, {required bool latitude}) {
    final value = _doubleOrNull(raw);
    if (value == null) return null;
    final isValid = latitude
        ? value >= -90 && value <= 90
        : value >= -180 && value <= 180;
    return isValid ? value : null;
  }

  static DateTime _date(dynamic raw) {
    return DateTime.tryParse(_string(raw))?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _firstDate(Iterable<dynamic> values) {
    for (final value in values) {
      final date = _dateOrNull(value);
      if (date != null) return date;
    }
    return null;
  }

  static DateTime? _dateOrNull(dynamic raw) {
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }

    final value = _string(raw);
    if (value.isEmpty) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _statusFrom(Map<String, dynamic> job) {
    return _firstNonEmpty([
      job['status'],
      job['jobStatus'],
      job['visibilityStatus'],
    ], fallback: 'active');
  }

  static String _firstNonEmpty(
    Iterable<dynamic> values, {
    String fallback = '',
  }) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String _string(dynamic raw) => raw?.toString().trim() ?? '';

  static String? _nullableString(dynamic raw) {
    final value = _string(raw);
    return value.isEmpty ? null : value;
  }

  static int _int(dynamic raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse(_string(raw).replaceAll(RegExp(r'[^\d-]'), '')) ?? 0;
  }

  static int _firstInt(Iterable<dynamic> values) {
    for (final value in values) {
      final parsed = _int(value);
      if (parsed != 0) return parsed;
    }
    return 0;
  }

  static double _double(dynamic raw) => _doubleOrNull(raw) ?? 0;

  static double _firstDouble(Iterable<dynamic> values) {
    for (final value in values) {
      final parsed = _doubleOrNull(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static double? _doubleOrNull(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(_string(raw));
  }

  static String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  static String _formatHours(double hours) {
    return hours == hours.truncateToDouble()
        ? hours.toInt().toString()
        : hours.toStringAsFixed(1);
  }

  @override
  Future<void> incrementJobViews(
    String jobId, {
    required bool isQuickJob,
  }) async {
    try {
      final baseUrl = isQuickJob ? _quickJobsUrl : _standardJobsUrl;
      final endpoint = isQuickJob
          ? '/quick-jobs/$jobId/views'
          : '/jobs/$jobId/views';
      await _client.post(Uri.parse('$baseUrl$endpoint'));
    } catch (error, stackTrace) {
      developer.log(
        'Không thể cập nhật lượt xem công việc',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class JobRepositoryException implements Exception {
  const JobRepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
