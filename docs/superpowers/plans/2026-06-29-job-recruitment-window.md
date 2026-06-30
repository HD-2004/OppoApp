# Job Recruitment Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a recruitment start/end date window to job posts, show that window on mobile job cards, move shift details into the job detail screen under `Lịch làm việc`, and hide or block expired posts.

**Architecture:** Extend `JobPost` with recruitment window fields and a normalized visibility status, then centralize date formatting and expiry checks in a small domain helper. Map backend date/status fields in `AwsJobRepository`, filter active provider results defensively on the client, and update candidate card/detail widgets to separate recruitment dates from work schedules.

**Tech Stack:** Flutter, Dart, Riverpod, existing REST-backed `AwsJobRepository`, Flutter widget tests.

---

## File Structure

- Create `lib/features/candidate/domain/job_recruitment_window.dart`
  - Owns `dd/MM/yyyy` formatting, active/expired/archive checks, and the list-card label text.
- Modify `lib/features/candidate/domain/job_post.dart`
  - Adds `recruitmentStartDate`, `recruitmentEndDate`, and `status`.
- Modify `lib/features/candidate/data/aws_job_repository.dart`
  - Maps backend fields to the new `JobPost` fields for standard and quick jobs.
- Modify `lib/features/candidate/application/jobs_providers.dart`
  - Filters stale expired/future/archived jobs before sorting.
- Modify `lib/features/candidate/presentation/widgets/job_post_card.dart`
  - Replaces list-card shift display with `Tuyển dụng: dd/MM/yyyy - dd/MM/yyyy`.
  - Keeps apply disabled if stale expired data reaches the card.
- Modify `lib/features/candidate/presentation/user_job_detail_screen.dart`
  - Shows `Thời gian tuyển dụng`.
  - Renames the shift section to `Lịch làm việc`.
  - Shows an expired notice and disables the sticky apply button for expired posts.
- Modify related tests under `test/`.

## Backend Contract Assumption

The app will consume these backend fields when available:

```json
{
  "recruitmentStartDate": "2026-07-01",
  "recruitmentEndDate": "2026-07-15",
  "status": "active"
}
```

The mapper should also accept compatible legacy names from AWS payloads:

```text
recruitmentStartDate | recruitmentStartDateTime | applicationStartDate | validFrom
recruitmentEndDate | recruitmentEndDateTime | applicationDeadline | deadline | expiresAt | expiryDate
status | jobStatus | visibilityStatus
```

The app must not invent dates when backend fields are missing. Missing dates display as `Tuyển dụng: Không công khai`.

---

### Task 1: Recruitment Window Domain Policy

**Files:**
- Create: `lib/features/candidate/domain/job_recruitment_window.dart`
- Modify: `lib/features/candidate/domain/job_post.dart`
- Test: `test/job_recruitment_window_test.dart`

- [ ] **Step 1: Write the failing domain tests**

Create `test/job_recruitment_window_test.dart`:

