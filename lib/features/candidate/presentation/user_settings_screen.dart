import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme_controller.dart';
import 'change_password_screen.dart';
import 'delete_account_request_screen.dart';
import 'language_selection_screen.dart';
import 'notification_preferences_screen.dart';
import 'policy_terms_screen.dart';
import 'theme_mode_screen.dart';
import 'widgets/setting_section.dart';
import 'widgets/setting_tile.dart';

class UserSettingsScreen extends ConsumerWidget {
  const UserSettingsScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final themeMode =
        ref.watch(appThemeControllerProvider).asData?.value ?? ThemeMode.system;
    final locale =
        ref.watch(appLanguageControllerProvider).asData?.value ??
        const Locale('vi');

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingSection(
              title: strings.appearance,
              children: [
                SettingTile(
                  icon: Icons.palette_outlined,
                  title: strings.themeMode,
                  subtitle: _themeModeLabel(strings, themeMode),
                  onTap: () => _push(context, const ThemeModeScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingSection(
              title: strings.language,
              children: [
                SettingTile(
                  icon: Icons.language_outlined,
                  title: strings.appLanguage,
                  subtitle: locale.languageCode == 'en'
                      ? 'English'
                      : 'Tiếng Việt',
                  onTap: () => _push(context, const LanguageSelectionScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingSection(
              title: strings.security,
              children: [
                SettingTile(
                  icon: Icons.lock_outline,
                  title: strings.changePassword,
                  onTap: () => _push(context, const ChangePasswordScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingSection(
              title: strings.notifications,
              children: [
                SettingTile(
                  icon: Icons.notifications_none,
                  title: strings.notificationPreferences,
                  onTap: () =>
                      _push(context, const NotificationPreferencesScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingSection(
              title: strings.text('policyTerms'),
              children: [
                SettingTile(
                  icon: Icons.description_outlined,
                  title: strings.text('policyTerms'),
                  onTap: () => _push(context, const PolicyTermsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingSection(
              title: strings.account,
              children: [
                SettingTile(
                  icon: Icons.delete_outline,
                  title: strings.deleteAccountRequest,
                  isDanger: true,
                  onTap: () =>
                      _push(context, const DeleteAccountRequestScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(AppLocalizations strings, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => strings.lightMode,
      ThemeMode.dark => strings.darkMode,
      ThemeMode.system => strings.systemDefault,
    };
  }
}
