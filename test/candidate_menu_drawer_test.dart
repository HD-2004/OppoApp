import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/home/presentation/widgets/candidate_menu_drawer.dart';

void main() {
  testWidgets('candidate drawer shows app-only navigation items', (
    tester,
  ) async {
    var openedProfile = false;
    var openedJobs = false;
    var openedWallet = false;
    var openedNotifications = false;
    var openedSettings = false;
    var openedSupport = false;
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateMenuDrawer(
            displayName: 'An',
            email: 'an@example.com',
            onProfileTap: () => openedProfile = true,
            onJobsTap: () => openedJobs = true,
            onWalletTap: () => openedWallet = true,
            onNotificationsTap: () => openedNotifications = true,
            onSettingsTap: () => openedSettings = true,
            onSupportTap: () => openedSupport = true,
            onSignOutTap: () => signedOut = true,
          ),
        ),
      ),
    );

    expect(find.text('An'), findsOneWidget);
    expect(find.text('an@example.com'), findsOneWidget);
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    expect(find.text('Công việc'), findsOneWidget);
    expect(find.text('Ví & thanh toán'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Trợ giúp'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(find.text('Tin nhắn'), findsNothing);
    expect(find.text('Lịch làm việc'), findsNothing);

    await tester.tap(find.text('Hồ sơ của tôi'));
    await tester.tap(find.text('Công việc'));
    await tester.tap(find.text('Ví & thanh toán'));
    await tester.tap(find.text('Thông báo'));
    await tester.tap(find.text('Cài đặt'));
    await tester.tap(find.text('Trợ giúp'));
    await tester.tap(find.text('Đăng xuất'));

    expect(openedProfile, isTrue);
    expect(openedJobs, isTrue);
    expect(openedWallet, isTrue);
    expect(openedNotifications, isTrue);
    expect(openedSettings, isTrue);
    expect(openedSupport, isTrue);
    expect(signedOut, isTrue);
  });

  testWidgets('candidate menu button opens the nearest drawer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: CandidateMenuDrawer(
            displayName: 'An',
            email: 'an@example.com',
            onProfileTap: () {},
            onJobsTap: () {},
            onWalletTap: () {},
            onNotificationsTap: () {},
            onSettingsTap: () {},
            onSupportTap: () {},
            onSignOutTap: () {},
          ),
          appBar: AppBar(leading: const CandidateMenuButton()),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Hồ sơ của tôi'), findsNothing);

    await tester.tap(find.byType(CandidateMenuButton));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
  });
}
