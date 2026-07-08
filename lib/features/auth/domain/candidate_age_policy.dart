import '../../../core/formatters/app_date_formatter.dart';

class CandidateAgePolicy {
  const CandidateAgePolicy._();

  static const minimumAge = 18;
  static const requiredMessage = 'Vui lòng chọn ngày sinh.';
  static const invalidMessage = 'Ngày sinh không hợp lệ.';
  static const underageMessage =
      'Ứng dụng chỉ dành cho ứng viên từ 18 tuổi trở lên.';

  static bool isEligible(DateTime dateOfBirth, {DateTime? today}) {
    final birthDate = _dateOnly(dateOfBirth);
    final currentDate = _dateOnly(today ?? DateTime.now());
    if (birthDate.isAfter(currentDate)) {
      return false;
    }

    final eighteenthBirthday = DateTime(
      birthDate.year + minimumAge,
      birthDate.month,
      birthDate.day,
    );
    return !eighteenthBirthday.isAfter(currentDate);
  }

  static String? validateDateOfBirth(String? value, {DateTime? today}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return requiredMessage;
    }

    final parsed = parseDate(raw);
    if (parsed == null ||
        _dateOnly(parsed).isAfter(_dateOnly(today ?? DateTime.now()))) {
      return invalidMessage;
    }

    if (!isEligible(parsed, today: today)) {
      return underageMessage;
    }

    return null;
  }

  static DateTime? parseDate(String value) {
    return AppDateFormatter.parseDateOnly(value);
  }

  static String formatDate(DateTime date) {
    return AppDateFormatter.formatStorageDate(date);
  }

  static String formatDisplayDate(DateTime date) {
    return AppDateFormatter.formatVietnameseDate(date);
  }

  static String? normalizeDateOfBirth(String value) {
    return AppDateFormatter.normalizeDateOnly(value);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
