import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_work_schedule.dart';

void main() {
  group('job work schedule', () {
    test('parses multiple weekday shift rules and stacks same-day shifts', () {
      final job = _job(
        shiftTime: 'T2,T3,T4,T5 @ 06:30 - 11:00 | T5,T6,T7 @ 08:00 - 11:30',
        recruitmentStartDate: DateTime(2026, 7),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(workShiftTimesForDate(job, DateTime(2026, 7, 2)), [
        '06:30 - 11:00',
        '08:00 - 11:30',
      ]);
      expect(workShiftTimesForDate(job, DateTime(2026, 7, 5)), isEmpty);
    });

    test('uses separate workDays and workHours as a weekly shift rule', () {
      final job = _job(
        shiftTime: '',
        workDays: 'T2,T4,T6',
        workHours: '07:00 - 11:30',
        recruitmentStartDate: DateTime(2026, 7),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(workShiftTimesForDate(job, DateTime(2026, 7, 3)), [
        '07:00 - 11:30',
      ]);
      expect(workShiftTimesForDate(job, DateTime(2026, 7, 4)), isEmpty);
    });

    test('uses quick job exact work date', () {
      final job = _job(
        shiftTime: '',
        workDate: '2026-07-04',
        startTime: '09:00',
        endTime: '13:00',
        recruitmentStartDate: DateTime(2026, 7),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(workShiftTimesForDate(job, DateTime(2026, 7, 4)), [
        '09:00 - 13:00',
      ]);
      expect(workShiftTimesForDate(job, DateTime(2026, 7, 5)), isEmpty);
    });

    test('finds the first scheduled date inside recruitment window', () {
      final job = _job(
        shiftTime: 'T5 @ 08:00 - 11:30',
        recruitmentStartDate: DateTime(2026, 7),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(firstScheduledWorkDate(job), DateTime(2026, 7, 2));
    });

    test('formats explicit weekdays separately from display shift time', () {
      final weekdayJob = _job(shiftTime: 'T2,T3,T4,T5,T6 @ 07:00 - 11:30');
      final splitScheduleJob = _job(
        shiftTime: 'T2,T3,T4,T5,T6 @ 07:00 - 12:00 | T7,CN @ 12:00 - 17:30',
      );
      final simpleShiftJob = _job(shiftTime: '07:00 - 12:00');

      expect(displayWorkShiftDays(weekdayJob), 'T2 - T6');
      expect(displayWorkShiftTime(weekdayJob), '07:00 - 11:30');
      expect(displayWorkShiftDays(splitScheduleJob), 'T2 - T6 | T7 - CN');
      expect(
        displayWorkShiftTime(splitScheduleJob),
        '07:00 - 12:00 | 12:00 - 17:30',
      );
      expect(displayWorkShiftDays(simpleShiftJob), isEmpty);
    });
  });
}

JobPost _job({
  required String shiftTime,
  String? workDays,
  String? workHours,
  String? workDate,
  String? startTime,
  String? endTime,
  DateTime? recruitmentStartDate,
  DateTime? recruitmentEndDate,
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
    shiftTime: shiftTime,
    workDays: workDays,
    workHours: workHours,
    workDate: workDate,
    startTime: startTime,
    endTime: endTime,
    description: 'Phục vụ khách hàng.',
    tags: const ['F&B'],
    postedAt: DateTime(2026, 6, 1),
    recruitmentStartDate: recruitmentStartDate,
    recruitmentEndDate: recruitmentEndDate,
  );
}
