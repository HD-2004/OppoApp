import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/home/presentation/widgets/candidate_menu_drawer.dart';

void main() {
  testWidgets('candidate drawer shows app-only navigation items', (
    tester,
  ) async {
    var openedProfile = false;
    var openedHome = false;
    var openedJobs = false;
    var openedWallet = false;
    var openedNotifications = false;
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateMenuDrawer(
            displayName: 'An',
            email: 'an@example.com',
            onHomeTap: () => openedHome = true,
            onProfileTap: () => openedProfile = true,
            onJobsTap: () => openedJobs = true,
            onWalletTap: () => openedWallet = true,
            onNotificationsTap: () => openedNotifications = true,
            onSettingsTap: () {},
            onSupportTap: () {},
            onSignOutTap: () => signedOut = true,
          ),
        ),
      ),
    );

    expect(find.text('An'), findsNothing);
    expect(find.text('an@example.com'), findsNothing);
    expect(find.text('QUẢN LÝ'), findsOneWidget);
    expect(find.text('TƯƠNG TÁC'), findsOneWidget);
    expect(find.text('TÀI KHOẢN'), findsOneWidget);
    expect(find.text('MỞ RỘNG'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Hồ Sơ Của Tôi'), findsOneWidget);
    expect(find.text('Công việc'), findsOneWidget);
    expect(find.text('Ví điện tử'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Cài đặt'), findsNothing);
    expect(find.text('Trợ giúp'), findsNothing);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(find.text('Thông tin cá nhân, KYC, kỹ năng'), findsNothing);
    expect(find.text('Số dư, giao dịch, rút tiền'), findsNothing);
    expect(find.text('Tin nhắn'), findsNothing);
    expect(find.text('Lịch làm việc'), findsNothing);

    final homeText = tester.widget<Text>(find.text('Trang chủ'));
    expect(homeText.style?.color, Colors.white);

    Future<void> tapMenuItem(String label) async {
      final finder = find.text(label);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pump();
    }

    await tapMenuItem('Trang chủ');
    await tapMenuItem('Hồ Sơ Của Tôi');
    await tapMenuItem('Công việc');
    await tapMenuItem('Ví điện tử');
    await tapMenuItem('Thông báo');
    await tapMenuItem('Đăng xuất');

    expect(openedHome, isTrue);
    expect(openedProfile, isTrue);
    expect(openedJobs, isTrue);
    expect(openedWallet, isTrue);
    expect(openedNotifications, isTrue);
    expect(signedOut, isTrue);
  });

  testWidgets('candidate menu button opens the nearest drawer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: CandidateMenuDrawer(
            displayName: 'An',
            email: 'an@example.com',
            onHomeTap: () {},
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

    expect(find.text('Hồ Sơ Của Tôi'), findsNothing);

    await tester.tap(find.byType(CandidateMenuButton));
    await tester.pumpAndSettle();

    expect(find.text('Hồ Sơ Của Tôi'), findsOneWidget);
  });

  testWidgets('candidate drawer highlights the current destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateMenuDrawer(
            displayName: 'An',
            email: 'an@example.com',
            currentDestination: CandidateMenuDestination.profile,
            onHomeTap: () {},
            onProfileTap: () {},
            onJobsTap: () {},
            onWalletTap: () {},
            onNotificationsTap: () {},
            onSettingsTap: () {},
            onSupportTap: () {},
            onSignOutTap: () {},
          ),
        ),
      ),
    );

    final homeText = tester.widget<Text>(find.text('Trang chủ'));
    final profileText = tester.widget<Text>(find.text('Hồ Sơ Của Tôi'));

    expect(homeText.style?.color, isNot(Colors.white));
    expect(profileText.style?.color, Colors.white);
  });
}
