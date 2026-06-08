import 'dart:convert';

import 'package:flutter/material.dart';

class CandidateMenuButton extends StatelessWidget {
  const CandidateMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: IconButton(
        tooltip: 'Mở menu',
        onPressed: () => Scaffold.of(context).openDrawer(),
        icon: const Icon(
          Icons.menu_rounded,
          color: Color(0xFF1E293B),
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
    required this.onProfileTap,
    required this.onJobsTap,
    required this.onWalletTap,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onSupportTap,
    required this.onSignOutTap,
  });

  final String displayName;
  final String email;
  final String? profileImage;
  final VoidCallback onProfileTap;
  final VoidCallback onJobsTap;
  final VoidCallback onWalletTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSupportTap;
  final VoidCallback onSignOutTap;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(
              displayName: displayName,
              email: email,
              profileImage: profileImage,
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _MenuTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Hồ sơ của tôi',
                    subtitle: 'Thông tin cá nhân, KYC, kỹ năng',
                    onTap: onProfileTap,
                  ),
                  _MenuTile(
                    icon: Icons.work_outline_rounded,
                    title: 'Việc của tôi',
                    subtitle: 'Việc đang ứng tuyển, tuyển gấp, đã lưu',
                    onTap: onJobsTap,
                  ),
                  _MenuTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Ví & thanh toán',
                    subtitle: 'Số dư, giao dịch, rút tiền',
                    onTap: onWalletTap,
                  ),
                  _MenuTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Thông báo',
                    subtitle: 'Cập nhật từ hệ thống và nhà tuyển dụng',
                    onTap: onNotificationsTap,
                  ),
                  const Divider(height: 16),
                  _MenuTile(
                    icon: Icons.settings_outlined,
                    title: 'Cài đặt',
                    subtitle: 'Ngôn ngữ, bảo mật, tuỳ chọn thông báo',
                    onTap: onSettingsTap,
                  ),
                  _MenuTile(
                    icon: Icons.support_agent_outlined,
                    title: 'Trợ giúp',
                    subtitle: 'FAQ, hỗ trợ, báo cáo sự cố',
                    onTap: onSupportTap,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _MenuTile(
              icon: Icons.logout_rounded,
              title: 'Đăng xuất',
              subtitle: 'Thoát khỏi tài khoản hiện tại',
              onTap: onSignOutTap,
              isDanger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.displayName,
    required this.email,
    this.profileImage,
  });

  final String displayName;
  final String email;
  final String? profileImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          _DrawerAvatar(profileImage: profileImage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({this.profileImage});

  final String? profileImage;

  @override
  Widget build(BuildContext context) {
    final image = profileImage?.trim();

    Widget content;
    if (image != null && image.startsWith('data:image')) {
      try {
        final bytes = base64Decode(image.split(',').last);
        content = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        content = const _DrawerAvatarFallback();
      }
    } else if (image != null && image.isNotEmpty) {
      content = Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _DrawerAvatarFallback(),
      );
    } else {
      content = const _DrawerAvatarFallback();
    }

    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class _DrawerAvatarFallback extends StatelessWidget {
  const _DrawerAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person_rounded, color: Color(0xFF1E3A8A), size: 26);
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: isDanger ? color : const Color(0xFF111827),
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}
