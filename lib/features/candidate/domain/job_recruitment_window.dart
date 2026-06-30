import 'package:intl/intl.dart';

import 'job_post.dart';

enum JobPostVisibilityStatus { active, expired, archived, unknown }

final _vietnameseDateFormat = DateFormat('dd/MM/yyyy');

JobPostVisibilityStatus parseJobPostVisibilityStatus(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  return switch (value) {
    'active' || 'open' || 'published' => JobPostVisibilityStatus.active,
    'expired' || 'closed' || 'inactive' => JobPostVisibilityStatus.expired,
    'archived' || 'archive' => JobPostVisibilityStatus.archived,
    _ => JobPostVisibilityStatus.unknown,
  };
}

String formatRecruitmentDate(DateTime date) {
  return _vietnameseDateFormat.format(date);
}

String recruitmentWindowLabel(JobPost job) {
  return 'Tuyển dụng: ${recruitmentWindowValue(job)}';
}

String recruitmentWindowValue(JobPost job) {
  final start = job.recruitmentStartDate;
  final end = job.recruitmentEndDate;

  if (start == null && end == null) {
    return 'Không công khai';
  }
  if (start == null) {
    return 'Đến ${formatRecruitmentDate(end!)}';
  }
  if (end == null) {
    return 'Từ ${formatRecruitmentDate(start)}';
  }
  return '${formatRecruitmentDate(start)} - ${formatRecruitmentDate(end)}';
}

bool isJobPostExpired(JobPost job, {DateTime? now}) {
  final status = parseJobPostVisibilityStatus(job.status);
  if (status == JobPostVisibilityStatus.expired ||
      status == JobPostVisibilityStatus.archived) {
    return true;
  }

  final end = job.recruitmentEndDate;
  if (end == null) return false;

  final today = _dateOnly(now ?? DateTime.now());
  final endDate = _dateOnly(end);
  return today.isAfter(endDate);
}

bool isJobPostRecruitable(JobPost job, {DateTime? now}) {
  if (isJobPostExpired(job, now: now)) return false;

  final start = job.recruitmentStartDate;
  if (start == null) return true;

  final today = _dateOnly(now ?? DateTime.now());
  final startDate = _dateOnly(start);
  return !today.isBefore(startDate);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
