class VoiceRssInterviewTts {
  static const apiKey = String.fromEnvironment('VOICERSS_API_KEY');
  static const language = String.fromEnvironment(
    'VOICERSS_LANGUAGE',
    defaultValue: 'vi-vn',
  );
  static const voice = String.fromEnvironment(
    'VOICERSS_VOICE',
    defaultValue: 'Chi',
  );
  static const codec = String.fromEnvironment(
    'VOICERSS_CODEC',
    defaultValue: 'MP3',
  );
  static const format = String.fromEnvironment(
    'VOICERSS_FORMAT',
    defaultValue: '44khz_16bit_stereo',
  );
  static const rate = int.fromEnvironment('VOICERSS_RATE', defaultValue: 0);

  static VoiceRssTtsRequest get request => VoiceRssTtsRequest(
    apiKey: apiKey,
    language: language,
    voice: voice,
    codec: codec,
    format: format,
    rate: rate,
  );

  static bool get isEnabled => request.isEnabled;

  static Uri uriFor(String text) => request.uriFor(text);
}

class VoiceRssTtsRequest {
  final String apiKey;
  final String language;
  final String voice;
  final String codec;
  final String format;
  final int rate;

  const VoiceRssTtsRequest({
    required this.apiKey,
    this.language = 'vi-vn',
    this.voice = 'Chi',
    this.codec = 'MP3',
    this.format = '44khz_16bit_stereo',
    this.rate = 0,
  });

  bool get isEnabled => apiKey.trim().isNotEmpty;

  Uri uriFor(String text) {
    final cleanText = text.trim();
    if (!isEnabled) {
      throw StateError('Voice RSS API key is not configured.');
    }
    if (cleanText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Text must not be empty.');
    }

    return Uri.https('api.voicerss.org', '/', {
      'key': apiKey.trim(),
      'hl': language,
      'v': voice,
      'r': rate.toString(),
      'c': codec,
      'f': format,
      'src': cleanText,
    });
  }
}
