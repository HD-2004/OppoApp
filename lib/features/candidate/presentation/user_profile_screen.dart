import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/platform/cv_file_picker.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user_profile.dart';
import '../data/aws_application_repository.dart';
import '../../home/presentation/widgets/candidate_menu_drawer.dart';
import 'kyc_verification_screen.dart';
import 'policy_terms_screen.dart';
import 'support_screen.dart';
import 'update_profile_screen.dart';
import 'user_jobs_screen.dart';
import 'user_settings_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({
    super.key,
    this.onJobsTap,
    this.onWalletTap,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.onSupportTap,
    this.onSignOutTap,
  });

  final VoidCallback? onJobsTap;
  final VoidCallback? onWalletTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSupportTap;
  final VoidCallback? onSignOutTap;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isSigningOut = false;

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _closeDrawerAndRun(VoidCallback action) {
    Navigator.of(context).pop();
    action();
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
    if (ok == true) {
      setState(() => _isSigningOut = true);
      try {
        await ref.read(authControllerProvider.notifier).signOut();
        if (!mounted) return;
        context.go('/login');
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSigningOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).text('signOutFailed')),
          ),
        );
      }
    }
  }

  int _calculateProfileCompletion(AuthUserProfile? user) {
    if (user == null) return 0;
    int completion = 0;

    // Basic info (40% total - 8% each)
    if (user.fullName.trim().isNotEmpty) completion += 8;
    if (user.email.trim().isNotEmpty) completion += 8;
    if (user.phone?.trim().isNotEmpty == true) completion += 8;
    if (user.cccd?.trim().isNotEmpty == true) completion += 8;
    if (user.dateOfBirth?.trim().isNotEmpty == true) completion += 8;

    // Professional info (24% total - 8% each)
    if (user.location?.trim().isNotEmpty == true) completion += 8;
    if (user.title?.trim().isNotEmpty == true) completion += 8;
    if (user.bio?.trim().isNotEmpty == true) completion += 8;

    // Profile image (10%)
    if (user.profileImage?.trim().isNotEmpty == true) completion += 10;

    // Social links (6% total - at least 1 link)
    final hasSocialLinks =
        user.socialLinks?.values.any((val) => val.trim().isNotEmpty) == true;
    if (hasSocialLinks) completion += 6;

    // Skills (10% - at least 3 skills)
    if (user.skills != null && user.skills!.length >= 3) completion += 10;

    // eKYC verification (10%)
    if (user.kycCompleted) completion += 10;

    return completion.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Bạn';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'Chưa có email';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      drawer: CandidateMenuDrawer(
        displayName: displayName,
        email: email,
        profileImage: user?.profileImage,
        onProfileTap: () => Navigator.of(context).pop(),
        onJobsTap: () => _closeDrawerAndRun(
          widget.onJobsTap ?? () => _push(const UserJobsScreen()),
        ),
        onWalletTap: () => _closeDrawerAndRun(widget.onWalletTap ?? () {}),
        onNotificationsTap: () =>
            _closeDrawerAndRun(widget.onNotificationsTap ?? () {}),
        onSettingsTap: () => _closeDrawerAndRun(
          widget.onSettingsTap ?? () => _push(const UserSettingsScreen()),
        ),
        onSupportTap: () => _closeDrawerAndRun(
          widget.onSupportTap ?? () => _push(const SupportScreen()),
        ),
        onSignOutTap: () =>
            _closeDrawerAndRun(widget.onSignOutTap ?? _confirmSignOut),
      ),
      appBar: _ProfileAppBar(
        onSettings: () => _push(const UserSettingsScreen()),
        onSignOut: _isSigningOut ? null : _confirmSignOut,
        isSigningOut: _isSigningOut,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero header card ────────────────────────────────────
            _HeroCard(
              user: user,
              completionPercent: _calculateProfileCompletion(user),
              onEditTap: () => _push(const UpdateProfileScreen()),
            ),
            const SizedBox(height: 12),

            // ── eKYC Verification ───────────────────────────────────
            _ProfileSection(
              child: _KycSection(
                kycCompleted: user?.kycCompleted ?? false,
                onKyc: () => _push(const KycVerificationScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // ── Personal Information ────────────────────────────────
            _ProfileSection(child: _PersonalInformationSection(user: user)),
            const SizedBox(height: 12),

            // ── CV / Resume ─────────────────────────────────────────
            _ProfileSection(child: _CvSection(userId: user?.userId)),
            const SizedBox(height: 12),

            // ── Work History ───────────────────────────────────────
            _ProfileSection(child: _WorkHistorySection(userId: user?.userId)),
            const SizedBox(height: 12),

            // ── Skills ──────────────────────────────────────────────
            _ProfileSection(
              child: _SkillsSection(
                skills: user?.skills ?? [],
                kycCompleted: user?.kycCompleted ?? false,
              ),
            ),
            const SizedBox(height: 12),

            // ── Settings Links ──────────────────────────────
            _ProfileSection(
              child: Column(
                children: [
                  _ActionTile(
                    icon: Icons.support_agent_outlined,
                    iconColor: const Color(0xFF1E3A8A),
                    iconBg: const Color(0xFFEFF6FF),
                    title: 'Hỗ trợ',
                    subtitle: 'Liên hệ hỗ trợ kỹ thuật',
                    onTap: () => _push(const SupportScreen()),
                  ),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF6B7280),
                    iconBg: const Color(0xFFF3F4F6),
                    title: 'Chính sách & Điều khoản',
                    subtitle: 'Quy chế và chính sách bảo mật',
                    onTap: () => _push(const PolicyTermsScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _ProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ProfileAppBar({
    required this.onSettings,
    required this.onSignOut,
    required this.isSigningOut,
  });

  final VoidCallback onSettings;
  final VoidCallback? onSignOut;
  final bool isSigningOut;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CandidateMenuButton(),
      title: const Text(
        'Ốp Pờ',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1E3A8A),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF1E293B),
            size: 24,
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Hero card ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.user,
    required this.completionPercent,
    required this.onEditTap,
  });

  final AuthUserProfile? user;
  final int completionPercent;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Ứng viên';
    final title = user?.title ?? 'Chưa cập nhật vị trí';
    final location = user?.location ?? 'Chưa có địa điểm';
    final email = user?.email ?? 'Chưa có email';
    final phone = user?.phone ?? 'Chưa có SĐT';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background pattern
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Wrapper
                    _Avatar(user: user, size: 84),
                    const SizedBox(width: 16),
                    // Header Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Info Items
                          _InfoRowItem(icon: Icons.email_outlined, text: email),
                          const SizedBox(height: 6),
                          _InfoRowItem(
                            icon: Icons.phone_android_outlined,
                            text: phone,
                          ),
                          const SizedBox(height: 6),
                          _InfoRowItem(
                            icon: Icons.location_on_outlined,
                            text: location,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Progress Bar
                if (completionPercent < 100) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hoàn thiện hồ sơ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '$completionPercent%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: completionPercent / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '🎉 Hồ sơ đã hoàn thiện 100%!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Edit Profile button
          Positioned(
            right: 14,
            top: 14,
            child: OutlinedButton.icon(
              onPressed: onEditTap,
              icon: const Icon(
                Icons.edit_rounded,
                size: 13,
                color: Colors.white,
              ),
              label: const Text(
                'Chỉnh Sửa',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRowItem extends StatelessWidget {
  const _InfoRowItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, this.size = 72});

  final AuthUserProfile? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final profileImage = user?.profileImage;
    final name = user?.fullName.trim() ?? '';

    Widget content;
    if (profileImage != null && profileImage.startsWith('data:image')) {
      try {
        final bytes = base64.decode(profileImage.split(',').last);
        content = Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        content = _InitialsAvatar(name: name);
      }
    } else if (profileImage != null && profileImage.isNotEmpty) {
      content = Image.network(
        profileImage,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _InitialsAvatar(name: name),
      );
    } else {
      content = _InitialsAvatar(name: name);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(child: content),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : '?';
    return Container(
      color: const Color(0xFFDBEAFE),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E3A8A),
          ),
        ),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: child,
    );
  }
}

// ── eKYC Verification ──────────────────────────────────────────────────────────

class _KycSection extends StatelessWidget {
  const _KycSection({required this.kycCompleted, required this.onKyc});

  final bool kycCompleted;
  final VoidCallback onKyc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shield_outlined, size: 20, color: Color(0xFF1E3A8A)),
            SizedBox(width: 8),
            Text(
              'Xác Minh eKYC',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (kycCompleted)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981), width: 2),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 44),
                SizedBox(height: 8),
                Text(
                  'Đã Xác Minh',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tài khoản của bạn đã được xác minh',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF059669)),
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: onKyc,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yêu Cầu Xác Minh',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Xác minh danh tính eKYC để hoàn thiện hồ sơ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB45309),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Personal Information ─────────────────────────────────────────────────────

class _PersonalInformationSection extends StatelessWidget {
  const _PersonalInformationSection({required this.user});
  final AuthUserProfile? user;

  @override
  Widget build(BuildContext context) {
    final fullName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Chưa cập nhật';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'Chưa cập nhật';
    final phone = user?.phone?.trim().isNotEmpty == true
        ? user!.phone!.trim()
        : 'Chưa cập nhật';
    final cccd = user?.cccd?.trim().isNotEmpty == true
        ? user!.cccd!.trim()
        : 'Chưa cập nhật';

    String dobStr = 'Chưa cập nhật';
    if (user?.dateOfBirth?.trim().isNotEmpty == true) {
      try {
        final date = DateTime.parse(user!.dateOfBirth!.trim());
        dobStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (_) {
        dobStr = user!.dateOfBirth!.trim();
      }
    }

    final location = user?.location?.trim().isNotEmpty == true
        ? user!.location!.trim()
        : 'Chưa cập nhật';
    final title = user?.title?.trim().isNotEmpty == true
        ? user!.title!.trim()
        : 'Chưa cập nhật';
    final bio = user?.bio?.trim().isNotEmpty == true
        ? user!.bio!.trim()
        : 'Chưa cập nhật';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: Color(0xFF1E3A8A),
            ),
            SizedBox(width: 8),
            Text(
              'Thông Tin Cá Nhân',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          icon: Icons.person_rounded,
          iconColor: const Color(0xFF1E40AF),
          label: 'Họ và Tên',
          value: fullName,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.email_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Email',
                value: email,
                valueFontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(
                icon: Icons.phone_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Điện Thoại',
                value: phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                icon: Icons.badge_outlined,
                iconColor: const Color(0xFF1E40AF),
                label: 'Số CCCD',
                value: cccd,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFFEC4899),
                label: 'Ngày sinh',
                value: dobStr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.map_rounded,
          iconColor: const Color(0xFFEF4444),
          label: 'Địa Điểm',
          value: location,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.work_rounded,
          iconColor: const Color(0xFF1E40AF),
          label: 'Vị Trí Mong Muốn',
          value: title,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.description_rounded,
          iconColor: const Color(0xFF06B6D4),
          label: 'Giới Thiệu',
          value: bio,
          maxLines: 10,
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueFontSize = 14,
    this.maxLines = 2,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double valueFontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Experience section ────────────────────────────────────────────────────────

class _CvSection extends ConsumerStatefulWidget {
  const _CvSection({required this.userId});

  final String? userId;

  @override
  ConsumerState<_CvSection> createState() => _CvSectionState();
}

class _CvSectionState extends ConsumerState<_CvSection> {
  static const int _maxCvCount = 3;
  static const int _maxCvSize = 5 * 1024 * 1024;

  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String? _success;
  List<Map<String, dynamic>> _cvList = const [];

  @override
  void initState() {
    super.initState();
    _loadCvs();
  }

  Future<void> _loadCvs() async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      setState(() {
        _cvList = const [];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(applicationRepositoryProvider);
      final cvs = await repo.getCandidateCVs(userId);
      if (!mounted) return;
      setState(() {
        _cvList = cvs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không thể tải danh sách CV.';
      });
    }
  }

  Future<void> _pickAndUploadCv() async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty || _uploading) return;

    if (_cvList.length >= _maxCvCount) {
      setState(() {
        _error =
            'Bạn đã tải tối đa $_maxCvCount CV. Vui lòng xóa CV cũ để thêm mới.';
        _success = null;
      });
      return;
    }

    final file = await _pickCvFileSafely();
    if (file == null) return;

    final bytes = file.bytes;
    if (bytes.isEmpty) {
      setState(() {
        _error = 'Không thể đọc dữ liệu file.';
        _success = null;
      });
      return;
    }
    if (bytes.length > _maxCvSize) {
      setState(() {
        _error = 'File không được vượt quá 5MB.';
        _success = null;
      });
      return;
    }

    final fileName = file.name.trim();
    final fileType = _resolveMimeType(fileName);
    if (fileType == null) {
      setState(() {
        _error = 'Chỉ hỗ trợ file PDF, DOC, DOCX.';
        _success = null;
      });
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
      _success = null;
    });

    try {
      final repo = ref.read(applicationRepositoryProvider);
      await repo.uploadCandidateCV(
        userId: userId,
        fileBytes: bytes,
        fileName: fileName,
        fileType: fileType,
      );
      await _loadCvs();
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _success = 'Đã tải CV lên thành công.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<CvFileSelection?> _pickCvFileSafely() async {
    try {
      return await pickCvFile();
    } catch (error) {
      if (!mounted) return null;
      setState(() {
        _error =
            'Không thể mở trình chọn file. Vui lòng tải lại trang hoặc thử lại.';
        _success = null;
      });
      return null;
    }
  }

  Future<void> _deleteCv(Map<String, dynamic> cv) async {
    final userId = widget.userId;
    if (userId == null || userId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa CV?'),
        content: Text('Bạn có chắc muốn xóa "${cv['cvFileName'] ?? 'CV'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _error = null;
      _success = null;
    });

    try {
      final repo = ref.read(applicationRepositoryProvider);
      final cvId = cv['id']?.toString();
      await repo.deleteCandidateCV(userId: userId, cvId: cvId);
      await _loadCvs();
      if (!mounted) return;
      setState(() {
        _success = 'Đã xóa CV thành công.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _resolveMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 20,
              color: Color(0xFF1E3A8A),
            ),
            SizedBox(width: 8),
            Text(
              'CV / Hồ Sơ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ..._cvList.map((cv) {
          final fileName = cv['cvFileName']?.toString() ?? 'CV.pdf';
          final uploadedAt = cv['cvUploadDate']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (uploadedAt.isNotEmpty)
                        Text(
                          'Tải lên: ${_formatDate(uploadedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteCv(cv),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          );
        }),
        InkWell(
          onTap: _uploading ? null : _pickAndUploadCv,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, color: Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _uploading
                        ? 'Đang tải lên...'
                        : 'Tải CV lên (PDF, DOC, DOCX - tối đa 5MB). Còn lại: ${_maxCvCount - _cvList.length} CV',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_success != null) ...[
          const SizedBox(height: 8),
          Text(
            _success!,
            style: const TextStyle(color: Color(0xFF059669), fontSize: 13),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
          ),
        ],
      ],
    );
  }
}

class _WorkHistorySection extends ConsumerWidget {
  const _WorkHistorySection({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      return const _EmptyWorkHistory();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref
          .read(applicationRepositoryProvider)
          .getCandidateApplications(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: 'Lịch Sử Làm Việc'),
              SizedBox(height: 12),
              LinearProgressIndicator(minHeight: 2),
            ],
          );
        }

        if (snapshot.hasError) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: 'Lịch Sử Làm Việc'),
              SizedBox(height: 12),
              Text(
                'Không thể tải lịch sử làm việc.',
                style: TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ],
          );
        }

        final items = _mapWorkHistory(snapshot.data ?? const []);
        if (items.isEmpty) {
          return const _EmptyWorkHistory();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Lịch Sử Làm Việc'),
            const SizedBox(height: 12),
            ...items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.jobTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                item.companyName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.completedAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatDate(item.completedAt!.toIso8601String()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.overallRating != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'Đánh giá của nhà tuyển dụng:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...List.generate(5, (index) {
                                      return Icon(
                                        index < item.overallRating!.round()
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        size: 14,
                                        color: const Color(0xFFF59E0B),
                                      );
                                    }),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${item.overallRating!.toStringAsFixed(1)}/5',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (item.comment != null &&
                                item.comment!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '"${item.comment!.trim()}"',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF475569),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  List<_WorkHistoryItem> _mapWorkHistory(List<Map<String, dynamic>> apps) {
    final completed = apps.where((app) {
      final status = app['status']?.toString().toLowerCase().trim();
      return status == 'completed' || status == 'completed_pending_candidate';
    });

    final items = completed.map((app) {
      final rating = app['employerRating'];
      Map<String, dynamic>? ratingMap;
      if (rating is Map<String, dynamic>) {
        ratingMap = rating;
      } else if (rating is Map) {
        ratingMap = rating.map((key, value) => MapEntry(key.toString(), value));
      }

      final overallNum = ratingMap?['overall'];
      final overall = overallNum is num
          ? overallNum.toDouble()
          : double.tryParse(overallNum?.toString() ?? '');

      DateTime? completedAt;
      final completedAtRaw =
          app['updatedAt'] ??
          app['completedAt'] ??
          app['appliedAt'] ??
          app['createdAt'];
      if (completedAtRaw != null) {
        completedAt = DateTime.tryParse(completedAtRaw.toString());
      }

      return _WorkHistoryItem(
        id: app['applicationId']?.toString() ?? app['id']?.toString() ?? '',
        jobTitle: app['jobTitle']?.toString() ?? '---',
        companyName:
            app['employerName']?.toString() ??
            app['companyName']?.toString() ??
            '---',
        completedAt: completedAt,
        overallRating: overall,
        comment: ratingMap?['comment']?.toString(),
      );
    }).toList();

    items.sort((a, b) {
      final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return items;
  }
}

class _WorkHistoryItem {
  const _WorkHistoryItem({
    required this.id,
    required this.jobTitle,
    required this.companyName,
    required this.completedAt,
    required this.overallRating,
    required this.comment,
  });

  final String id;
  final String jobTitle;
  final String companyName;
  final DateTime? completedAt;
  final double? overallRating;
  final String? comment;
}

class _EmptyWorkHistory extends StatelessWidget {
  const _EmptyWorkHistory();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Lịch Sử Làm Việc'),
        SizedBox(height: 12),
        _EmptyEntryState(message: 'Chưa có lịch sử làm việc nào', onAdd: _noop),
      ],
    );
  }
}

