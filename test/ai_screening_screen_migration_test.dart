import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/candidate/presentation/ai_screening_screen.dart',
    ).readAsStringSync();
  });

  test(
    'screening screen falls back like website when shared ai is unavailable',
    () {
      expect(source, contains('CvScreeningResult.websiteMockFallback'));

      final start = source.indexOf('Future<void> _runCVScreening');
      expect(start, greaterThanOrEqualTo(0));

      final end = source.indexOf(
        '\n  Future<void> _submitRoundOneApplication',
        start,
      );
      expect(end, greaterThan(start));

      final runSource = source.substring(start, end);
      expect(runSource, contains('CvScreeningResult.websiteMockFallback'));
      expect(runSource, contains('_applicationNotice'));
      expect(
        runSource,
        isNot(contains('Không thể kết nối đến dịch vụ phỏng vấn AI')),
      );
    },
  );
}
