import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/preferences/app_preferences.dart';
import '../domain/intro_repository.dart';

class IntroRepository implements IntroRepositoryContract {
  const IntroRepository();

  @override
  Future<bool> hasSeenIntro() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(AppPreferenceKeys.hasSeenIntro) ?? false;
  }

  @override
  Future<void> markIntroAsSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(AppPreferenceKeys.hasSeenIntro, true);
  }
}
