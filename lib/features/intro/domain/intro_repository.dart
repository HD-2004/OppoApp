abstract interface class IntroRepositoryContract {
  Future<bool> hasSeenIntro();

  Future<void> markIntroAsSeen();
}
