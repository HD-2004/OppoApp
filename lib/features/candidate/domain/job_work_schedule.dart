import '../../../core/formatters/app_date_formatter.dart';
import 'job_post.dart';

class JobWorkShiftRule {
  const JobWorkShiftRule({
    required this.timeRange,
    this.weekdays = const {},
    this.date,
  });

  final String timeRange;
  final Set<int> weekdays;
  final DateTime? date;

  bool matches(DateTime targetDate) {
    final target = _dateOnly(targetDate);
    final exactDate = date;
    if (exactDate != null) {
      return _dateOnly(exactDate) == target;
    }
    return weekdays.contains(target.weekday);
  }
}

List<JobWorkShiftRule> workShiftRulesFromJob(JobPost job) {
  final exactDate = _parseDateOnly(job.workDate);
  final exactTime =
      _timeRangeFromStartEnd(job.startTime, job.endTime) ??
      _simpleTimeRange(job.shiftTime) ??
      _simpleTimeRange(job.workHours);
  if (exactDate != null && exactTime != null) {
    return [JobWorkShiftRule(date: exactDate, timeRange: exactTime)];
  }

  final rules = <JobWorkShiftRule>[];
  _addRulesFromRaw(rules, job.shiftTime);
  _addRulesFromRaw(rules, job.workHours);

  final workDays = job.workDays?.trim();
  final workHours =
      _simpleTimeRange(job.workHours) ??
      _simpleTimeRange(job.shiftTime) ??
      _timeRangeFromStartEnd(job.startTime, job.endTime);
  if (workDays != null && workDays.isNotEmpty && workHours != null) {
    final weekdays = _weekdaysFrom(workDays);
    if (weekdays.isNotEmpty) {
      rules.add(JobWorkShiftRule(weekdays: weekdays, timeRange: workHours));
    }
  }

  if (rules.isEmpty) {
    final fallbackTime =
        _simpleTimeRange(job.shiftTime) ??
        _simpleTimeRange(job.workHours) ??
        _timeRangeFromStartEnd(job.startTime, job.endTime);
    if (fallbackTime != null) {
      rules.add(
        JobWorkShiftRule(
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          timeRange: fallbackTime,
        ),
      );
    }
  }

  return _dedupeRules(rules);
}

List<String> workShiftTimesForDate(JobPost job, DateTime date) {
  if (!_isInsideRecruitmentWindow(job, date)) return const [];

  final times = <String>[];
  for (final rule in workShiftRulesFromJob(job)) {
    if (_ruleAppliesToRecruitmentDate(rule, date) &&
        !times.contains(rule.timeRange)) {
      times.add(rule.timeRange);
    }
  }
  return times;
}

String displayWorkShiftTime(JobPost job) {
  final explicitTime = _timeRangeFromStartEnd(job.startTime, job.endTime);
  if (explicitTime != null) return explicitTime;

  final shiftTime = job.shiftTime.trim();
  final workHours = job.workHours?.trim();
  final hasWeekdayMarkers =
      shiftTime.contains('@') || (workHours?.contains('@') ?? false);
  if (hasWeekdayMarkers) {
    final times = <String>[];
    for (final rule in workShiftRulesFromJob(job)) {
      if (!times.contains(rule.timeRange)) {
        times.add(rule.timeRange);
      }
    }
    if (times.isNotEmpty) return times.join(' | ');
  }

  if (shiftTime.isNotEmpty) return shiftTime;
  if (workHours != null && workHours.isNotEmpty) return workHours;
  return '';
}

String displayWorkShiftDays(JobPost job) {
  final exactDate = _parseDateOnly(job.workDate);
  if (exactDate != null) {
    return AppDateFormatter.formatVietnameseDate(exactDate);
  }

  final hasExplicitDays =
      _hasWeekdayMarkers(job.shiftTime) ||
      _hasWeekdayMarkers(job.workHours) ||
      (job.workDays?.trim().isNotEmpty ?? false);
  if (!hasExplicitDays) return '';

  final labels = <String>[];
  for (final rule in workShiftRulesFromJob(job)) {
    final date = rule.date;
    final label = date != null
        ? AppDateFormatter.formatVietnameseDate(date)
        : _formatWeekdayRanges(rule.weekdays);
    if (label.isNotEmpty && !labels.contains(label)) {
      labels.add(label);
    }
  }

  return labels.join(' | ');
}

bool hasWorkScheduleOnDate(JobPost job, DateTime date) {
  return workShiftTimesForDate(job, date).isNotEmpty;
}

