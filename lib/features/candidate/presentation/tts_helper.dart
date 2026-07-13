import 'tts_helper_stub.dart'
    if (dart.library.js) 'tts_helper_web.dart';

class TtsHelper {
  static bool get isSupported => isSupportedPlatform;

  static void speak(String text, {Function()? onStart, Function()? onEnd}) {
    speakPlatform(text, onStart: onStart, onEnd: onEnd);
  }

  static void stop() {
    stopPlatform();
  }

  static bool get isSpeaking => isSpeakingPlatform;
}
