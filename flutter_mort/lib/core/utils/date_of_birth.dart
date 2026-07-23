class DateOfBirthValidation {
  const DateOfBirthValidation.valid(this.date) : message = null;

  const DateOfBirthValidation.invalid(this.message) : date = null;

  final DateTime? date;
  final String? message;

  bool get isValid => date != null && message == null;
}

class DateOfBirthParser {
  const DateOfBirthParser._();

  static final RegExp _displayPattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateOfBirthValidation validate(
    String? value, {
    DateTime? today,
    int maximumAge = 120,
  }) {
    final text = value?.trim() ?? '';
    if (text.length < 10) {
      return const DateOfBirthValidation.invalid(
        'Enter your full date of birth.',
      );
    }

    final match = _displayPattern.firstMatch(text);
    if (match == null) {
      return const DateOfBirthValidation.invalid('Use MM/DD/YYYY.');
    }

    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final date = _strictCalendarDate(year: year, month: month, day: day);
    if (date == null) {
      return const DateOfBirthValidation.invalid('Enter a real calendar date.');
    }

    final calendarToday = _calendarDate(today ?? DateTime.now());
    if (date.isAfter(calendarToday)) {
      return const DateOfBirthValidation.invalid(
        'Date of birth cannot be in the future.',
      );
    }
    if (ageOn(date, calendarToday) > maximumAge) {
      return const DateOfBirthValidation.invalid('Enter a real date of birth.');
    }

    return DateOfBirthValidation.valid(date);
  }

  static DateTime? tryParse(String? value, {DateTime? today}) {
    return validate(value, today: today).date;
  }

  static DateTime? tryParseIso(String? value) {
    final match = _isoPattern.firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    return _strictCalendarDate(
      year: int.parse(match.group(1)!),
      month: int.parse(match.group(2)!),
      day: int.parse(match.group(3)!),
    );
  }

  static String display(DateTime date) {
    return '${_two(date.month)}/${_two(date.day)}/${_four(date.year)}';
  }

  static String? displayFromIso(String? value) {
    final date = tryParseIso(value);
    return date == null ? null : display(date);
  }

  static String toIsoDate(DateTime date) {
    return '${_four(date.year)}-${_two(date.month)}-${_two(date.day)}';
  }

  static int ageOn(DateTime dob, DateTime today) {
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  static DateTime _calendarDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime? _strictCalendarDate({
    required int year,
    required int month,
    required int day,
  }) {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _four(int value) => value.toString().padLeft(4, '0');
}

class DateOfBirthRules {
  const DateOfBirthRules._();

  static const teenMinimumAge = 13;
  static const teenMaximumAge = 17;
  static const adultMinimumAge = 18;

  static String? roleAgeError({required int age, required bool teenRole}) {
    if (teenRole) {
      if (age < teenMinimumAge || age > teenMaximumAge) {
        return 'Teens must be ages 13-17.';
      }
      return null;
    }
    if (age < adultMinimumAge) {
      return 'Adults and guardians must be 18 or older.';
    }
    return null;
  }
}