```dart
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

      expect(recruitmentWindowLabel(job), 'Tuyển dụng: 01/07/2026 - 15/07/2026');
    });

    test('uses conservative label when recruitment dates are missing', () {
      expect(recruitmentWindowLabel(_job()), 'Tuyển dụng: Không công khai');
      expect(
        recruitmentWindowLabel(_job(recruitmentStartDate: DateTime(2026, 7, 1))),
        'Tuyển dụng: Không công khai',
      );
    });

    test('keeps a job recruitable through the full end date', () {
      final job = _job(
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(isJobPostRecruitable(job, now: today), isTrue);
      expect(isJobPostExpired(job, now: today), isFalse);
    });

    test('marks job expired after the end date', () {
      final job = _job(
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );

      expect(
        isJobPostExpired(job, now: DateTime(2026, 7, 16)),
        isTrue,
      );
      expect(
        isJobPostRecruitable(job, now: DateTime(2026, 7, 16)),
        isFalse,
      );
    });

    test('blocks archived or explicitly expired jobs even inside date range', () {
      final expired = _job(
        status: 'expired',
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 30),
      );
      final archived = expired.copyWith(status: 'archived');

      expect(isJobPostRecruitable(expired, now: today), isFalse);
      expect(isJobPostRecruitable(archived, now: today), isFalse);
    });

    test('does not show future recruitment windows as active', () {
      final job = _job(
        recruitmentStartDate: DateTime(2026, 7, 20),
        recruitmentEndDate: DateTime(2026, 7, 30),
      );

      expect(isJobPostRecruitable(job, now: today), isFalse);
      expect(isJobPostExpired(job, now: today), isFalse);
    });
  });
}

JobPost _job({
  DateTime? recruitmentStartDate,
  DateTime? recruitmentEndDate,
  String? status = 'active',
}) {
  return JobPost(
    id: 'job-1',
    idJob: 'job-1',
    employerId: 'employer-1',
    employerName: 'Katinat',
    title: 'Nhân viên phục vụ',
    jobType: JobPostType.partTime,
    location: 'Quận 1',
    salary: '30.000 VNĐ/giờ',
    shiftTime: '18:00 - 22:00',
    description: 'Phục vụ khách hàng.',
    tags: const ['F&B'],
    postedAt: DateTime(2026, 7, 1),
    recruitmentStartDate: recruitmentStartDate,
    recruitmentEndDate: recruitmentEndDate,
    status: status,
  );
}
```

- [ ] **Step 2: Run the domain test and verify RED**

Run:

```powershell
flutter test test/job_recruitment_window_test.dart
```

Expected: FAIL because `job_recruitment_window.dart`, `JobPost.recruitmentStartDate`, `JobPost.recruitmentEndDate`, `JobPost.status`, and `JobPost.copyWith(status:)` do not exist.

- [ ] **Step 3: Extend `JobPost`**

In `lib/features/candidate/domain/job_post.dart`, add constructor parameters:

```dart
    this.recruitmentStartDate,
    this.recruitmentEndDate,
    this.status,
```

Add fields:

```dart
  final DateTime? recruitmentStartDate;
  final DateTime? recruitmentEndDate;
  final String? status;
```

Update `copyWith` signature:

```dart
    DateTime? recruitmentStartDate,
    DateTime? recruitmentEndDate,
    String? status,
```

Pass the new fields into the returned `JobPost`:

```dart
      recruitmentStartDate:
          recruitmentStartDate ?? this.recruitmentStartDate,
      recruitmentEndDate: recruitmentEndDate ?? this.recruitmentEndDate,
      status: status ?? this.status,
```

- [ ] **Step 4: Implement recruitment window helper**

Create `lib/features/candidate/domain/job_recruitment_window.dart`:

```dart
import 'job_post.dart';

enum JobPostVisibilityStatus { active, expired, archived, unknown }

JobPostVisibilityStatus parseJobPostVisibilityStatus(String? raw) {
  final value = raw?.trim().toLowerCase();
  return switch (value) {
    'active' || 'published' || 'open' => JobPostVisibilityStatus.active,
    'expired' => JobPostVisibilityStatus.expired,
    'archived' || 'closed' || 'inactive' => JobPostVisibilityStatus.archived,
    _ => JobPostVisibilityStatus.unknown,
  };
}

String formatRecruitmentDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString().padLeft(4, '0');
  return '$day/$month/$year';
}

String recruitmentWindowLabel(JobPost job) {
  final start = job.recruitmentStartDate;
  final end = job.recruitmentEndDate;
  if (start == null || end == null) {
    return 'Tuyển dụng: Không công khai';
  }
  return 'Tuyển dụng: ${formatRecruitmentDate(start)} - ${formatRecruitmentDate(end)}';
}

String recruitmentWindowValue(JobPost job) {
  final start = job.recruitmentStartDate;
  final end = job.recruitmentEndDate;
  if (start == null || end == null) {
    return 'Không công khai';
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
  if (end == null) {
    return false;
  }

  final currentDate = _dateOnly(now ?? DateTime.now());
  final endDate = _dateOnly(end);
  return currentDate.isAfter(endDate);
}

bool isJobPostRecruitable(JobPost job, {DateTime? now}) {
  final status = parseJobPostVisibilityStatus(job.status);
  if (status == JobPostVisibilityStatus.expired ||
      status == JobPostVisibilityStatus.archived) {
    return false;
  }

  final currentDate = _dateOnly(now ?? DateTime.now());
  final start = job.recruitmentStartDate;
  if (start != null && currentDate.isBefore(_dateOnly(start))) {
    return false;
  }

  if (isJobPostExpired(job, now: now)) {
    return false;
  }

  return true;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
```

