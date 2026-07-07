# API CORS Profile Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix browser CORS failures so Flutter Web can read and update profile data, persist `dateOfBirth`, and call candidate recommendation APIs without `Failed to fetch`.

**Architecture:** Treat this as an API boundary problem first, not a Flutter routing problem. Verify the deployed API Gateway preflight behavior, repair CORS on the actual deployed API resources/stage, then use Flutter only to verify persistence and remove temporary fallback behavior if it hides real failures.

**Tech Stack:** Flutter Web, Dart `http`, AWS API Gateway, AWS CLI, Cognito bearer token, existing profile API at `https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod`.

---

## File Structure

- `fix_api_cors.ps1`: Extend or replace the current helper script so it configures CORS on the real API type and verifies headers after deployment.
- `docs/superpowers/plans/2026-07-07-api-cors-profile-repair.md`: This plan and execution checklist.
- `lib/features/auth/data/aws_user_profile_repository.dart`: Inspect only during initial repair; modify only if API verification shows Flutter sends incorrect headers or methods.
- `lib/features/auth/application/auth_controller.dart`: Inspect fallback behavior after CORS is fixed; modify only if fallback continues to mask failed persistence.
- `test/aws_user_profile_repository_test.dart`: Add tests only if Flutter request construction changes.

## Current Evidence

- Browser origin: `http://localhost:64746`.
- API origin: `https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com`.
- Failing resource: `/prod/profile/c91a85cc-80d1-705d-996d-865a8781a144`.
- Browser error says the preflight response has no `Access-Control-Allow-Origin`.
- Manual verification reproduced the problem: `OPTIONS /prod/profile/{userId}` returns `204` without CORS headers.
- Flutter age-gate logic is already covered by focused tests; the broken part is persistence through the API boundary.

## Success Criteria

- `OPTIONS /prod/profile/{userId}` with `Origin: http://localhost:64746` returns an `Access-Control-Allow-Origin` header.
- `OPTIONS /prod/profile/{userId}` allows `GET`, `PUT`, and `OPTIONS`.
- `OPTIONS /prod/profile/{userId}` allows `content-type` and `authorization`.
- `OPTIONS /prod/candidate/recommend-jobs` returns valid CORS headers for `POST`.
- After entering DOB in Flutter Web, the console no longer shows CORS errors for `PUT /profile/{userId}`.
- After reload or sign out/sign in, the same user still has `dateOfBirth`, so `/candidate/age-verification` does not appear again.

---

### Task 1: Capture The Failing CORS Baseline

**Files:**
- Modify: none

- [ ] **Step 1: Run profile PUT preflight check**

Run:

```powershell
curl.exe -i -X OPTIONS "https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/profile/c91a85cc-80d1-705d-996d-865a8781a144" `
  -H "Origin: http://localhost:64746" `
  -H "Access-Control-Request-Method: PUT" `
  -H "Access-Control-Request-Headers: content-type,authorization"
```

Expected failing output before repair:

```text
HTTP/1.1 204 No Content
```

Expected missing headers before repair:

```text
Access-Control-Allow-Origin
Access-Control-Allow-Methods
Access-Control-Allow-Headers
```

- [ ] **Step 2: Run candidate recommendation POST preflight check**

Run:

```powershell
curl.exe -i -X OPTIONS "https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/candidate/recommend-jobs" `
  -H "Origin: http://localhost:64746" `
  -H "Access-Control-Request-Method: POST" `
  -H "Access-Control-Request-Headers: content-type,authorization"
```

Expected failing output before repair:

```text
HTTP/1.1 200 OK
vary: Origin
```

Expected missing headers before repair:

```text
Access-Control-Allow-Origin
Access-Control-Allow-Methods
Access-Control-Allow-Headers
```

- [ ] **Step 3: Record whether the API is HTTP API v2 or REST API v1**

Run:

```powershell
$apiId = "sd7ds72m8g"
$region = "ap-southeast-1"

try {
  aws apigatewayv2 get-api --api-id $apiId --region $region
} catch {
  aws apigateway get-rest-api --rest-api-id $apiId --region $region
}
```

Expected result:

```text
One command returns API metadata. The successful command determines the repair path in Task 2 or Task 3.
```

---

### Task 2: Repair CORS If The API Is HTTP API v2

**Files:**
- Modify: `fix_api_cors.ps1`

- [ ] **Step 1: Update the HTTP API branch to include local and wildcard origins**

Replace the HTTP API update command in `fix_api_cors.ps1` with:

