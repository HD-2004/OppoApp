import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/voice_rss_tts.dart';

void main() {
  test('builds Voice RSS Vietnamese interview speech URL', () {
    final request = VoiceRssTtsRequest(apiKey: 'test-key');
    final uri = request.uriFor('Xin chào ứng viên');

    expect(uri.scheme, 'https');
    expect(uri.host, 'api.voicerss.org');
    expect(uri.queryParameters['key'], 'test-key');
    expect(uri.queryParameters['hl'], 'vi-vn');
    expect(uri.queryParameters['v'], 'Chi');
    expect(uri.queryParameters['c'], 'MP3');
    expect(uri.queryParameters['f'], '44khz_16bit_stereo');
    expect(uri.queryParameters['src'], 'Xin chào ứng viên');
  });

  test('does not enable Voice RSS without an API key', () {
    const request = VoiceRssTtsRequest(apiKey: '');

    expect(request.isEnabled, isFalse);
    expect(() => request.uriFor('Xin chào'), throwsStateError);
  });
}