void _noop() {}

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

// ── Skills section ────────────────────────────────────────────────────────────

class _SkillsSection extends ConsumerStatefulWidget {
  const _SkillsSection({required this.skills, required this.kycCompleted});

  final List<String> skills;
  final bool kycCompleted;

  @override
  ConsumerState<_SkillsSection> createState() => _SkillsSectionState();
}

class _SkillsSectionState extends ConsumerState<_SkillsSection> {
  static const _suggestedSkills = [
    'Pha chế',
    'Barista',
    'Phục vụ',
    'Thu ngân',
    'Bếp phụ',
    'Bếp chính',
    'POS',
    'Giao tiếp',
    'Làm việc nhóm',
    'Chăm sóc khách hàng',
    'Quản lý ca',
    'Tiếng Anh cơ bản',
    'An toàn thực phẩm',
    'Sắp xếp kho',
    'Giao hàng',
  ];

  final _skillController = TextEditingController();
  bool _isAdding = false;
  bool _isSaving = false;
  String? _message;
  late List<String> _skills;

  @override
  void initState() {
    super.initState();
    _skills = _normalizedSkills(widget.skills);
  }

  @override
  void didUpdateWidget(covariant _SkillsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameSkills(oldWidget.skills, widget.skills)) {
      _skills = _normalizedSkills(widget.skills);
    }
  }

  @override
  void dispose() {
    _skillController.dispose();
    super.dispose();
  }

  List<String> _normalizedSkills(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final skill = value.trim();
      final key = skill.toLowerCase();
      if (skill.isNotEmpty && seen.add(key)) {
        result.add(skill);
      }
    }
    return result;
  }

  bool _sameSkills(List<String> first, List<String> second) {
    final a = _normalizedSkills(first);
    final b = _normalizedSkills(second);
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _hasSkill(String value) {
    final key = value.trim().toLowerCase();
    return _skills.any((skill) => skill.trim().toLowerCase() == key);
  }

  List<String> get _filteredSuggestions {
    final query = _skillController.text.trim().toLowerCase();
    final matches = _suggestedSkills
        .where((skill) {
          if (_hasSkill(skill)) return false;
          if (query.isEmpty) return true;
          return skill.toLowerCase().contains(query);
        })
        .take(8);
    return matches.toList();
  }

  Future<void> _addSkill(String value) async {
    final skill = value.trim();
    if (skill.isEmpty) return;
    if (_hasSkill(skill)) {
      setState(() => _message = 'Kỹ năng này đã có trong hồ sơ.');
      return;
    }

    final nextSkills = [..._skills, skill];
    await _saveSkills(nextSkills);
    if (!mounted) return;
    _skillController.clear();
    setState(() {
      _isAdding = false;
      _message = null;
    });
  }

  Future<void> _removeSkill(String value) async {
    final key = value.trim().toLowerCase();
    final nextSkills = _skills
        .where((skill) => skill.trim().toLowerCase() != key)
        .toList();
    await _saveSkills(nextSkills);
  }

  Future<void> _saveSkills(List<String> nextSkills) async {
    final previousSkills = _skills;
    setState(() {
      _skills = nextSkills;
      _isSaving = true;
      _message = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .completeProfile(skills: nextSkills);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _skills = previousSkills;
        _message = 'Không thể lưu kỹ năng. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _openComposer() {
    setState(() {
      _isAdding = true;
      _message = null;
    });
  }

  void _closeComposer() {
    _skillController.clear();
    setState(() {
      _isAdding = false;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _skillController.text.trim();
    final canCreate = query.isNotEmpty && !_hasSkill(query);
    final suggestions = _filteredSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'Kỹ năng')),
            GestureDetector(
              onTap: _isAdding ? _closeComposer : _openComposer,
              child: Row(
                children: [
                  Icon(
                    _isAdding ? Icons.close_rounded : Icons.add_rounded,
                    size: 16,
                    color: const Color(0xFF1E3A8A),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _isAdding ? 'Đóng' : 'Thêm',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isAdding) ...[
          TextField(
            controller: _skillController,
            enabled: !_isSaving,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: _isSaving ? null : _addSkill,
            decoration: InputDecoration(
              labelText: 'Tìm hoặc tạo kỹ năng',
              hintText: 'Ví dụ: Pha chế, POS, Giao tiếp',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: canCreate
                  ? IconButton(
                      tooltip: 'Thêm kỹ năng',
                      icon: const Icon(Icons.add_circle_rounded),
                      color: const Color(0xFF1E3A8A),
                      onPressed: _isSaving ? null : () => _addSkill(query),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (suggestions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (skill) => ActionChip(
                      label: Text(skill),
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      onPressed: _isSaving ? null : () => _addSkill(skill),
                      backgroundColor: const Color(0xFFEFF6FF),
                      labelStyle: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                      ),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                    ),
                  )
                  .toList(),
            ),
          if (canCreate) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : () => _addSkill(query),
                icon: const Icon(Icons.add_rounded),
                label: Text('Thêm "$query"'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          if (_isSaving) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
            ),
          ],
          if (_skills.isNotEmpty) const SizedBox(height: 12),
        ],
        if (_skills.isEmpty && !_isAdding)
          _EmptyEntryState(
            message: 'Thêm kỹ năng của bạn',
            onAdd: _openComposer,
          )
        else if (_skills.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills.map((skill) {
              final isVerified =
                  widget.kycCompleted && _skills.indexOf(skill) < 2;
              return _SkillChip(
                skill: skill,
                isVerified: isVerified,
                onRemove: _isSaving ? null : () => _removeSkill(skill),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.skill,
    required this.isVerified,
    required this.onRemove,
  });

  final String skill;
  final bool isVerified;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: onRemove == null ? 14 : 6,
        top: 7,
        bottom: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            skill,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827),
            ),
          ),
          if (isVerified) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.verified_rounded,
              size: 16,
              color: Color(0xFF1E3A8A),
            ),
          ],
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _EmptyEntryState extends StatelessWidget {
  const _EmptyEntryState({required this.message, required this.onAdd});

  final String message;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
