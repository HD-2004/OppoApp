import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language_controller.dart';
import '../../../core/localization/app_localizations.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final selectedLocale =
        ref.watch(appLanguageControllerProvider).asData?.value ??
        const Locale('vi');

    return Scaffold(
      appBar: AppBar(title: Text(strings.appLanguage)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LanguageTile(
              title: 'Tiếng Việt',
              selected: selectedLocale.languageCode == 'vi',
              onTap: () => ref
                  .read(appLanguageControllerProvider.notifier)
                  .setLocale(const Locale('vi')),
            ),
            _LanguageTile(
              title: 'English',
              selected: selectedLocale.languageCode == 'en',
              onTap: () => ref
                  .read(appLanguageControllerProvider.notifier)
                  .setLocale(const Locale('en')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
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
