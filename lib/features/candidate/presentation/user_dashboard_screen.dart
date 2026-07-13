import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../home/presentation/pages/candidate_home_page.dart';
import '../notifications/application/notification_controller.dart';
import '../notifications/presentation/candidate_notifications_screen.dart';
import 'digital_wallet_screen.dart';
import 'support_screen.dart';
import 'user_profile_screen.dart';
import 'user_jobs_screen.dart';
import 'user_settings_screen.dart';

class UserDashboardScreen extends ConsumerStatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  ConsumerState<UserDashboardScreen> createState() =>
      _UserDashboardScreenState();
}

class _UserDashboardScreenState extends ConsumerState<UserDashboardScreen> {
  int _selectedIndex = 0;

  static const _tabJobs = 1;
  static const _tabWallet = 2;
  static const _tabProfile = 3;

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openSettings() {
    _push(const UserSettingsScreen());
  }

  void _openSupport() {
    _push(const SupportScreen());
  }

  Future<void> _confirmSignOut() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.text('confirmSignOutTitle')),
        content: Text(l10n.text('confirmSignOutMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) {
        return;
      }
      context.go('/login');
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).text('signOutFailed')),
        ),
      );
    }
  }

  /// Mở màn hình thông báo — dùng chung cho toàn bộ app.
  /// Sau khi đóng, refresh badge để cập nhật số unread.
  void _openNotifications() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const CandidateNotificationsScreen(),
          ),
        )
        .then((_) {
          // Refresh sau khi user quay lại để cập nhật badge
          if (mounted) {
            ref
                .read(candidateNotificationControllerProvider.notifier)
                .refreshNotifications();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    // Đọc unread count một lần tại đây — truyền xuống cho các tab cần badge
    final unreadCount =
        ref
            .watch(candidateNotificationControllerProvider)
            .asData
            ?.value
            .summary
            .unread ??
        0;

    final tabs = [
      // 0 – Trang chủ
      CandidateHomePage(
        onNotificationTap: _openNotifications,
        onSeeAllJobsTap: () => _selectTab(_tabJobs),
        onWalletTap: () => _selectTab(_tabWallet),
        onJobsTap: () => _selectTab(_tabJobs),
        onProfileTap: () => _selectTab(_tabProfile),
        onSettingsTap: _openSettings,
        onSupportTap: _openSupport,
        onSignOutTap: _confirmSignOut,
      ),
      // 1 – Công việc, đồng bộ với màn "Việc của tôi" trên web
      const UserJobsScreen(showBackButton: false),
      // 2 – Ví
      const DigitalWalletScreen(),
      // 3 – Cá nhân
      UserProfileScreen(
        onHomeTap: () => _selectTab(0),
        onJobsTap: () => _selectTab(_tabJobs),
        onWalletTap: () => _selectTab(_tabWallet),
        onNotificationsTap: _openNotifications,
        onSettingsTap: _openSettings,
        onSupportTap: _openSupport,
        onSignOutTap: _confirmSignOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: _HomeBottomNav(
        selectedIndex: _selectedIndex,
        unreadCount: unreadCount,
        onTabSelected: _selectTab,
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                selectedIndex: selectedIndex,
                icon: Icons.home_rounded,
                label: 'Trang chủ',
                onTap: onTabSelected,
              ),
              _NavItem(
                index: 1,
                selectedIndex: selectedIndex,
                icon: Icons.work_outline_rounded,
                label: 'Công việc',
                onTap: onTabSelected,
              ),
              _NavItem(
                index: 2,
                selectedIndex: selectedIndex,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Ví',
                onTap: onTabSelected,
              ),
              _NavItem(
                index: 3,
                selectedIndex: selectedIndex,
                icon: Icons.person_outline_rounded,
                label: 'Cá nhân',
                onTap: onTabSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = AppColors.textSecondaryFor(context);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? AppColors.textOnPrimary : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
