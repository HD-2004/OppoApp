# Popular Jobs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace personalized/search-driven job discovery with a "Cong viec pho bien nhat" section ranked by market signals.

**Architecture:** Add a small pure ranking module for popular jobs, extend `JobPost` with optional reputation/rating metrics, map those metrics from existing job payloads, and update the candidate home UI to consume real job lists directly. Remove recommendation/search-autocomplete code paths that only supported the old discovery surface.

**Tech Stack:** Flutter, Dart, Riverpod, flutter_test.

---

### Task 1: Popular Jobs Ranking Core

**Files:**
- Create: `lib/features/jobs/application/popular_jobs.dart`
- Create: `test/popular_jobs_test.dart`
- Modify: `lib/features/candidate/domain/job_post.dart`

- [ ] **Step 1: Write the failing ranking test**

Create `test/popular_jobs_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/jobs/application/popular_jobs.dart';

void main() {
  test('sorts popular jobs by applicants, reputation, rating, then newest', () {
    final oldest = _job(
      id: 'oldest',
      applicants: 4,
      employerReputationScore: 50,
      candidateRatingScore: 4.5,
      postedAt: DateTime(2026, 7, 1),
    );
    final highestApplicants = _job(
      id: 'highest-applicants',
      applicants: 8,
      employerReputationScore: 10,
      candidateRatingScore: 1,
      postedAt: DateTime(2026, 7, 1),
    );
    final bestReputation = _job(
      id: 'best-reputation',
      applicants: 4,
      employerReputationScore: 90,
      candidateRatingScore: 1,
      postedAt: DateTime(2026, 7, 1),
    );
    final bestRating = _job(
      id: 'best-rating',
      applicants: 4,
      employerReputationScore: 50,
      candidateRatingScore: 4.9,
      postedAt: DateTime(2026, 7, 1),
    );
    final newest = _job(
      id: 'newest',
      applicants: 4,
      employerReputationScore: 50,
      candidateRatingScore: 4.5,
      postedAt: DateTime(2026, 7, 9),
    );

    final result = sortJobsByPopularity([
      oldest,
      bestRating,
      highestApplicants,
      newest,
      bestReputation,
    ]);

    expect(result.map((job) => job.id), [
      'highest-applicants',
      'best-reputation',
      'best-rating',
      'newest',
      'oldest',
    ]);
  });
}

JobPost _job({
  required String id,
  required int applicants,
  required double employerReputationScore,
  required double candidateRatingScore,
  required DateTime postedAt,
}) {
  return JobPost(
    id: id,
    idJob: id,
    employerId: 'employer-$id',
    employerName: 'Employer $id',
    title: 'Job $id',
    jobType: JobPostType.partTime,
    location: 'Quan 1',
    salary: '35.000 VND/gio',
    shiftTime: '08:00 - 12:00',
    description: 'Popular job',
    tags: const ['F&B'],
    postedAt: postedAt,
    applicants: applicants,
    employerReputationScore: employerReputationScore,
    candidateRatingScore: candidateRatingScore,
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/popular_jobs_test.dart`

Expected: FAIL because `popular_jobs.dart` or the new `JobPost` named parameters do not exist.

- [ ] **Step 3: Implement the minimal ranking code**

In `lib/features/candidate/domain/job_post.dart`, add constructor params, fields, and `copyWith` preservation:

```dart
this.employerReputationScore = 0,
this.candidateRatingScore = 0,
```

```dart
final double employerReputationScore;
final double candidateRatingScore;
```

When returning from `copyWith`, pass:

```dart
employerReputationScore: employerReputationScore,
candidateRatingScore: candidateRatingScore,
```

Create `lib/features/jobs/application/popular_jobs.dart`:

