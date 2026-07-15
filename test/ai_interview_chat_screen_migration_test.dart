import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/candidate/presentation/ai_interview_chat_screen.dart',
    ).readAsStringSync();
  });

  test('chat screen uses shared ai repository instead of local FastAPI', () {
    final localFastApiHost = ['localhost', '8000'].join(':');
    final loopbackFastApiHost = ['127.0.0.1', '8000'].join(':');
    final directHttpPostCall = ['http', 'post'].join('.');

    expect(source, isNot(contains(localFastApiHost)));
    expect(source, isNot(contains(loopbackFastApiHost)));
    expect(source, isNot(contains(directHttpPostCall)));
    expect(source, contains('aiInterviewRepositoryProvider'));
  });

  test('chat screen falls back like website when shared ai is unavailable', () {
    expect(source, contains('mockInterviewSessionId'));
    expect(source, contains('websiteMockFallback'));
  });

  test('chat screen updates existing application after interview pass', () {
    final start = source.indexOf('Future<void> _submitDeferredApplication');
    expect(start, greaterThanOrEqualTo(0));

    final end = source.indexOf('\n  void _showReportDialog', start);
    expect(end, greaterThan(start));

    final deferredSource = source.substring(start, end);
    expect(deferredSource, contains('applicationId'));
    expect(deferredSource, contains('updateApplicationStatus'));
    expect(deferredSource, isNot(contains('submitApplication(')));
  });

  test('interview screen is voice-only instead of typed chat', () {
    expect(source, contains("package:speech_to_text/speech_to_text.dart"));
    expect(source, contains("package:flutter_tts/flutter_tts.dart"));
    expect(source, contains("package:audioplayers/audioplayers.dart"));
    expect(source, contains('VoiceRssInterviewTts'));

    expect(source, isNot(contains('TextEditingController')));
    expect(source, isNot(contains('TextField')));
    expect(source, isNot(contains('Nhập câu trả lời')));
    expect(source, isNot(contains('_buildInputBar')));
    expect(source, isNot(contains('_buildMessageBubble')));
  });

  test('interview screen requires rules and microphone before starting', () {
    expect(source, contains('_prepareAndStartInterview'));
    expect(source, contains('requestBrowserMicrophonePermission'));
    expect(source, contains('Quy chế Phỏng vấn AI bắt buộc'));
    expect(source, contains('Tôi đã đọc hiểu và cam kết tuân thủ quy chế'));
    expect(source, contains('Cần cấp quyền Micro để bắt đầu'));
    expect(source, contains('Bắt đầu ngay'));
  });

  test('interview speech capture does not stop on early final chunks', () {
    final start = source.indexOf('void _handleSpeechResult');
    expect(start, greaterThanOrEqualTo(0));

    final end = source.indexOf('\n  void _handleSpeechStatus', start);
    expect(end, greaterThan(start));

    final resultHandlerSource = source.substring(start, end);
    expect(resultHandlerSource, isNot(contains('_stopListening')));
    expect(source, contains('pauseFor: const Duration(seconds: 12)'));
    expect(source, contains('listenFor: const Duration(seconds: 90)'));
  });

  test('interview speech capture uses Vietnamese locale on web', () {
    expect(source, contains("package:flutter/foundation.dart"));
    expect(source, contains('kIsWeb'));
    expect(source, contains("'vi-VN'"));
  });
}
