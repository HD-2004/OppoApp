import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/formatters/app_date_formatter.dart';

void main() {
  group('AppDateFormatter', () {
    test('formats dates for Vietnamese UI', () {
      expect(
        AppDateFormatter.formatVietnameseDate(DateTime(2005, 7, 15)),
        '15/07/2005',
      );
    });

    test('parses Vietnamese and ISO date-only strings', () {
      expect(
        AppDateFormatter.parseDateOnly('15/07/2005'),
        DateTime(2005, 7, 15),
      );
      expect(
        AppDateFormatter.parseDateOnly('2005-07-15'),
        DateTime(2005, 7, 15),
      );
    });

    test('normalizes display input to storage format', () {
      expect(AppDateFormatter.normalizeDateOnly('15/07/2005'), '2005-07-15');
      expect(AppDateFormatter.normalizeDateOnly('2005-07-15'), '2005-07-15');
    });

    test('rejects invalid calendar dates', () {
      expect(AppDateFormatter.parseDateOnly('31/02/2005'), isNull);
      expect(AppDateFormatter.normalizeDateOnly('2005-02-31'), isNull);
    });
  });
}