```dart
import '../../candidate/domain/job_post.dart';

List<JobPost> sortJobsByPopularity(Iterable<JobPost> jobs) {
  final sorted = jobs.toList(growable: false);
  sorted.sort(compareJobsByPopularity);
  return sorted;
}

int compareJobsByPopularity(JobPost a, JobPost b) {
  final applicants = b.applicants.compareTo(a.applicants);
  if (applicants != 0) return applicants;

  final reputation = b.employerReputationScore.compareTo(
    a.employerReputationScore,
  );
  if (reputation != 0) return reputation;

  final rating = b.candidateRatingScore.compareTo(a.candidateRatingScore);
  if (rating != 0) return rating;

  return b.postedAt.compareTo(a.postedAt);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/popular_jobs_test.dart`

Expected: PASS.

### Task 2: Map Popularity Metrics From Job Payloads

**Files:**
- Modify: `test/aws_job_repository_test.dart`
- Modify: `lib/features/candidate/data/aws_job_repository.dart`

- [ ] **Step 1: Write mapper tests**

Add to `group('AwsJobRepository mapper', ...)` in `test/aws_job_repository_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/aws_job_repository_test.dart`

Expected: FAIL because mapper does not fill reputation/rating and may not map `applicationCount`.

- [ ] **Step 3: Implement metric mapping**

In both `mapStandardJob` and `mapQuickJob`, pass:

```dart
applicants: _firstInt([
  job['applicants'],
  job['applicationCount'],
  job['applicationsCount'],
  job['cvCount'],
  job['submittedCvCount'],
]),
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
```

Add helpers near `_int`/`_double`:

```dart
static int _firstInt(Iterable<dynamic> values) {
  for (final value in values) {
    final parsed = _int(value);
    if (parsed != 0) return parsed;
  }
  return 0;
}

static double _firstDouble(Iterable<dynamic> values) {
  for (final value in values) {
    final parsed = _doubleOrNull(value);
    if (parsed != null) return parsed;
  }
  return 0;
}
```

- [ ] **Step 4: Run mapper tests**

Run: `flutter test test/aws_job_repository_test.dart`

Expected: PASS.

### Task 3: Replace Home Recommendations With Popular Jobs

**Files:**
- Modify: `test/candidate_home_feed_test.dart`
- Modify: `lib/features/home/presentation/pages/candidate_home_page.dart`
- Modify: `lib/features/home/presentation/widgets/candidate_home_marketplace_sections.dart`

- [ ] **Step 1: Update failing home tests**

In `test/candidate_home_feed_test.dart`:

- Remove imports for `job_recommendation_providers.dart` and `job_recommendation.dart`.
- Remove `recommendations` from `_pumpHome`.
- Remove `personalizedJobRecommendationsProvider.overrideWith`.
- Change "Việc hợp bạn nhất" expectations to "Công việc phổ biến nhất".
- Change empty-state copy to "Tạm thời chưa có công việc phổ biến.".
- Add a test that passes jobs with different `applicants` and expects the most popular job title to appear before lower-ranked jobs in the section.

The key assertion should be:

```dart
expect(find.text('Công việc phổ biến nhất'), findsOneWidget);
expect(find.text('Việc hợp bạn nhất'), findsNothing);
expect(find.text('Tìm việc, công ty, bài đăng...'), findsNothing);
```

- [ ] **Step 2: Run home tests to verify failure**

Run: `flutter test test/candidate_home_feed_test.dart`

Expected: FAIL because production UI still renders recommendation/search UI.

- [ ] **Step 3: Update Home state and data flow**

In `candidate_home_page.dart`:

- Remove `dart:async`, `jobs_search_provider.dart`, recommendation imports, and search suggestion imports.
- Remove `_searchController`, `_searchFocusNode`, `_keyword`, debounce timer, `_keywordSuggestions`, `_searchFocused`, and their handlers.
- Remove invalidation/read/watch of `personalizedJobRecommendationsProvider`.
- Build `popularJobs = sortJobsByPopularity(filteredJobs).take(6).toList(growable: false);`.
- Pass only static header data to `HomeHeader`.
- Replace `RecommendedJobsSection` call with `PopularJobsSection`.

- [ ] **Step 4: Update Home widgets**

