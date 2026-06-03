import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user_profile.dart';
import 'kyc_verification_screen.dart';
import 'policy_terms_screen.dart';
import 'support_screen.dart';
import 'update_profile_screen.dart';
import 'user_settings_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isSigningOut = false;

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmSignOut() async {
    final l10n = AppLocalizations.of(context);
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.text('confirmSignOutTitle')),
          content: Text(l10n.text('confirmSignOutMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.signOut),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      await _signOut();
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

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
      setState(() {
        _isSigningOut = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).text('signOutFailed')),
        ),
      );
    }
  }

  int _calculateCompletion(AuthUserProfile? user) {
    if (user == null) return 0;
    int score = 0;

    // Basic Info: 8% each (40% total)
    if (user.fullName.trim().isNotEmpty) score += 8;
    if (user.email.trim().isNotEmpty) score += 8;
    if (user.phone != null && user.phone!.trim().isNotEmpty) score += 8;
    if (user.cccd != null && user.cccd!.trim().isNotEmpty) score += 8;
    if (user.dateOfBirth != null && user.dateOfBirth!.trim().isNotEmpty) {
      score += 8;
    }

    // Professional Info: 10% each (30% total)
    if (user.location != null && user.location!.trim().isNotEmpty) score += 10;
    if (user.title != null && user.title!.trim().isNotEmpty) score += 10;
    if (user.bio != null && user.bio!.trim().isNotEmpty) score += 10;

    // Skills (10% if >= 3, otherwise 5% or 0%)
    if (user.skills != null && user.skills!.length >= 3) {
      score += 10;
    } else if (user.skills != null && user.skills!.isNotEmpty) {
      score += 5;
    }

    // Profile Image: 10%
    if (user.profileImage != null && user.profileImage!.isNotEmpty) score += 10;

    // eKYC completed: 10%
    if (user.kycCompleted) score += 10;

    return score;
  }

  String _formatDate(String? dateStr, bool isVi) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat.yMMMMd(isVi ? 'vi' : 'en').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildAvatar(AuthUserProfile? user, String fullName) {
    if (user?.profileImage != null &&
        user!.profileImage!.startsWith('data:image')) {
      try {
        final base64Str = user.profileImage!.split(',').last;
        final bytes = base64.decode(base64Str);
        return CircleAvatar(radius: 38, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }

    // Fallback to initials
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 3,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isVi = AppLocalizations.of(context).isVietnamese;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty
                      ? value
                      : (isVi ? 'Chưa cập nhật' : 'Not updated'),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isVi = l10n.isVietnamese;
    final user = ref.watch(authControllerProvider).asData?.value.user;

    final fullName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : (isVi ? 'Ứng viên' : 'Candidate');
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : '';
    final completion = _calculateCompletion(user);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myProfileTabTitle),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: isVi ? 'Cài đặt' : 'Settings',
            onPressed: () => _push(const UserSettingsScreen()),
          ),
          IconButton(
            icon: _isSigningOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            tooltip: l10n.signOut,
            onPressed: _isSigningOut ? null : _confirmSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Blue Gradient Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E40AF).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildAvatar(user, fullName),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.title ??
                                        (isVi
                                            ? 'Chưa cập nhật vị trí'
                                            : 'Position not set'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Edit profile quick button
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              onPressed: () =>
                                  _push(const UpdateProfileScreen()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),
                        // Metadata items
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            if (email.isNotEmpty)
                              _buildMetaItem(Icons.email_outlined, email),
                            if (user?.phone != null && user!.phone!.isNotEmpty)
                              _buildMetaItem(Icons.phone_outlined, user.phone!),
                            if (user?.location != null &&
                                user!.location!.isNotEmpty)
                              _buildMetaItem(
                                Icons.map_outlined,
                                user.location!,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Completeness percentage bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi
                                  ? '🎉 Hồ sơ đã hoàn thiện $completion%!'
                                  : '🎉 Profile completed $completion%!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completion / 100.0,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. eKYC Verification Status Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: user?.kycCompleted == true
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: user?.kycCompleted == true
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isVi ? 'Xác Minh eKYC' : 'eKYC Verification',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (user?.kycCompleted == true)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF10B981),
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isVi ? 'Đã Xác Minh' : 'Verified',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isVi
                                              ? 'Tài khoản của bạn đã được xác minh thành công.'
                                              : 'Your account has been successfully verified.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xFFF59E0B),
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isVi
                                                  ? 'Chưa Xác Minh'
                                                  : 'Unverified',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFF59E0B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isVi
                                                  ? 'Xác minh danh tính để nâng cấp độ tin cậy của hồ sơ.'
                                                  : 'Verify your identity to increase profile trust level.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: const Color(
                                                  0xFFF59E0B,
                                                ).withValues(alpha: 0.9),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _push(const KycVerificationScreen()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF59E0B),
                                    side: const BorderSide(
                                      color: Color(0xFFF59E0B),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.shield_outlined),
                                  label: Text(
                                    isVi
                                        ? 'Bắt Đầu Xác Minh'
                                        : 'Start Verification',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Thông Tin Cá Nhân Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isVi
                                        ? 'Thông Tin Cá Nhân'
                                        : 'Personal Information',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _push(const UpdateProfileScreen()),
                                icon: const Icon(Icons.edit, size: 14),
                                label: Text(isVi ? 'Sửa' : 'Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailTile(
                            context,
                            icon: Icons.person_outline,
                            label: isVi ? 'Họ và tên' : 'Full name',
                            value: user?.fullName ?? '',
                            color: const Color(0xFF1E40AF),
                          ),
                          _buildDetailTile(
                            context,
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user?.email ?? '',
                            color: const Color(0xFF10B981),
                          ),
                          _buildDetailTile(
                            context,
                            icon: Icons.phone_outlined,
                            label: isVi ? 'Điện thoại' : 'Phone',
                            value: user?.phone ?? '',
                            color: const Color(0xFFF59E0B),
                          ),
                          _buildDetailTile(
                            context,
                            icon: Icons.badge_outlined,
                            label: isVi ? 'Số CCCD' : 'Citizen ID',
                            value: user?.cccd ?? '',
                            color: const Color(0xFF1E40AF),
                          ),
                          _buildDetailTile(
                            context,
                            icon: Icons.cake_outlined,
                            label: isVi ? 'Ngày sinh' : 'Date of Birth',
                            value: _formatDate(user?.dateOfBirth, isVi),
                            color: const Color(0xFFEC4899),
                          ),
                          _buildDetailTile(
                            context,
                            icon: Icons.map_outlined,
                            label: isVi ? 'Địa điểm' : 'Location',
                            value: user?.location ?? '',
                            color: const Color(0xFFEF4444),
                          ),
                          _buildDetailTile(
                            context,
                            icon: Icons.work_outline,
                            label: isVi
                                ? 'Vị trí mong muốn'
                                : 'Desired Position',
                            value: user?.title ?? '',
                            color: const Color(0xFF1E40AF),
                          ),
                          _buildDetailTile(
                            context,
                            icon: Icons.notes_outlined,
                            label: isVi ? 'Giới thiệu' : 'Bio',
                            value: user?.bio ?? '',
                            color: const Color(0xFF06B6D4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Kỹ năng Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.star_border,
                                color: Color(0xFFF59E0B),
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isVi ? 'Kỹ Năng' : 'Skills',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (user?.skills != null && user!.skills!.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: user.skills!.map((skill) {
                                return Chip(
                                  label: Text(
                                    skill,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  avatar: const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Color(0xFF10B981),
                                  ),
                                  backgroundColor: theme
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.15),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Text(
                                isVi
                                    ? 'Chưa thêm kỹ năng nào. Vui lòng bấm chỉnh sửa để cập nhật.'
                                    : 'No skills added yet. Tap edit to update.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Quick Support & Links Card (Replaced general menu tiles)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.support_agent_outlined),
                            title: Text(l10n.support),
                            subtitle: Text(
                              isVi
                                  ? 'Liên hệ hỗ trợ kỹ thuật'
                                  : 'Contact tech support',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _push(const SupportScreen()),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(l10n.text('policyTerms')),
                            subtitle: Text(
                              isVi
                                  ? 'Quy chế và chính sách bảo mật'
                                  : 'Terms and privacy policies',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _push(const PolicyTermsScreen()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
