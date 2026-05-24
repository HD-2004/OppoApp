import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../preferences/app_preferences.dart';

final appLanguageControllerProvider =
    AsyncNotifierProvider<AppLanguageController, Locale>(
      AppLanguageController.new,
    );

class AppLanguageController extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async {
    final preferences = await SharedPreferences.getInstance();
    return _localeFromValue(preferences.getString(AppPreferenceKeys.appLocale));
  }

  Future<void> setLocale(Locale locale) async {
    state = AsyncData(locale);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      AppPreferenceKeys.appLocale,
      locale.languageCode,
    );
  }

  Locale _localeFromValue(String? value) {
    return switch (value) {
      'en' => const Locale('en'),
      'vi' => const Locale('vi'),
      _ => const Locale('vi'),
    };
  }
}
