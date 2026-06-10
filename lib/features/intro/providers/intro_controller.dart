import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/intro_repository.dart';
import '../domain/intro_repository.dart';

final introRepositoryProvider = Provider<IntroRepositoryContract>((ref) {
  return const IntroRepository();
});

final introControllerProvider = AsyncNotifierProvider<IntroController, bool>(
  IntroController.new,
);

class IntroController extends AsyncNotifier<bool> {
  IntroRepositoryContract get _repository => ref.read(introRepositoryProvider);

  @override
  Future<bool> build() {
    return _repository.hasSeenIntro();
  }

  Future<void> markIntroAsSeen() async {
    await _repository.markIntroAsSeen();
    state = const AsyncData(true);
  }
}
