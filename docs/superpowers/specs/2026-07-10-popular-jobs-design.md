# Popular Jobs Design

## Decision

Replace personalized job recommendations and search/autocomplete discovery with a
market-driven "Cong viec pho bien nhat" experience.

The removed direction is any multi-API aggregation plan that separately calls
application, employer, or review APIs to compute popularity. That approach is
out of scope for this project plan.

## Goals

- Remove AI/local personalized recommendation behavior from the candidate app.
- Remove normal search/autocomplete discovery from the candidate home/search
  experience.
- Show popular jobs based on objective market signals instead of candidate
  profile matching.
- Keep job browsing, opening job details, and applying to jobs working as they
  do now.

## Ranking

Popular jobs are sorted by these signals in order:

1. Number of submitted CVs/applications for the job, descending.
2. Employer reputation score, descending.
3. Candidate rating score, descending.
4. Newest posting date, descending, as a deterministic fallback.

The current app already exposes `JobPost.applicants`. The domain model will be
extended with `employerReputationScore` and `candidateRatingScore`, both
defaulting to `0` when the backend does not provide those values. This makes the
first implementation behave like the approved MVP ranking while keeping the
model ready for real reputation/rating fields later.

## Data Flow

The popular jobs section reads the same real job lists already used by the home
screen:

- `activeQuickJobsProvider`
- `activeJobsProvider`

The app combines the lists, deduplicates by job id, keeps the current active and
recruitable filtering from the providers, then applies the popular-jobs sort.

No AI recommendation endpoint is called. No local personalized recommendation
fallback is used. No profile, CV text, or candidate application history is needed
to compute the popular jobs list.

## UI Changes

Home will replace "Viec hop ban nhat" with "Cong viec pho bien nhat".

The section keeps the existing horizontal job-card behavior:

- Tap a card to open `UserJobDetailScreen`.
- Tap apply to continue the existing application flow.
- Tap "See all" to open the existing jobs list.

Search/autocomplete UI will be removed from the home/search discovery flow. The
candidate should see curated popular jobs and existing job lists instead of a
search-driven recommendation surface.

## Removed Code Paths

The implementation should remove or stop using:

- `personalizedJobRecommendationsProvider`
- AI `/candidate/recommend-jobs` calls
- local rule-based `JobRecommendationService` fallback
- `AiJobRecommendationsModal`
- recommendation domain/presentation code that is no longer referenced
- search suggestion/autocomplete code that only served the removed discovery UI

If any remaining tests or widgets depend on those paths, they should be updated
to assert popular jobs behavior instead.

## Error Handling

If one job list fails but the other succeeds, the app should still render the
available jobs where current provider behavior allows it. If no jobs are
available, the section shows an empty state for popular jobs rather than a
recommendation/profile message.

Missing reputation or rating fields are not errors. They rank as `0`.

## Testing

Add or update tests for:

- Popular jobs sort order: applicants first, employer reputation second,
  candidate rating third, newest posting fourth.
- Job mapper defaults missing reputation/rating fields to `0`.
- Home renders "Cong viec pho bien nhat" and does not use recommendation
  provider overrides.
- Removed search/autocomplete UI no longer appears in the candidate home flow.

Verification commands:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
