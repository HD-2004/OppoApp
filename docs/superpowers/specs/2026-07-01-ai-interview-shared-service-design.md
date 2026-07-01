# AI Interview Shared Service Migration Design

## Goal

Migrate the AI interview capability from the website into the Flutter app by making the existing website `cv-ai` Lambda the shared AI Interview service for both web and app.

Phase 1 prioritizes low cost and low risk. The app will use the shared backend contract and the same application lifecycle as the website, while keeping the mobile UI simple. Audio recording, talking avatar media, fullscreen enforcement, and anti-cheat behavior are intentionally deferred.

## Current Context

The Flutter app lives in `C:\OppoApp`. It already has `AIScreeningScreen` and `AIInterviewChatScreen`, but those screens call `http://localhost:8000` directly. The app also has an in-repo FastAPI backend under `backend/app`, but that backend stores interview sessions in memory and is not the production shared service.

The website and serverless code live in `C:\OpPoReview`. The production-style AI service is `C:\OpPoReview\amplify\backend\cv-ai`. It exposes:

- `POST /api/v1/cv/screen`
- `POST /api/v1/interview/start`
- `POST /api/v1/interview/respond`
- `POST /api/v1/interview/media`
- `POST /api/v1/interview/audio-upload-url`
- `POST /api/v1/interview/upload-audio`

Phase 1 will use only the first three endpoints.

The app and website use the same Cognito User Pool:

- User pool: `ap-southeast-1_ShCajkmJd`
- App client: `2mv7qt4gpmq03dmlm0or9724n8`

The shared `cv-ai` endpoint is:

```text
https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod
```

## Recommended Approach

Use the website `cv-ai` Lambda as the shared AI Interview service and migrate the app to call it through a dedicated repository layer.

The app should not call AI endpoints directly from widgets. It should define domain models, a repository interface, an AWS-backed repository implementation, and Riverpod providers. This keeps network, auth, JSON parsing, timeout, and error mapping out of presentation code.

## Phase 1 Scope

Phase 1 includes:

- Add app configuration for `CV_AI_API_URL` via `String.fromEnvironment`.
- Add AI interview domain models.
- Add `AiInterviewRepository`.
- Add `AwsAiInterviewRepository` using `http.Client` and Cognito id token.
- Add Riverpod provider wiring.
- Replace `localhost:8000` calls in `AIScreeningScreen`.
- Replace `localhost:8000` calls in `AIInterviewChatScreen`.
- Align the app data lifecycle with the website:
  - Round 1 `fail`: do not create an application.
  - Round 1 `pass` or `review`: create the application immediately with AI screening fields.
  - Round 2 pass: update the existing application to `approved` with interview report fields.
  - Round 2 fail: show the result and do not update the application to `approved`.
- Add focused tests that use mocked clients and repositories instead of calling Gemini.

Phase 1 excludes:

- AI interviewer video or SadTalker media.
- Text-to-speech media service calls.
- Interview audio recording and S3 upload.
- Fullscreen enforcement.
- Tab/app-switch anti-cheat.
- Interview resume after app restart.
- Backend contract changes unless tests reveal an existing contract mismatch.

## Data Flow

When a candidate applies to an AI-screened job:

1. The candidate selects a CV.
2. The app builds a compact CV text from the authenticated profile and passes the selected CV URL to the shared service.
3. The app calls `POST /api/v1/cv/screen` with Cognito auth.
4. If the result is `fail`, the app displays the failure result and does not create an application.
5. If the result is `pass` or `review`, the app calls the existing application API to create an application with:
   - `aiScreeningScore`
   - `aiScreeningResult`
   - `aiScreeningReason`
   - `aiScreeningStrengths`
   - `aiScreeningWeaknesses`
6. The app keeps the returned `applicationId` in the in-memory AI flow state.
7. The candidate starts Round 2.
8. The app calls `POST /api/v1/interview/start` with Cognito auth.
9. The app displays the first AI question.
10. For each answer, the app calls `POST /api/v1/interview/respond`.
11. When the response has `finished = true`, the app reads `report`.
12. If `report.recommend_to_employer = true` or `report.total_score >= 60`, the app calls `PUT /applications/{applicationId}/status` with:
    - `status = approved`
    - `aiInterviewScore`
    - `aiInterviewReport`
13. If the report does not pass, the app displays the result and does not update the application to `approved`.

The pass threshold is `60` in Phase 1 to match the current website behavior.

## Cost Controls

The app must avoid unnecessary AI calls:

