# Candidate Age Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an 18+ age gate for candidate registration and Google sign-in while persisting `dateOfBirth` to the profile.

**Architecture:** Use a shared age policy helper, add date of birth to registration data, persist it through profile creation, and route authenticated Google users without a saved birth date to a focused age verification screen.

**Tech Stack:** Flutter, Riverpod, GoRouter, Amplify Cognito, existing HTTP profile repository, Flutter widget tests.

---

### Task 1: Age Policy

**Files:**
- Create: `lib/features/auth/domain/candidate_age_policy.dart`
- Test: `test/candidate_age_policy_test.dart`

- [ ] Write tests for exact 18th birthday, one day under 18, future dates, invalid strings, and ISO formatting.
- [ ] Run the test and verify it fails because the helper does not exist.
- [ ] Implement `CandidateAgePolicy` with `isEligible`, `validateDateOfBirth`, and `formatDate`.
- [ ] Re-run the test and verify it passes.

### Task 2: Registration Date Of Birth

**Files:**
- Modify: `lib/features/auth/presentation/register_screen.dart`
- Modify: `lib/features/auth/data/auth_repository.dart`
- Modify: `lib/features/auth/data/user_profile_repository.dart`
- Modify: `lib/features/auth/data/aws_user_profile_repository.dart`
- Test: `test/auth_redesign_test.dart`
- Test: `test/aws_user_profile_repository_test.dart`

- [ ] Add widget tests that the register form shows `Ngày sinh`, requires it, and blocks under-18 submissions.
- [ ] Add repository test that profile creation payload includes `dateOfBirth`.
- [ ] Run those tests and verify they fail for missing behavior.
- [ ] Add a DOB controller, date picker, submit enablement, validation, request field, and profile payload field.
- [ ] Re-run focused tests and verify they pass.

### Task 3: Google Age Verification Route

**Files:**
- Create: `lib/features/auth/presentation/candidate_age_verification_screen.dart`
- Modify: `lib/app/router.dart`
- Modify: `lib/features/auth/application/auth_controller.dart`
- Test: `test/candidate_age_gate_router_test.dart`
- Test: `test/candidate_age_verification_screen_test.dart`

- [ ] Add tests for redirect decisions: authenticated profile without DOB goes to `/candidate/age-verification`, profile with DOB goes to `/candidate`, and the age route does not redirect to itself.
- [ ] Add widget tests for the age verification screen accepting eligible DOB and rejecting under-18 DOB.
- [ ] Run those tests and verify they fail for missing route and screen.
- [ ] Implement route helper, route registration, screen UI, save action, and under-18 sign-out action.
- [ ] Re-run focused tests and verify they pass.

### Task 4: Verification

**Files:**
- Modify only files touched by Tasks 1-3.

- [ ] Run focused Flutter tests for auth age gate.
- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
- [ ] Review `git diff` for unrelated changes and leave pre-existing `user_profile_screen.dart` untouched.
