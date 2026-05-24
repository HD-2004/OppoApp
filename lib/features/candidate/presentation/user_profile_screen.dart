import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import 'digital_wallet_screen.dart';
import 'edit_profile_screen.dart';
import 'login_security_screen.dart';
import 'policy_terms_screen.dart';
import 'support_screen.dart';
import 'user_settings_screen.dart';
import 'widgets/profile_menu_tile.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final fullName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : l10n.candidate;
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : l10n.email;
    final kycStatus = user?.kycCompleted == true
        ? l10n.text('kycVerification')
        : l10n.text('kycVerification');

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(email),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(l10n.candidate)),
                              Chip(label: Text(kycStatus)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ProfileSection(
              title: l10n.account,
              children: [
                ProfileMenuTile(
                  icon: Icons.edit_outlined,
                  title: l10n.text('editProfile'),
                  subtitle: l10n.text('updateProfile'),
                  onTap: () => _push(const EditProfileScreen()),
                ),
                ProfileMenuTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.digitalWallet,
                  subtitle: l10n.text('wallet'),
                  onTap: () => _push(const DigitalWalletScreen()),
                ),
                ProfileMenuTile(
                  icon: Icons.security_outlined,
                  title: l10n.text('loginSecurity'),
                  subtitle: l10n.security,
                  onTap: () => _push(const LoginSecurityScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileSection(
              title: '${l10n.support} / ${l10n.text('policyTerms')}',
              children: [
                ProfileMenuTile(
                  icon: Icons.support_agent_outlined,
                  title: l10n.support,
                  subtitle: l10n.text('contactSupport'),
                  onTap: () => _push(const SupportScreen()),
                ),
                ProfileMenuTile(
                  icon: Icons.description_outlined,
                  title: l10n.text('policyTerms'),
                  subtitle: l10n.text('policyTerms'),
                  onTap: () => _push(const PolicyTermsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileSection(
              title: l10n.appName,
              children: [
                ProfileMenuTile(
                  icon: Icons.settings_outlined,
                  title: l10n.settings,
                  subtitle: l10n.appLanguage,
                  onTap: () => _push(const UserSettingsScreen()),
                ),
                ProfileMenuTile(
                  icon: Icons.logout,
                  title: _isSigningOut ? l10n.loading : l10n.signOut,
                  subtitle: l10n.signOut,
                  isDestructive: true,
                  onTap: _isSigningOut ? () {} : _confirmSignOut,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