- Do not run AI screening for jobs without `isAiScreeningEnabled`.
- Do not call `/api/v1/cv/screen` if the candidate already has an application for the job.
- If an existing application is `pending`, show the pending state.
- If an existing application is `approved` and has no interview report, allow Round 2 without rerunning Round 1.
- If an existing application already has `aiInterviewReport`, show that the interview is complete.
- If an existing application is `rejected`, do not rerun AI.
- Do not call `/api/v1/interview/media`.
- Do not call `/api/v1/interview/audio-upload-url`.
- Do not call `/api/v1/interview/upload-audio`.
- Do not auto-retry AI requests indefinitely.
- Do not fallback to mock pass when the production AI service fails.

Timeouts:

- CV screening: 30 seconds.
- Interview start: 30 seconds.
- Interview respond: 35 seconds.

## Error Handling

The app should map shared service errors into user-facing Vietnamese messages:

- Missing auth token: ask the candidate to sign in again.
- HTTP 401: session expired.
- HTTP 403: account is not allowed to use this candidate feature.
- HTTP 422 or invalid payload: the app sent incomplete data and should show a retry-safe error.
- HTTP 429: AI service is busy; ask the user to try again later.
- HTTP 5xx: AI service temporarily unavailable.
- Timeout: show a manual retry button.
- Invalid JSON: show a generic service error and log the parse issue with `safePrint`.

For interview answer failures, the app should not lose the candidate's answer. The UI should keep the local answer visible or recoverable so the candidate can retry.

## App File Design

Create:

- `lib/core/config/api_config.dart`
  - Owns `cvAiApiBaseUrl`.
  - Reads `CV_AI_API_URL` from `String.fromEnvironment`.

- `lib/features/candidate/domain/ai_interview_models.dart`
  - `CvScreeningResult`
  - `InterviewStartResult`
  - `InterviewAnswerResult`
  - `InterviewReport`

- `lib/features/candidate/domain/ai_interview_repository.dart`
  - `screenCv`
  - `startInterview`
  - `respondInterview`

- `lib/features/candidate/data/aws_ai_interview_repository.dart`
  - Adds Cognito `Authorization` header.
  - Applies timeout per endpoint.
  - Decodes UTF-8 JSON.
  - Throws domain-friendly exceptions.

- `lib/features/candidate/application/ai_interview_providers.dart`
  - Riverpod provider for `AiInterviewRepository`.

Modify:

- `lib/features/candidate/presentation/ai_screening_screen.dart`
  - Use `AiInterviewRepository`.
  - Create application after Round 1 pass/review.
  - Pass `applicationId` into the interview screen.

- `lib/features/candidate/presentation/ai_interview_chat_screen.dart`
  - Use `AiInterviewRepository`.
  - Update the existing application after Round 2 pass.

- `lib/features/candidate/domain/application_repository.dart`
  - Add a flexible `updateApplicationStatus` contract if needed.

- `lib/features/candidate/data/aws_application_repository.dart`
  - Implement the update method if needed.

## Testing Strategy

Use tests that do not call Gemini:

- Backend contract check:
  - Run `python -m unittest -v` in `C:\OpPoReview\amplify\backend\cv-ai`.

- App repository tests:
  - Verify `screenCv` request body, auth header, success parsing, non-200 error, timeout.
  - Verify `startInterview` request body and response parsing.
  - Verify `respondInterview` finished and unfinished parsing.

- Application repository tests:
  - Verify `updateApplicationStatus` sends expected body and endpoint.

- Presentation flow tests:
  - Round 1 fail does not submit an application.
  - Round 1 pass/review submits an application with screening fields.
  - Round 2 pass updates the existing application with interview report.
  - Round 2 fail does not update to `approved`.

- Regression checks:
  - `rg "localhost:8000" lib test` returns no AI flow usage.
  - `rg "interview/media|audio-upload-url|upload-audio" lib test` confirms Phase 1 does not call deferred endpoints.

## Rollout

Build or run the app with:

```powershell
flutter run --dart-define=CV_AI_API_URL=https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod
```

Rollout should begin with one or two test jobs where `isAiScreeningEnabled = true`. Do not enable AI screening broadly until the app flow has passed manual smoke testing.

Manual smoke test:

1. Candidate signs in.
2. Candidate chooses an AI-screened job.
3. Candidate selects a CV.
4. Round 1 creates an application when result is `pass` or `review`.
5. Round 1 `fail` does not create an application.
6. Candidate completes Round 2.
7. Passing report updates the application to `approved`.
8. Website employer/candidate views show the same application and report.

## Success Criteria

- The Flutter app no longer calls `http://localhost:8000` for AI interview.
- The app and website use the same `cv-ai` backend contract.
- App AI requests include Cognito auth.
- App and website store AI screening/interview results in the same application fields.
- Phase 1 does not call media/audio endpoints.
- AI errors do not create fake successful applications.
- Tests cover the repository and critical screen flows without consuming Gemini credits.
