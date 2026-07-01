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
    expect(source, isNot(contains('localhost:8000')));
    expect(source, isNot(contains('127.0.0.1:8000')));
    expect(source, isNot(contains('http.post')));
    expect(source, contains('aiInterviewRepositoryProvider'));
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
}
