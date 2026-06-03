import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../preferences/app_preferences.dart';

final appThemeControllerProvider =
    AsyncNotifierProvider<AppThemeController, ThemeMode>(
      AppThemeController.new,
    );

class AppThemeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final preferences = await SharedPreferences.getInstance();
    return _themeModeFromValue(
      preferences.getString(AppPreferenceKeys.appThemeMode),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(AppPreferenceKeys.appThemeMode, mode.value);
  }

  ThemeMode _themeModeFromValue(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }
}

extension ThemeModeValue on ThemeMode {
  String get value {
    return switch (this) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