In `candidate_home_marketplace_sections.dart`:

- Remove `JobRecommendation` and `JobSuggestion` imports.
- Remove search/autocomplete parameters from `HomeHeader`.
- Remove the search field and suggestion panel from `HomeHeader`.
- Rename `RecommendedJobsSection` to `PopularJobsSection`.
- Change its input from `List<JobRecommendation>` to `List<JobPost>`.
- Render `JobCard(job: job, onTap: ..., onApply: ...)` without `matchScore`.
- Change title to `Công việc phổ biến nhất`.
- Change empty/error copy to popular-jobs language.

- [ ] **Step 5: Run home tests**

Run: `flutter test test/candidate_home_feed_test.dart`

Expected: PASS.

### Task 4: Remove Old Recommendation And Autocomplete Code

**Files:**
- Delete: `lib/features/recommendations/application/job_recommendation_providers.dart`
- Delete: `lib/features/recommendations/application/job_recommendation_service.dart`
- Delete: `lib/features/recommendations/domain/job_recommendation.dart`
- Delete: `lib/features/recommendations/presentation/ai_job_recommendations_modal.dart`
- Delete: `lib/features/search/application/suggestion_engine.dart`
- Delete: `lib/features/search/application/text_normalizer.dart`
- Delete: `lib/features/search/domain/job_suggestion.dart`
- Delete: `lib/features/search/presentation/pages/search_page.dart`
- Delete: `lib/features/search/presentation/widgets/employer_spotlight_row.dart`
- Delete: `lib/features/search/presentation/widgets/search_category_grid.dart`
- Delete: `lib/features/search/presentation/widgets/search_filter_pills.dart`
- Delete: `lib/features/search/presentation/widgets/search_job_card.dart`
- Delete: `test/job_recommendation_service_test.dart`
- Delete: `test/suggestion_engine_test.dart`
- Delete: `test/search_suggestions_widget_test.dart`
- Delete: `.kiro/specs/search-keyword-suggestions/`
- Modify: tests that still import recommendation provider.

- [ ] **Step 1: Search remaining references**

Run: `rg -n "JobRecommendation|personalizedJobRecommendationsProvider|JobRecommendationService|SuggestionEngine|JobSuggestion|search-keyword-suggestions|recommend-jobs|Falling back to local rule-based" lib test .kiro docs`

Expected: References remain before deletion.

- [ ] **Step 2: Delete obsolete files**

Use `apply_patch` delete hunks for tracked files. The whole `lib/features/search`
folder is obsolete because it is not routed or imported outside the removed
home autocomplete surface. For the untracked `.kiro/specs/search-keyword-suggestions/`,
delete with PowerShell only after verifying the path is exactly under
`C:\OppoApp\.kiro\specs\search-keyword-suggestions`.

- [ ] **Step 3: Update remaining tests**

For tests like `test/user_jobs_layout_test.dart` and `test/user_dashboard_search_test.dart`, remove recommendation provider overrides and imports. Keep their existing job-list assertions focused on job browsing, saved jobs, radius sorting, and dashboard tab behavior.

- [ ] **Step 4: Verify no removed-code references**

Run: `rg -n "JobRecommendation|personalizedJobRecommendationsProvider|JobRecommendationService|SuggestionEngine|JobSuggestion|search-keyword-suggestions|recommend-jobs|Falling back to local rule-based" lib test .kiro`

Expected: No output except unrelated docs if intentionally kept.

### Task 5: Final Verification

**Files:**
- Format and verify all touched Dart files.

- [ ] **Step 1: Format**

Run: `dart format lib test`

Expected: formatter completes successfully.

- [ ] **Step 2: Format check**

Run: `dart format --output=none --set-exit-if-changed lib test`

Expected: `0 changed`.

- [ ] **Step 3: Analyze**

Run: `flutter analyze`

Expected: `No issues found`.

- [ ] **Step 4: Test suite**

Run: `flutter test`

Expected: all tests pass.
