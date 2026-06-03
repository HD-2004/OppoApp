# Auth Intro Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter introduction screen and refresh login UI in the Ốp Pờ app.

**Architecture:** Add a dedicated `IntroductionScreen`, route unauthenticated users through `/intro`, and keep auth business logic in `LoginScreen` unchanged. Use small local widgets for illustration, benefit chips, and auth layout polish.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Flutter widget tests.

---

### Task 1: Widget Tests

**Files:**
- Modify: `test/widget_test.dart`

- [ ] Update unauthenticated app test to expect the introduction screen first.
- [ ] Add a widget test that taps `Bắt đầu ngay` and expects the refreshed login form.
- [ ] Run `flutter test test/widget_test.dart` and confirm it fails before implementation.

### Task 2: Introduction Route

**Files:**
- Create: `lib/features/auth/presentation/introduction_screen.dart`
- Modify: `lib/app/router.dart`

- [ ] Implement `IntroductionScreen` with brand, F&B illustration, value proposition, benefit row, CTA, and login link.
- [ ] Set router initial location to `/intro`.
- [ ] Include `/intro` in auth routes and unauthenticated redirect allow-list.

### Task 3: Login UI Refresh

**Files:**
- Modify: `lib/features/auth/presentation/login_screen.dart`
- Modify: `lib/features/auth/presentation/auth_form_fields.dart`

- [ ] Replace the basic app-bar layout with a light teal auth surface.
- [ ] Keep form validation and sign-in logic unchanged.
- [ ] Style fields, password toggle, submit button, forgot password, and register link to match intro.

### Task 4: Verify

**Files:**
- Test: `test/widget_test.dart`

- [ ] Run `dart format` on touched Dart files.
- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