```powershell
$allowOrigins = "http://localhost:64746,http://localhost:*,http://127.0.0.1:*,https://hd-2004.github.io"

aws apigatewayv2 update-api `
  --api-id $apiId `
  --region $region `
  --cors-configuration "AllowOrigins=$allowOrigins,AllowMethods=GET,POST,PUT,DELETE,OPTIONS,AllowHeaders=content-type,authorization,MaxAge=3600" | Out-Host
```

- [ ] **Step 2: Run the script**

Run:

```powershell
.\fix_api_cors.ps1
```

Expected output:

```text
Detected HTTP API (v2)
CORS configuration applied to HTTP API
```

- [ ] **Step 3: Re-run Task 1 preflight checks**

Expected successful output:

```text
HTTP/1.1 204 No Content
access-control-allow-origin: http://localhost:64746
access-control-allow-methods: GET,POST,PUT,DELETE,OPTIONS
access-control-allow-headers: content-type,authorization
```

Proceed to Task 4.

---

### Task 3: Repair CORS If The API Is REST API v1

**Files:**
- Modify: `fix_api_cors.ps1`

- [ ] **Step 1: List deployed REST API resources**

Run:

```powershell
$apiId = "sd7ds72m8g"
$region = "ap-southeast-1"
aws apigateway get-resources --rest-api-id $apiId --region $region --limit 500
```

Expected resource paths to identify:

```text
/profile
/profile/{userId}
/profile/email/{email}
/candidate/recommend-jobs
```

- [ ] **Step 2: Add method response headers for GET, POST, PUT, and OPTIONS**

For each affected method on each affected resource, run this pattern with the actual `$resourceId` and `$method`:

```powershell
aws apigateway put-method-response `
  --rest-api-id $apiId `
  --resource-id $resourceId `
  --http-method $method `
  --status-code 200 `
  --response-parameters "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true" `
  --region $region
```

Use these method/resource combinations:

```text
GET /profile/{userId}
PUT /profile/{userId}
GET /profile/email/{email}
POST /profile
POST /candidate/recommend-jobs
```

- [ ] **Step 3: Add integration response headers for GET, POST, PUT, and OPTIONS**

For each affected method on each affected resource, run this pattern with the actual `$resourceId` and `$method`:

```powershell
aws apigateway put-integration-response `
  --rest-api-id $apiId `
  --resource-id $resourceId `
  --http-method $method `
  --status-code 200 `
  --response-parameters "method.response.header.Access-Control-Allow-Origin='*',method.response.header.Access-Control-Allow-Headers='content-type,authorization',method.response.header.Access-Control-Allow-Methods='GET,POST,PUT,DELETE,OPTIONS'" `
  --region $region
```

- [ ] **Step 4: Add or replace MOCK OPTIONS on each affected resource**

For each affected resource path, run this pattern with the actual `$resourceId`:

```powershell
aws apigateway put-method `
  --rest-api-id $apiId `
  --resource-id $resourceId `
  --http-method OPTIONS `
  --authorization-type NONE `
  --region $region

aws apigateway put-integration `
  --rest-api-id $apiId `
  --resource-id $resourceId `
  --http-method OPTIONS `
  --type MOCK `
  --request-templates '{"application/json":"{\"statusCode\": 200}"}' `
  --region $region

aws apigateway put-method-response `
  --rest-api-id $apiId `
  --resource-id $resourceId `
  --http-method OPTIONS `
  --status-code 200 `
  --response-parameters "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true" `
  --region $region

aws apigateway put-integration-response `
  --rest-api-id $apiId `
  --resource-id $resourceId `
  --http-method OPTIONS `
  --status-code 200 `
  --response-parameters "method.response.header.Access-Control-Allow-Origin='*',method.response.header.Access-Control-Allow-Headers='content-type,authorization',method.response.header.Access-Control-Allow-Methods='GET,POST,PUT,DELETE,OPTIONS'" `
  --region $region
```

- [ ] **Step 5: Deploy REST API stage**

Run:

```powershell
aws apigateway create-deployment `
  --rest-api-id sd7ds72m8g `
  --stage-name prod `
  --region ap-southeast-1
