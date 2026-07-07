# Logo-Only Intro Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current F&B illustration introduction with a logo-only, correctly sized mobile intro and splash.

**Architecture:** Keep the existing `SplashScreen` and `IntroScreen` route flow and persistence behavior. Update only presentation, asset registration, and tests. No fake data or mock product content is introduced.

**Tech Stack:** Flutter, Riverpod, GoRouter, SharedPreferences, `flutter_test`.

---

## File Structure

- Modify: `pubspec.yaml`
  - Register `img/oppo-logo-color.png` as a Flutter asset.
- Modify: `lib/features/intro/presentation/splash_screen.dart`
  - Replace text splash logo with the real bundled logo image, sized responsively.
- Modify: `lib/features/intro/presentation/intro_screen.dart`
  - Replace old copy, benefits, and F&B illustration with centered logo tile and two actions.
- Modify: `test/intro_flow_test.dart`
  - Assert `/intro` shows the logo-only action surface, not old intro copy.
- Modify: `test/widget_test.dart`
  - Assert the introduction uses the logo asset and no longer depends on `img/intro.png`.

---

### Task 1: Update Tests For Logo-Only Intro

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `test/intro_flow_test.dart`

- [ ] **Step 1: Write failing intro asset test**

Replace the first test in `test/widget_test.dart` with:

```dart
testWidgets('introduction uses bundled logo asset only', (
  WidgetTester tester,
) async {
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: IntroductionScreen())),
  );

  expect(find.image(const AssetImage('img/oppo-logo-color.png')), findsOneWidget);
  expect(find.image(const AssetImage('img/intro.png')), findsNothing);
  expect(find.text('Bắt đầu hành trình sự nghiệp F&B của bạn'), findsNothing);
  expect(find.text('Tìm việc linh hoạt, thu nhập tức thì'), findsNothing);
}
```

- [ ] **Step 2: Update intro visibility expectations**

In `test/widget_test.dart`, update `shows introduction when unauthenticated` to expect the logo asset and actions:

```dart
expect(find.image(const AssetImage('img/oppo-logo-color.png')), findsOneWidget);
expect(find.text('Bắt đầu ngay'), findsOneWidget);
expect(find.text('Đăng nhập'), findsOneWidget);
expect(find.text('Tìm việc linh hoạt, thu nhập tức thì'), findsNothing);
```

- [ ] **Step 3: Update splash-to-intro expectation**

In `test/intro_flow_test.dart`, update `splash opens intro when intro has not been seen` to:

```dart
expect(find.byType(IntroScreen), findsOneWidget);
expect(find.image(const AssetImage('img/oppo-logo-color.png')), findsOneWidget);
expect(find.text('Bắt đầu ngay'), findsOneWidget);
expect(find.text('Tìm việc linh hoạt, thu nhập tức thì'), findsNothing);
```

- [ ] **Step 4: Run tests to verify RED**

Run:

```powershell
flutter test test/widget_test.dart test/intro_flow_test.dart
```

Expected: tests fail because `img/oppo-logo-color.png` is not registered/used and old intro content still renders.

---

### Task 2: Register Logo Asset

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add logo asset**

Update the `flutter.assets` section:

```yaml
  assets:
    - img/intro.png
    - img/oppo-logo-color.png
    - assets/fonts/
```

Keep `img/intro.png` registered for now so unrelated code is not broken accidentally. The intro screen will stop using it.

- [ ] **Step 2: Run asset test**

Run:

```powershell
flutter test test/widget_test.dart
```

Expected: still fails because production UI has not been updated.

---

### Task 3: Implement Logo-Only Intro Screen

**Files:**
- Modify: `lib/features/intro/presentation/intro_screen.dart`

- [ ] **Step 1: Replace old layout**

Remove the old headline, subtitle, `_FnbHeroIllustration`, and `_BenefitItem` UI from `IntroScreen`.

Use:

```dart
static const _logoAsset = 'img/oppo-logo-color.png';
static const _deepBlue = AppColors.primary;
static const _lightBlue = AppColors.secondary;
static const _backgroundTop = Color(0xFFF2F8FF);
static const _backgroundBottom = Colors.white;
```

Build a centered column constrained to `maxWidth: 360`, with page padding `24`.

- [ ] **Step 2: Add responsive sizing helpers**

Inside `_IntroScreenState`, compute:

```dart
final width = MediaQuery.sizeOf(context).width;
final logoTileSize = (width * 0.46).clamp(160.0, 196.0);
final logoImageWidth = (logoTileSize * 0.72).clamp(0.0, 140.0);
final buttonWidth = width.clamp(0.0, 280.0);
```

- [ ] **Step 3: Add logo tile and actions**

Render:

```dart
_LogoTile(size: logoTileSize, logoWidth: logoImageWidth),
const SizedBox(height: 28),
_ScaleTapButton(
  width: buttonWidth,
  isLoading: _isNavigating,
  onPressed: _continueToLogin,
  child: const Text('Bắt đầu ngay'),
),
const SizedBox(height: 14),
_SecondaryIntroButton(
  width: buttonWidth,
  onPressed: _isNavigating ? null : _continueToLogin,
  child: const Text('Đăng nhập'),
),
```

- [ ] **Step 4: Keep navigation behavior unchanged**

Do not change `_continueToLogin`. It must still call:

```dart
await ref.read(introControllerProvider.notifier).markIntroAsSeen();
context.go('/login');
```

- [ ] **Step 5: Run tests**

Run:

```powershell
flutter test test/widget_test.dart test/intro_flow_test.dart
```

Expected: intro-related tests pass.

---

### Task 4: Implement Logo Splash

**Files:**
- Modify: `lib/features/intro/presentation/splash_screen.dart`

- [ ] **Step 1: Replace text logo with real logo image**

Update `_SplashLogo` to use:

```dart
const _logoAsset = 'img/oppo-logo-color.png';
final width = MediaQuery.sizeOf(context).width;
final logoWidth = (width * 0.38).clamp(132.0, 160.0);

return Image.asset(
  _logoAsset,
  width: logoWidth,
  fit: BoxFit.contain,
);
```

- [ ] **Step 2: Preserve routing delay behavior**

Do not change `_routeFromIntroState` or its `Future.wait`.

- [ ] **Step 3: Run intro tests**

Run:

```powershell
flutter test test/intro_flow_test.dart
```

Expected: splash routing tests pass.

---

### Task 5: Verify And Commit

**Files:**
- Verify all modified files.

- [ ] **Step 1: Format Dart files**

Run:

```powershell
dart format lib/features/intro/presentation/intro_screen.dart lib/features/intro/presentation/splash_screen.dart test/widget_test.dart test/intro_flow_test.dart
```

Expected: formatter completes without errors.

- [ ] **Step 2: Run targeted tests**

Run:

```powershell
flutter test test/widget_test.dart test/intro_flow_test.dart
```

Expected: all tests pass.

- [ ] **Step 3: Run full test suite if targeted tests pass**

Run:

```powershell
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Commit implementation**

Run:

```powershell
git add pubspec.yaml lib/features/intro/presentation/intro_screen.dart lib/features/intro/presentation/splash_screen.dart test/widget_test.dart test/intro_flow_test.dart
git commit -m "feat: add logo-only intro experience"
```

Expected: implementation commit is created without staging temporary screenshot artifacts.
