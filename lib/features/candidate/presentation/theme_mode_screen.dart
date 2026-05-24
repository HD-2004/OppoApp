import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme_controller.dart';

class ThemeModeScreen extends ConsumerWidget {
  const ThemeModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final selectedMode =
        ref.watch(appThemeControllerProvider).asData?.value ?? ThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: Text(strings.themeMode)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ThemeModeTile(
              title: strings.systemDefault,
              selected: selectedMode == ThemeMode.system,
              onTap: () => ref
                  .read(appThemeControllerProvider.notifier)
                  .setThemeMode(ThemeMode.system),
            ),
            _ThemeModeTile(
              title: strings.lightMode,
              selected: selectedMode == ThemeMode.light,
              onTap: () => ref
                  .read(appThemeControllerProvider.notifier)
                  .setThemeMode(ThemeMode.light),
            ),
            _ThemeModeTile(
              title: strings.darkMode,
              selected: selectedMode == ThemeMode.dark,
              onTap: () => ref
                  .read(appThemeControllerProvider.notifier)
                  .setThemeMode(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: onTap,
    );
  }
}
