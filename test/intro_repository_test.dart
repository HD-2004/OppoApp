import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/intro/data/intro_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hasSeenIntro returns false when no local flag exists', () async {
    final repository = IntroRepository();

    final hasSeenIntro = await repository.hasSeenIntro();

    expect(hasSeenIntro, isFalse);
  });

  test('markIntroAsSeen stores the stable local intro flag', () async {
    final repository = IntroRepository();

    await repository.markIntroAsSeen();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('has_seen_intro'), isTrue);
    expect(await repository.hasSeenIntro(), isTrue);
  });
}
