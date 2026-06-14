import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/preferences/app_preferences.dart';
import 'package:oppo_temp_jobs/core/theme/app_theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'loads persisted system theme mode instead of resetting to light',
    () async {
      SharedPreferences.setMockInitialValues({
        AppPreferenceKeys.appThemeMode: 'system',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = await container.read(appThemeControllerProvider.future);

      expect(mode, ThemeMode.system);
    },
  );

  test('persists dark theme mode in shared preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(appThemeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AppPreferenceKeys.appThemeMode), 'dark');
    expect(
      container.read(appThemeControllerProvider).asData?.value,
      ThemeMode.dark,
    );
  });
}