- [ ] **Step 5: Run the domain test and verify GREEN**

Run:

```powershell
flutter test test/job_recruitment_window_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 1 if working on an isolated branch**

Run:

```powershell
git add lib/features/candidate/domain/job_post.dart lib/features/candidate/domain/job_recruitment_window.dart test/job_recruitment_window_test.dart
git commit -m "feat: add job recruitment window policy"
```

Expected: commit created. If executing in the current dirty workspace without commit approval, skip the commit and continue with the next task.

---

### Task 2: Map Recruitment Fields From Backend

**Files:**
- Modify: `lib/features/candidate/data/aws_job_repository.dart`
- Test: `test/aws_job_repository_test.dart`

- [ ] **Step 1: Write failing mapper tests**

Append the following tests inside the existing `AwsJobRepository mapper` test group in `test/aws_job_repository_test.dart`:

```dart
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

    test('maps quick job recruitment window from alternate backend keys', () {
      final job = AwsJobRepository.mapQuickJob({
        'jobID': 'quick-window',
        'applicationStartDate': '2026-07-03T08:00:00Z',
        'applicationDeadline': '2026-07-20T23:59:59Z',
        'jobStatus': 'expired',
      });

      expect(job.recruitmentStartDate, DateTime(2026, 7, 3));
      expect(job.recruitmentEndDate, DateTime(2026, 7, 20));
      expect(job.status, 'expired');
    });
