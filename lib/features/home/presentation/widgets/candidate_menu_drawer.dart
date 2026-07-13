import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

enum CandidateMenuDestination { home, jobs, notifications, profile, wallet }

class CandidateMenuButton extends StatelessWidget {
  const CandidateMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        tooltip: 'Mở menu',
        onPressed: () => Scaffold.of(context).openDrawer(),
        icon: Icon(
          Icons.menu_rounded,
          color: AppColors.textPrimaryFor(context),
          size: 24,
        ),
      ),
    );
  }
}

class CandidateMenuDrawer extends StatelessWidget {
  const CandidateMenuDrawer({
    super.key,
    required this.displayName,
    required this.email,
    this.profileImage,
    required this.onHomeTap,
    required this.onProfileTap,
    required this.onJobsTap,
    required this.onWalletTap,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onSupportTap,
    required this.onSignOutTap,
    this.currentDestination = CandidateMenuDestination.home,
  });

  final String displayName;
  final String email;
  final String? profileImage;
  final VoidCallback onHomeTap;
  final VoidCallback onProfileTap;
  final VoidCallback onJobsTap;
  final VoidCallback onWalletTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSupportTap;
  final VoidCallback onSignOutTap;
  final CandidateMenuDestination currentDestination;

  @override
  Widget build(BuildContext context) {
    final drawerWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.88,
      382.0,
    );

    return Drawer(
      width: drawerWidth,
      backgroundColor: AppColors.surface(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 12, 28),
          children: [
            _MenuSection(
              label: 'QUẢN LÝ',
              children: [
                _MenuTile(
                  icon: Icons.grid_view_rounded,
                  title: 'Trang chủ',
                  isSelected:
                      currentDestination == CandidateMenuDestination.home,
                  onTap: onHomeTap,
                ),
                _MenuTile(
                  icon: Icons.work_outline_rounded,
                  title: 'Công việc',
                  isSelected:
                      currentDestination == CandidateMenuDestination.jobs,
                  onTap: onJobsTap,
                ),
              ],
            ),
            const _SectionDivider(),
            _MenuSection(
              label: 'TƯƠNG TÁC',
              children: [
                _MenuTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Thông báo',
                  isSelected:
                      currentDestination ==
                      CandidateMenuDestination.notifications,
                  onTap: onNotificationsTap,
                ),
              ],
            ),
            const _SectionDivider(),
            _MenuSection(
              label: 'TÀI KHOẢN',
              children: [
                _MenuTile(
                  icon: Icons.group_outlined,
                  title: 'Hồ Sơ Của Tôi',
                  isSelected:
                      currentDestination == CandidateMenuDestination.profile,
                  onTap: onProfileTap,
                ),
              ],
            ),
            const _SectionDivider(),
            _MenuSection(
              label: 'MỞ RỘNG',
              children: [
                _MenuTile(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Ví điện tử',
                  isSelected:
                      currentDestination == CandidateMenuDestination.wallet,
                  onTap: onWalletTap,
                ),
                _MenuTile(
                  icon: Icons.logout_rounded,
                  title: 'Đăng xuất',
                  onTap: onSignOutTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 0, 14),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textMutedFor(context),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected
        ? AppColors.textOnPrimary
        : AppColors.textPrimaryFor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(icon, color: foregroundColor, size: 30),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 28),
      child: Divider(height: 1, color: AppColors.borderFor(context)),
    );
  }
}
