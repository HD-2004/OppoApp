import 'package:intl/intl.dart';

class AppDateFormatter {
  const AppDateFormatter._();

  static final DateFormat _vietnameseDate = DateFormat('dd/MM/yyyy');
  static final DateFormat _storageDate = DateFormat('yyyy-MM-dd');

  static String formatVietnameseDate(DateTime date) {
    return _vietnameseDate.format(_dateOnly(date));
  }

  static String formatStorageDate(DateTime date) {
    return _storageDate.format(_dateOnly(date));
  }

  static String formatVietnameseDateString(
    String? value, {
    String fallback = '',
  }) {
    final parsed = parseDateOnly(value);
    if (parsed == null) return fallback;
    return formatVietnameseDate(parsed);
  }

  static String? normalizeDateOnly(String? value) {
    final parsed = parseDateOnly(value);
    if (parsed == null) return null;
    return formatStorageDate(parsed);
  }

  static DateTime? parseDateOnly(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final vietnameseMatch = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})$',
    ).firstMatch(raw);
    if (vietnameseMatch != null) {
      return _strictDate(
        int.tryParse(vietnameseMatch.group(3)!),
        int.tryParse(vietnameseMatch.group(2)!),
        int.tryParse(vietnameseMatch.group(1)!),
      );
    }

    final isoDateMatch = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})$',
    ).firstMatch(raw);
    if (isoDateMatch != null) {
      return _strictDate(
        int.tryParse(isoDateMatch.group(1)!),
        int.tryParse(isoDateMatch.group(2)!),
        int.tryParse(isoDateMatch.group(3)!),
      );
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }
    return _dateOnly(parsed);
  }

  static DateTime? _strictDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
