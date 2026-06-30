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
    final raw = value.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw);
    if (match == null) {
      return null;
    }

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return null;
    }

    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static String formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