DateTime? firstScheduledWorkDate(JobPost job, {DateTime? from}) {
  final rules = workShiftRulesFromJob(job);
  if (rules.isEmpty) return null;

  final exactDates =
      rules
          .map((rule) => rule.date)
          .whereType<DateTime>()
          .map(_dateOnly)
          .where((date) => _isInsideRecruitmentWindow(job, date))
          .toList()
        ..sort();
  if (exactDates.isNotEmpty) return exactDates.first;

  var cursor = _dateOnly(job.recruitmentStartDate ?? from ?? DateTime.now());
  if (from != null && _dateOnly(from).isAfter(cursor)) {
    cursor = _dateOnly(from);
  }

  final end = _dateOnly(
    job.recruitmentEndDate ?? cursor.add(const Duration(days: 366)),
  );

  while (!cursor.isAfter(end)) {
    if (workShiftTimesForDate(job, cursor).isNotEmpty) return cursor;
    cursor = cursor.add(const Duration(days: 1));
  }
  return null;
}

DateTime? workScheduleInitialMonth(JobPost job) {
  return firstScheduledWorkDate(job) ??
      job.recruitmentStartDate ??
      _parseDateOnly(job.workDate);
}

void _addRulesFromRaw(List<JobWorkShiftRule> rules, String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return;

  final segments = value
      .split('|')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty);

  for (final segment in segments) {
    final marker = segment.indexOf('@');
    if (marker <= 0) continue;

    final weekdays = _weekdaysFrom(segment.substring(0, marker));
    final timeRange = _simpleTimeRange(segment.substring(marker + 1));
    if (weekdays.isEmpty || timeRange == null) continue;

    rules.add(JobWorkShiftRule(weekdays: weekdays, timeRange: timeRange));
  }
}

List<JobWorkShiftRule> _dedupeRules(List<JobWorkShiftRule> rules) {
  final seen = <String>{};
  final result = <JobWorkShiftRule>[];

  for (final rule in rules) {
    final key = [
      rule.date?.toIso8601String() ?? '',
      (rule.weekdays.toList()..sort()).join(','),
      rule.timeRange,
    ].join('|');
    if (seen.add(key)) result.add(rule);
  }

  return result;
}

Set<int> _weekdaysFrom(String raw) {
  final matches = RegExp(
    r'(t\s*[2-7]|thứ\s*[2-7]|thu\s*[2-7]|cn|chủ\s*nhật|chu\s*nhat)',
    caseSensitive: false,
    unicode: true,
  ).allMatches(raw);

  return matches
      .map((match) => _weekdayFromToken(match.group(0)!))
      .whereType<int>()
      .toSet();
}

int? _weekdayFromToken(String raw) {
  final value = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (value.contains('cn') ||
      value.contains('chủnhật') ||
      value.contains('chunhat')) {
    return DateTime.sunday;
  }
  for (var day = 2; day <= 7; day++) {
    if (value.contains(day.toString())) {
      return day - 1;
    }
  }
  return null;
}

String? _timeRangeFromStartEnd(String? startTime, String? endTime) {
  final start = startTime?.trim();
  final end = endTime?.trim();
  if (start == null || start.isEmpty || end == null || end.isEmpty) {
    return null;
  }
  return '$start - $end';
}

String? _simpleTimeRange(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || value.contains('@')) return null;
  return value;
}

bool _hasWeekdayMarkers(String? raw) {
  final value = raw?.trim();
  return value != null && value.isNotEmpty && value.contains('@');
}

String _formatWeekdayRanges(Set<int> weekdays) {
  if (weekdays.isEmpty) return '';

  final sorted = weekdays.toList()..sort();
  final ranges = <String>[];
  var start = sorted.first;
  var previous = start;

  for (final current in sorted.skip(1)) {
    if (current == previous + 1) {
      previous = current;
      continue;
    }
    ranges.add(_weekdayRangeLabel(start, previous));
    start = current;
    previous = current;
  }
  ranges.add(_weekdayRangeLabel(start, previous));

  return ranges.join(', ');
}

String _weekdayRangeLabel(int start, int end) {
  if (start == end) return _weekdayLabel(start);
  return '${_weekdayLabel(start)} - ${_weekdayLabel(end)}';
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'T2',
    DateTime.tuesday => 'T3',
    DateTime.wednesday => 'T4',
    DateTime.thursday => 'T5',
    DateTime.friday => 'T6',
    DateTime.saturday => 'T7',
    DateTime.sunday => 'CN',
    _ => '',
  };
}

DateTime? _parseDateOnly(String? raw) {
  return AppDateFormatter.parseDateOnly(raw);
}

bool _isInsideRecruitmentWindow(JobPost job, DateTime date) {
  final target = _dateOnly(date);
  final start = job.recruitmentStartDate;
  if (start != null && target.isBefore(_dateOnly(start))) return false;

  final end = job.recruitmentEndDate;
  if (end != null && target.isAfter(_dateOnly(end))) return false;

  return true;
}

bool _ruleAppliesToRecruitmentDate(JobWorkShiftRule rule, DateTime date) {
  if (!rule.matches(date)) return false;

  final exactDate = rule.date;
  if (exactDate == null) return true;
  return _dateOnly(exactDate) == _dateOnly(date);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