```

Expected output:

```text
Deployment metadata with an id and createdDate.
```

- [ ] **Step 6: Re-run Task 1 preflight checks**

Expected successful output:

```text
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS
Access-Control-Allow-Headers: content-type,authorization
```

Proceed to Task 4.

---

### Task 4: Verify Flutter Web Persistence

**Files:**
- Modify: none

- [ ] **Step 1: Run Flutter Web**

Run:

```powershell
flutter run -d chrome
```

Expected output:

```text
Flutter serves the app on a localhost port.
```

- [ ] **Step 2: Reproduce the age verification flow**

Manual steps:

```text
1. Sign in with the test user.
2. If redirected to /candidate/age-verification, enter 2004-08-20.
3. Submit.
4. Open DevTools Console.
```

Expected console result:

```text
No CORS error for PUT /prod/profile/{userId}
No "Saving date of birth to API failed" message
```

- [ ] **Step 3: Verify profile survives reload**

Manual steps:

```text
1. Refresh the browser tab.
2. Sign out.
3. Sign in again with the same user.
```

Expected UI result:

```text
The app opens /candidate, not /candidate/age-verification.
The profile page still shows the same date of birth.
```

- [ ] **Step 4: Verify recommendation API**

Manual steps:

```text
1. Navigate to candidate dashboard.
2. Open DevTools Console.
3. Trigger the candidate recommendations section.
```

Expected console result:

```text
No CORS error for POST /prod/candidate/recommend-jobs.
```

---

### Task 5: Decide Whether To Keep Or Tighten Flutter Fallback

**Files:**
- Inspect: `lib/features/auth/application/auth_controller.dart`
- Inspect: `lib/features/auth/data/auth_repository.dart`
- Test: focused auth tests only if behavior changes

- [ ] **Step 1: Inspect current fallback behavior**

Read:

```text
lib/features/auth/data/auth_repository.dart
lib/features/auth/application/auth_controller.dart
```

Current fallback behavior to review:

```text
Profile sync failed, using Cognito-derived profile
Saving date of birth to API failed, applying locally
```

- [ ] **Step 2: Choose fallback policy after CORS is fixed**

Use this policy:

```text
Keep login fallback so users are not locked out during transient API failures.
Change DOB save fallback only if product wants a visible warning when persistence fails.
Do not silently claim DOB is saved if the backend write failed.
```

- [ ] **Step 3: If changing fallback, add a focused test first**

Test file:

```text
test/candidate_age_verification_screen_test.dart
```

Behavior to test:

```text
When saveDateOfBirth fails, the screen shows a persistence warning instead of silently clearing the gate.
```

- [ ] **Step 4: Run focused tests**

Run:

```powershell
flutter test test/candidate_age_gate_router_test.dart test/candidate_age_verification_screen_test.dart test/candidate_age_policy_test.dart test/aws_user_profile_repository_test.dart
```

Expected output:

```text
All tests passed.
```

---

### Task 6: Final Verification

**Files:**
- Modify: none unless Task 5 changes Flutter behavior

- [ ] **Step 1: Run focused Flutter tests**

Run:

```powershell
flutter test test/candidate_age_gate_router_test.dart test/candidate_age_verification_screen_test.dart test/candidate_age_policy_test.dart test/aws_user_profile_repository_test.dart
```

Expected output:

```text
All tests passed.
```

- [ ] **Step 2: Run full Flutter tests if code changed**

Run:

```powershell
flutter test
```

Expected output:

```text
All tests passed.
```

- [ ] **Step 3: Run analyzer if code changed**

Run:

```powershell
flutter analyze
```

Expected output:

```text
No issues found.
```

- [ ] **Step 4: Re-run deployed CORS checks**

Run:

```powershell
curl.exe -i -X OPTIONS "https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/profile/c91a85cc-80d1-705d-996d-865a8781a144" `
  -H "Origin: http://localhost:64746" `
  -H "Access-Control-Request-Method: PUT" `
  -H "Access-Control-Request-Headers: content-type,authorization"

curl.exe -i -X OPTIONS "https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod/candidate/recommend-jobs" `
  -H "Origin: http://localhost:64746" `
  -H "Access-Control-Request-Method: POST" `
  -H "Access-Control-Request-Headers: content-type,authorization"
```

Expected output:

```text
Access-Control-Allow-Origin is present.
Access-Control-Allow-Methods is present.
Access-Control-Allow-Headers is present.
```

- [ ] **Step 5: Review changed files**

Run:

```powershell
git status --short
git diff -- fix_api_cors.ps1 lib/features/auth/application/auth_controller.dart lib/features/auth/data/auth_repository.dart
```

Expected result:

```text
Only intentional CORS repair script changes and optional fallback-policy changes are present.
```