```

- [ ] **Step 2: Run mapper tests and verify RED**

Run:

```powershell
flutter test test/aws_job_repository_test.dart
```

Expected: FAIL because the mapper does not populate the new fields.

- [ ] **Step 3: Add mapper helpers**

In `lib/features/candidate/data/aws_job_repository.dart`, add helpers near `_date`:

```dart
  static DateTime? _dateOrNull(dynamic raw) {
    final value = _string(raw);
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? _firstDate(Iterable<dynamic> values) {
    for (final value in values) {
      final parsed = _dateOrNull(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _statusFrom(Map<String, dynamic> job) {
    return _nullableString(
      job['status'] ?? job['jobStatus'] ?? job['visibilityStatus'],
    );
  }
```

- [ ] **Step 4: Populate fields in `mapStandardJob`**

In the `JobPost(` call inside `mapStandardJob`, add:

```dart
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
```

- [ ] **Step 5: Populate fields in `mapQuickJob`**

In the `JobPost(` call inside `mapQuickJob`, add the same field block:

```dart
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
```

- [ ] **Step 6: Run mapper tests and verify GREEN**

Run:

```powershell
flutter test test/aws_job_repository_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit Task 2 if working on an isolated branch**

Run:

```powershell
git add lib/features/candidate/data/aws_job_repository.dart test/aws_job_repository_test.dart
git commit -m "feat: map job recruitment window fields"
```

Expected: commit created. If executing in the current dirty workspace without commit approval, skip the commit and continue.

---

### Task 3: Filter Expired And Future Jobs In Providers

**Files:**
- Modify: `lib/features/candidate/application/jobs_providers.dart`
- Test: `test/jobs_providers_test.dart`
- Test: `test/user_jobs_layout_test.dart`

- [ ] **Step 1: Write provider filter tests**

Append to `test/jobs_providers_test.dart`:

```dart
test('active jobs provider hides expired, archived, and future jobs', () async {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      jobRepositoryProvider.overrideWithValue(
        _StaticJobRepository([
          _job(id: 'active', start: DateTime(2026, 1, 1), end: DateTime(2099, 1, 1)),
          _job(id: 'expired', start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 2)),
          _job(id: 'archived', start: DateTime(2026, 1, 1), end: DateTime(2099, 1, 1), status: 'archived'),
          _job(id: 'future', start: DateTime(2099, 1, 2), end: DateTime(2099, 1, 3)),
        ]),
      ),
    ],
  );
  addTearDown(container.dispose);

  final jobs = await container.read(activeJobsProvider.future);

  expect(jobs.map((job) => job.idJob), ['active']);
});
```

Add helper classes at the bottom of `test/jobs_providers_test.dart`:

```dart
class _StaticJobRepository implements JobRepository {
  _StaticJobRepository(this.jobs);

  final List<JobPost> jobs;

  @override
  Future<List<JobPost>> getActiveJobs() async => jobs;

  @override
  Future<List<JobPost>> getActiveQuickJobs() async => jobs;

  @override
  Future<void> incrementJobViews(String jobId, {required bool isQuickJob}) async {}
}

JobPost _job({
  required String id,
  required DateTime start,
  required DateTime end,
  String status = 'active',
}) {
  return JobPost(
    id: id,
    idJob: id,
    employerId: 'employer-1',
    employerName: 'Katinat',
    title: 'Nhân viên phục vụ',
    jobType: JobPostType.partTime,
    location: 'Quận 1',
    salary: '30.000 VNĐ/giờ',
    shiftTime: '18:00 - 22:00',
    description: 'Phục vụ khách hàng.',
    tags: const ['F&B'],
    postedAt: DateTime(2026, 7, 1),
    recruitmentStartDate: start,
    recruitmentEndDate: end,
    status: status,
  );
}
```

- [ ] **Step 2: Update saved-job test data to include active recruitment windows**

In `test/user_jobs_layout_test.dart`, add the new fields to `_job`, `_secondJob`, and `_quickJob` so existing tests keep representing active jobs:

```dart
  recruitmentStartDate: DateTime(2026, 1, 1),
  recruitmentEndDate: DateTime(2099, 1, 1),
  status: 'active',
```

- [ ] **Step 3: Run provider tests and verify RED**

Run:

```powershell
flutter test test/jobs_providers_test.dart test/user_jobs_layout_test.dart
```

Expected: FAIL because providers do not filter expired, archived, or future jobs yet.

- [ ] **Step 4: Filter provider results defensively**

In `lib/features/candidate/application/jobs_providers.dart`, import the helper:

```dart
import '../domain/job_recruitment_window.dart';
```

Add this function:

```dart
List<JobPost> filterRecruitableJobs(List<JobPost> jobs) {
  return jobs
      .where((job) => isJobPostRecruitable(job))
      .toList(growable: false);
}
```

Update `activeJobsProvider`:

```dart
  final jobs = await repository.getActiveJobs();
  return sortJobsByVisibilityThenCreatedAt(filterRecruitableJobs(jobs));
```

Update `activeQuickJobsProvider`:

```dart
  final jobs = await repository.getActiveQuickJobs();
  return sortJobsByVisibilityThenCreatedAt(filterRecruitableJobs(jobs));
```

- [ ] **Step 5: Run provider tests and verify GREEN**

Run:

```powershell
flutter test test/jobs_providers_test.dart test/user_jobs_layout_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3 if working on an isolated branch**

Run:

```powershell
git add lib/features/candidate/application/jobs_providers.dart test/jobs_providers_test.dart test/user_jobs_layout_test.dart
git commit -m "feat: filter non-recruitable jobs"
```

Expected: commit created. If executing in the current dirty workspace without commit approval, skip the commit and continue.

---

### Task 4: Update Candidate Job Card

**Files:**
- Modify: `lib/features/candidate/presentation/widgets/job_post_card.dart`
- Test: `test/job_post_card_test.dart`
- Test: `test/job_post_card_grid_overflow_test.dart`

- [ ] **Step 1: Write card display tests**

In `test/job_post_card_test.dart`, update `_job` to include:

```dart
  recruitmentStartDate: DateTime(2026, 7, 1),
  recruitmentEndDate: DateTime(2026, 7, 15),
  status: 'active',
```

In the first test, replace:

```dart
    expect(find.text('18:00 - 22:00'), findsOneWidget);
```

with:

```dart
    expect(find.text('Tuyển dụng'), findsOneWidget);
    expect(find.text('01/07/2026 - 15/07/2026'), findsOneWidget);
    expect(find.text('18:00 - 22:00'), findsNothing);
```

Add a new widget test:

```dart
testWidgets('job post card disables apply for stale expired job data', (
  tester,
) async {
  var applyTapCount = 0;
  final expiredJob = _job.copyWith(
    recruitmentStartDate: DateTime(2026, 7, 1),
    recruitmentEndDate: DateTime(2026, 7, 15),
    status: 'expired',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JobPostCard(
          job: expiredJob,
          onDetailsPressed: () {},
          onApplyPressed: () => applyTapCount++,
        ),
      ),
    ),
  );

  expect(find.text('Đã hết hạn'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Đã hết hạn'));
  await tester.pump();

  expect(applyTapCount, 0);
});
```

- [ ] **Step 2: Run card tests and verify RED**

Run:

```powershell
flutter test test/job_post_card_test.dart test/job_post_card_grid_overflow_test.dart
```

Expected: FAIL because the card still shows `Thời gian` and `shiftTime` on the list card, and expired card apply is not disabled.

- [ ] **Step 3: Update card imports and values**

In `lib/features/candidate/presentation/widgets/job_post_card.dart`, import:

```dart
import '../../domain/job_recruitment_window.dart';
```

In `build`, replace:

```dart
    final shiftTime = _shiftTime(job);
```

with:

```dart
    final recruitmentWindow = recruitmentWindowValue(job);
    final isExpired = isJobPostExpired(job);
```

- [ ] **Step 4: Replace shift row with recruitment window row**

Replace the shift row block:

```dart
                  if (shiftTime.isNotEmpty)
                    _JobInfoRowData(
                      label: 'Thời gian',
                      value: shiftTime,
                      icon: Icons.schedule_rounded,
                    ),
```

with:

```dart
                  _JobInfoRowData(
                    label: 'Tuyển dụng',
                    value: recruitmentWindow,
                    icon: Icons.event_available_outlined,
                  ),
```

- [ ] **Step 5: Disable expired apply button**

Replace button `onPressed`:

```dart
                  onPressed: isApplying ? null : onApplyPressed,
```

with:

```dart
                  onPressed: isApplying || isExpired ? null : onApplyPressed,
```

Replace button text:

```dart
                        : const Text(
                            'Ứng tuyển ngay',
```

with:

```dart
                        : Text(
                            isExpired ? 'Đã hết hạn' : 'Ứng tuyển ngay',
```

- [ ] **Step 6: Remove unused `_shiftTime` helper only if no references remain in this file**

Run:

```powershell
rg -n "_shiftTime" lib/features/candidate/presentation/widgets/job_post_card.dart
```

If the only reference is the helper declaration, delete the helper:

```dart
String _shiftTime(JobPost job) {
  final startTime = job.startTime?.trim();
  final endTime = job.endTime?.trim();
  if (startTime != null &&
      startTime.isNotEmpty &&
      endTime != null &&
      endTime.isNotEmpty) {
    return '$startTime - $endTime';
  }

  final shiftTime = job.shiftTime.trim();
  if (shiftTime.isNotEmpty) {
    return shiftTime;
  }

  return '';
}
```

- [ ] **Step 7: Run card tests and verify GREEN**

Run:

```powershell
flutter test test/job_post_card_test.dart test/job_post_card_grid_overflow_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit Task 4 if working on an isolated branch**

Run:

```powershell
git add lib/features/candidate/presentation/widgets/job_post_card.dart test/job_post_card_test.dart test/job_post_card_grid_overflow_test.dart
git commit -m "feat: show recruitment window on job cards"
```

Expected: commit created. If executing in the current dirty workspace without commit approval, skip the commit and continue.

---

### Task 5: Update Job Detail Screen

**Files:**
- Modify: `lib/features/candidate/presentation/user_job_detail_screen.dart`
- Test: `test/user_job_detail_screen_test.dart`

- [ ] **Step 1: Write detail screen tests**

In `test/user_job_detail_screen_test.dart`, update `_job`:

```dart
  shiftTime: 'T2,T3,T4,T5 @ 06:30 - 11:00 | T5,T6,T7 @ 08:00 - 11:30',
  recruitmentStartDate: DateTime(2026, 7, 1),
  recruitmentEndDate: DateTime(2026, 7, 15),
  status: 'active',
```

Add assertions to the existing test:

```dart
    expect(find.text('Thời gian tuyển dụng'), findsOneWidget);
    expect(find.text('01/07/2026 - 15/07/2026'), findsOneWidget);
    expect(find.text('Lịch làm việc'), findsOneWidget);
    expect(find.textContaining('06:30 - 11:00'), findsOneWidget);
```

Add a new test:

```dart
testWidgets('job detail disables apply for expired posts', (tester) async {
  var applyTapCount = 0;
  final expiredJob = _job.copyWith(status: 'expired');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [jobRepositoryProvider.overrideWithValue(_FakeJobRepo())],
      child: MaterialApp(
        home: UserJobDetailScreen(
          job: expiredJob,
          onApplyPressed: () => applyTapCount++,
        ),
      ),
    ),
  );

  await tester.pump();

  expect(find.text('Tin tuyển dụng đã hết hạn'), findsOneWidget);
  expect(find.text('Đã hết hạn'), findsOneWidget);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Đã hết hạn'));
  await tester.pump();

  expect(applyTapCount, 0);
});
```

- [ ] **Step 2: Run detail tests and verify RED**

Run:

```powershell
flutter test test/user_job_detail_screen_test.dart
```

Expected: FAIL because detail screen does not show recruitment window, does not use `Lịch làm việc`, and does not disable expired apply.

- [ ] **Step 3: Import recruitment helper**

In `lib/features/candidate/presentation/user_job_detail_screen.dart`, add:

```dart
import '../domain/job_recruitment_window.dart';
```

- [ ] **Step 4: Add expired state in `build`**

At the start of `build`, before `return Scaffold(`:

```dart
    final isExpired = isJobPostExpired(widget.job);
```

Update `_StickyApplyBar` call:

```dart
              child: _StickyApplyBar(
                onApply: widget.onApplyPressed,
                isAiEnabled: widget.job.isAiScreeningEnabled,
                isExpired: isExpired,
              ),
```

- [ ] **Step 5: Show expired notice after quick info**

After `_QuickInfoSection(job: widget.job),` add:

```dart
                    if (isExpired) const _ExpiredJobNotice(),
```

Add widget near `_QuickInfoSection`:

```dart
class _ExpiredJobNotice extends StatelessWidget {
  const _ExpiredJobNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDA4AF)),
        ),
        child: const Text(
          'Tin tuyển dụng đã hết hạn',
          style: TextStyle(
            color: Color(0xFFBE123C),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Update quick info labels**

In `_QuickInfoSection.build`, replace:

```dart
    final shiftTime = _resolveShiftTime();
```

with:

```dart
    final shiftTime = _resolveShiftTime();
    final recruitmentWindow = recruitmentWindowValue(job);
```

After the location tile, insert:

```dart
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.event_available_outlined,
            iconBg: AppColors.primarySoft,
            iconColor: AppColors.primary,
            label: 'Thời gian tuyển dụng',
            value: recruitmentWindow,
          ),
```

Replace the existing time tile label:

```dart
              label: 'THỜI GIAN',
```

with:

```dart
              label: 'Lịch làm việc',
```

- [ ] **Step 7: Update `_InfoTile` label styling to support normal-case labels**

In `_InfoTile`, replace hardcoded all-caps label styling:

```dart
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                  letterSpacing: 0.5,
```

with:

```dart
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
```

This keeps `Lịch làm việc` visually readable instead of forcing an all-caps metadata style.

- [ ] **Step 8: Disable sticky apply button when expired**

Update `_StickyApplyBar` constructor:

```dart
  const _StickyApplyBar({
    required this.onApply,
    required this.isAiEnabled,
    required this.isExpired,
  });

  final VoidCallback onApply;
  final bool isAiEnabled;
  final bool isExpired;
```

Update `ElevatedButton`:

```dart
              onPressed: isExpired ? null : onApply,
```

Update button child:

```dart
              child: Text(
                isExpired ? 'Đã hết hạn' : 'Ứng tuyển ngay',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
```

- [ ] **Step 9: Run detail tests and verify GREEN**

Run:

```powershell
flutter test test/user_job_detail_screen_test.dart
```

Expected: PASS.

- [ ] **Step 10: Commit Task 5 if working on an isolated branch**

Run:

```powershell
git add lib/features/candidate/presentation/user_job_detail_screen.dart test/user_job_detail_screen_test.dart
git commit -m "feat: show recruitment window in job details"
```

Expected: commit created. If executing in the current dirty workspace without commit approval, skip the commit and continue.

---

### Task 6: Verification And Regression Sweep

**Files:**
- Verify all files touched in Tasks 1-5.

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
dart format lib/features/candidate/domain/job_post.dart lib/features/candidate/domain/job_recruitment_window.dart lib/features/candidate/data/aws_job_repository.dart lib/features/candidate/application/jobs_providers.dart lib/features/candidate/presentation/widgets/job_post_card.dart lib/features/candidate/presentation/user_job_detail_screen.dart test/job_recruitment_window_test.dart test/aws_job_repository_test.dart test/jobs_providers_test.dart test/job_post_card_test.dart test/job_post_card_grid_overflow_test.dart test/user_job_detail_screen_test.dart test/user_jobs_layout_test.dart
```

Expected: formatter completes without errors.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test test/job_recruitment_window_test.dart test/aws_job_repository_test.dart test/jobs_providers_test.dart test/job_post_card_test.dart test/job_post_card_grid_overflow_test.dart test/user_job_detail_screen_test.dart test/user_jobs_layout_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run full test suite**

Run:

```powershell
flutter test
```

Expected: PASS with all tests.

- [ ] **Step 4: Run analyzer**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Check diff hygiene**

Run:

```powershell
git diff --check
git status --short
```

Expected:

- `git diff --check` prints no output and exits 0.
- `git status --short` shows only intended files for this feature plus any pre-existing unrelated dirty files. Do not revert unrelated files such as `lib/features/candidate/presentation/user_profile_screen.dart`.

## Spec Coverage Self-Review

- Recruitment start/end date fields: Task 1 and Task 2.
- `dd/MM/yyyy` display: Task 1, Task 4, Task 5.
- End date valid through the full day: Task 1.
- Expired posts hidden from candidate lists: Task 3.
- Expired posts retained instead of deleted: backend contract note and client behavior in Task 3/Task 5.
- Card outside shows recruitment window only: Task 4.
- Detail screen shows `Thời gian tuyển dụng` and `Lịch làm việc`: Task 5.
- Expired detail disables applying: Task 5.
- Whole-app date-format reminder remains in the spec: `docs/superpowers/specs/2026-06-29-job-recruitment-window-design.md`.
