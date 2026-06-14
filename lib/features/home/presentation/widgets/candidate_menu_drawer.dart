import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import '../../../../core/config/s3_asset_config.dart';
import '../../../../shared/presentation/widgets/network_asset_image.dart';

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
      backgroundColor: AppColors.surface(context),
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
                    title: 'Công việc',
                    subtitle: 'Đang ứng tuyển, tuyển gấp, đã lưu',
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
                    subtitle: 'Ngôn ngữ, bảo mật, tùy chọn thông báo',
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          _DrawerAvatar(profileImage: profileImage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryFor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondaryFor(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 44,
            height: 32,
            child: NetworkAssetImage(
              url: S3AssetConfig.logo,
              fit: BoxFit.contain,
              semanticLabel: 'Logo Ốp Pờ',
              placeholder: SizedBox.shrink(),
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
    Widget content = const _DrawerAvatarFallback();

    if (image != null && image.startsWith('data:image')) {
      try {
        content = Image.memory(
          base64Decode(image.split(',').last),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _DrawerAvatarFallback(),
        );
      } catch (_) {
        content = const _DrawerAvatarFallback();
      }
    } else if (image != null && image.isNotEmpty) {
      content = Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _DrawerAvatarFallback(),
      );
    }

    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.softPrimaryFor(context),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: content,
    );
  }
}

class _DrawerAvatarFallback extends StatelessWidget {
  const _DrawerAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person_rounded, color: AppColors.primary, size: 26);
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
    final color = isDanger ? AppColors.danger : AppColors.primary;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: isDanger ? color : AppColors.textPrimaryFor(context),
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textSecondaryFor(context),
          fontSize: 12,
        ),
      ),
      onTap: onTap,
    );
  }
}
