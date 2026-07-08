import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/domain/candidate_age_policy.dart';

void main() {
  group('CandidateAgePolicy', () {
    final today = DateTime(2026, 6, 29);

    test('accepts candidate on exact 18th birthday', () {
      expect(
        CandidateAgePolicy.isEligible(DateTime(2008, 6, 29), today: today),
        isTrue,
      );
    });

    test('rejects candidate one day before 18th birthday', () {
      expect(
        CandidateAgePolicy.isEligible(DateTime(2008, 6, 30), today: today),
        isFalse,
      );
    });

    test('rejects future birth dates', () {
      expect(
        CandidateAgePolicy.validateDateOfBirth('2026-06-30', today: today),
        'Ngày sinh không hợp lệ.',
      );
    });

    test('rejects invalid or empty birth date strings', () {
      expect(
        CandidateAgePolicy.validateDateOfBirth('', today: today),
        'Vui lòng chọn ngày sinh.',
      );
      expect(
        CandidateAgePolicy.validateDateOfBirth('not-a-date', today: today),
        'Ngày sinh không hợp lệ.',
      );
    });

    test('rejects underage Vietnamese birth date strings', () {
      expect(
        CandidateAgePolicy.validateDateOfBirth('30/06/2008', today: today),
        'Ứng dụng chỉ dành cho ứng viên từ 18 tuổi trở lên.',
      );
    });

    test('formats dates for storage as yyyy-MM-dd', () {
      expect(CandidateAgePolicy.formatDate(DateTime(2008, 1, 5)), '2008-01-05');
    });

    test('formats dates for Vietnamese UI as dd/MM/yyyy', () {
      expect(
        CandidateAgePolicy.formatDisplayDate(DateTime(2008, 1, 5)),
        '05/01/2008',
      );
    });

    test('normalizes Vietnamese UI input for storage', () {
      expect(
        CandidateAgePolicy.normalizeDateOfBirth('05/01/2008'),
        '2008-01-05',
      );
    });
  });
}
