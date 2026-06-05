import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../features/auth/application/auth_controller.dart';
import '../../../../features/candidate/notifications/application/notification_controller.dart';
import '../../../../core/preferences/app_preferences.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.onNotificationTap});

  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final unreadCount =
        ref
            .watch(candidateNotificationControllerProvider)
            .asData
            ?.value
            .summary
            .unread ??
        0;

    final now = DateTime.now();
    // e.g. "Thứ 4, 03 Tháng 6"
    final dateStr = DateFormat('EEEE, dd MMMM', 'vi').format(now);

    final displayName = (user?.fullName.trim().isNotEmpty == true)
        ? user!.fullName
              .trim()
              .split(' ')
              .last // lấy tên cuối
        : 'Bạn';

    final avatarUrl = user?.profileImage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          _UserAvatar(avatarUrl: avatarUrl),
          const SizedBox(width: 10),

          // Date + Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                    children: [
                      const TextSpan(text: 'Chào bạn, '),
                      TextSpan(
                        text: '$displayName!',
                        style: const TextStyle(color: Color(0xFF0D9488)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Notification bell
          Stack(
            children: [
              IconButton(
                onPressed: onNotificationTap,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  size: 26,
                  color: Color(0xFF374151),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 4),

          // Sẵn sàng toggle
          _AvailabilityToggle(user: user),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.avatarUrl});
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0D9488), width: 2),
        color: const Color(0xFFE5E7EB),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _DefaultAvatarIcon(),
              )
            : const _DefaultAvatarIcon(),
      ),
    );
  }
}

class _DefaultAvatarIcon extends StatelessWidget {
  const _DefaultAvatarIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person, size: 24, color: Color(0xFF9CA3AF));
  }
}

/// Toggle "Sẵn sàng" được lưu app-local để người dùng giữ trạng thái giữa các phiên.
class _AvailabilityToggle extends StatefulWidget {
  const _AvailabilityToggle({this.user});
  final dynamic user;

  @override
  State<_AvailabilityToggle> createState() => _AvailabilityToggleState();
}

class _AvailabilityToggleState extends State<_AvailabilityToggle> {
  bool _available = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _available =
          preferences.getBool(AppPreferenceKeys.candidateAvailability) ?? true;
    });
  }

  Future<void> _setAvailability(bool value) async {
    setState(() => _available = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(AppPreferenceKeys.candidateAvailability, value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sẵn\nsàng',
          style: TextStyle(
            fontSize: 10,
            color: _available
                ? const Color(0xFF0D9488)
                : const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: _available,
            onChanged: _setAvailability,
            activeThumbColor: const Color(0xFF0D9488),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
