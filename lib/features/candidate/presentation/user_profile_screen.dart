import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user_profile.dart';
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
              onEditTap: () => _push(const UpdateProfileScreen()),
            ),
            const SizedBox(height: 12),

            // ── About ───────────────────────────────────────────────
            if (user?.bio != null && user!.bio!.isNotEmpty)
              _ProfileSection(child: _AboutSection(bio: user.bio!)),
            if (user?.bio != null && user!.bio!.isNotEmpty)
              const SizedBox(height: 12),

            // ── Experience ──────────────────────────────────────────
            _ProfileSection(
              child: _ExperienceSection(
                onAdd: () => _push(const UpdateProfileScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // ── Skills ──────────────────────────────────────────────
            _ProfileSection(
              child: _SkillsSection(
                skills: user?.skills ?? [],
                kycCompleted: user?.kycCompleted ?? false,
                onAdd: () => _push(const UpdateProfileScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // ── Education ───────────────────────────────────────────
            _ProfileSection(
              child: _EducationSection(
                onAdd: () => _push(const UpdateProfileScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // ── eKYC + Settings links ───────────────────────────────
            _ProfileSection(
              child: _AccountSection(
                kycCompleted: user?.kycCompleted ?? false,
                onKyc: () => _push(const KycVerificationScreen()),
                onSupport: () => _push(const SupportScreen()),
                onPolicy: () => _push(const PolicyTermsScreen()),
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
  const _HeroCard({required this.user, required this.onEditTap});

  final AuthUserProfile? user;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Ứng viên';
    final title = user?.title ?? '';
    final location = user?.location ?? '';
    final kycVerified = user?.kycCompleted ?? false;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue banner
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar overlapping banner
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: _Avatar(user: user, size: 80),
                ),
                // Name + Edit button row
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            if (title.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Edit Profile button
                      ElevatedButton.icon(
                        onPressed: onEditTap,
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: const Text(
                          'Edit\nProfile',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, height: 1.3),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Verified + Open for Work badges
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (kycVerified)
                        _StatusBadge(
                          icon: Icons.verified_rounded,
                          label: 'Verified Student',
                          bgColor: const Color(0xFFEFF6FF),
                          textColor: const Color(0xFF1E3A8A),
                          iconColor: const Color(0xFF1E3A8A),
                        ),
                      _StatusBadge(
                        icon: null,
                        label: 'Open for Work',
                        bgColor: const Color(0xFFF3F4F6),
                        textColor: const Color(0xFF374151),
                        iconColor: Colors.transparent,
                      ),
                    ],
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(13), child: content),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.iconColor,
  });

  final IconData? icon;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
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

// ── About section ─────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.bio});
  final String bio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'About'),
        const SizedBox(height: 10),
        Text(
          bio,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ── Experience section ────────────────────────────────────────────────────────

class _ExperienceSection extends StatelessWidget {
  const _ExperienceSection({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'Experience')),
            GestureDetector(
              onTap: onAdd,
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 3),
                  Text(
                    'Add',
                    style: TextStyle(
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
        // App-local empty state until profile editing captures experience.
        _EmptyEntryState(
          message: 'Thêm kinh nghiệm làm việc của bạn',
          onAdd: onAdd,
        ),
      ],
    );
  }
}

// ── Skills section ────────────────────────────────────────────────────────────

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({
    required this.skills,
    required this.kycCompleted,
    required this.onAdd,
  });

  final List<String> skills;
  final bool kycCompleted;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'Skills')),
            GestureDetector(
              onTap: onAdd,
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 3),
                  Text(
                    'Add',
                    style: TextStyle(
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
        if (skills.isEmpty)
          _EmptyEntryState(message: 'Thêm kỹ năng của bạn', onAdd: onAdd)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((skill) {
              // Verified skills (first 2 nếu kycCompleted)
              final isVerified = kycCompleted && skills.indexOf(skill) < 2;
              return _SkillChip(skill: skill, isVerified: isVerified);
            }).toList(),
          ),
      ],
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill, required this.isVerified});

  final String skill;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
        ],
      ),
    );
  }
}

// ── Education section ─────────────────────────────────────────────────────────

class _EducationSection extends StatelessWidget {
  const _EducationSection({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'Education')),
            GestureDetector(
              onTap: onAdd,
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Color(0xFF1E3A8A)),
                  SizedBox(width: 3),
                  Text(
                    'Add',
                    style: TextStyle(
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
        _EmptyEntryState(message: 'Thêm học vấn của bạn', onAdd: onAdd),
      ],
    );
  }
}

// ── Account section ───────────────────────────────────────────────────────────

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.kycCompleted,
    required this.onKyc,
    required this.onSupport,
    required this.onPolicy,
  });

  final bool kycCompleted;
  final VoidCallback onKyc;
  final VoidCallback onSupport;
  final VoidCallback onPolicy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KYC verification
        if (!kycCompleted)
          _ActionTile(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFEF3C7),
            title: 'Xác minh danh tính (eKYC)',
            subtitle: 'Tăng độ tin cậy hồ sơ của bạn',
            onTap: onKyc,
          ),
        if (!kycCompleted) const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.support_agent_outlined,
          iconColor: const Color(0xFF1E3A8A),
          iconBg: const Color(0xFFEFF6FF),
          title: 'Hỗ trợ',
          subtitle: 'Liên hệ hỗ trợ kỹ thuật',
          onTap: onSupport,
        ),
        const SizedBox(height: 8),
        _ActionTile(
          icon: Icons.description_outlined,
          iconColor: const Color(0xFF6B7280),
          iconBg: const Color(0xFFF3F4F6),
          title: 'Chính sách & Điều khoản',
          subtitle: 'Quy chế và chính sách bảo mật',
          onTap: onPolicy,
        ),
      ],
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
