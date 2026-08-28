import 'package:flutter/services.dart';
import 'package:flutter_mort/core/utils/date_of_birth.dart';
import 'package:flutter_mort/core/widgets/date_of_birth_field.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue edit(
  MmDdYyyyInputFormatter formatter,
  String oldText,
  String newText, {
  int? oldOffset,
  int? newOffset,
}) {
  return formatter.formatEditUpdate(
    TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: oldOffset ?? oldText.length),
    ),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset ?? newText.length),
    ),
  );
}

void main() {
  group('MmDdYyyyInputFormatter', () {
    const formatter = MmDdYyyyInputFormatter();

    test('formats progressively while digits are entered', () {
      expect(edit(formatter, '', '0').text, '0');
      expect(edit(formatter, '0', '06').text, '06/');
      expect(edit(formatter, '06/', '06/2').text, '06/2');
      expect(edit(formatter, '06/2', '06/29').text, '06/29/');
      expect(edit(formatter, '06/29/', '06292011').text, '06/29/2011');
    });

    test('keeps an already formatted pasted date unchanged', () {
      expect(edit(formatter, '', '06/29/2011').text, '06/29/2011');
    });

    test('converts pasted ISO date to display format', () {
      final value = edit(formatter, '', '2011-06-29');
      expect(value.text, '06/29/2011');
      expect(value.selection.baseOffset, 10);
    });

    test('removes letters and unrelated symbols', () {
      expect(edit(formatter, '', '0a6b').text, '06/');
      expect(edit(formatter, '', '@06#29!2011').text, '06/29/2011');
    });

    test('limits input to eight digits', () {
      expect(edit(formatter, '', '06292011999').text, '06/29/2011');
    });

    test('backspace across month slash removes the preceding digit', () {
      final value = edit(formatter, '06/', '06', oldOffset: 3, newOffset: 2);
      expect(value.text, '0');
      expect(value.selection.baseOffset, 1);
    });

    test('backspace across day slash remains editable', () {
      final value = edit(
        formatter,
        '06/29/',
        '06/29',
        oldOffset: 6,
        newOffset: 5,
      );
      expect(value.text, '06/2');
      expect(value.selection.baseOffset, 4);
    });

    test('cursor lands after an automatically inserted slash', () {
      expect(edit(formatter, '0', '06').selection.baseOffset, 3);
      expect(edit(formatter, '06/2', '06/29').selection.baseOffset, 6);
    });
  });

  group('DateOfBirthParser', () {
    final today = DateTime(2026, 7, 11);

    test('parses a valid standard date', () {
      expect(
        DateOfBirthParser.validate('06/29/2011', today: today).date,
        DateTime(2011, 6, 29),
      );
    });

    test('accepts a valid leap day', () {
      expect(
        DateOfBirthParser.validate('02/29/2012', today: today).isValid,
        isTrue,
      );
    });

    test('rejects invalid leap day, month, and day', () {
      expect(
        DateOfBirthParser.validate('02/29/2011', today: today).message,
        'Enter a real calendar date.',
      );
      expect(
        DateOfBirthParser.validate('13/15/2011', today: today).message,
        'Enter a real calendar date.',
      );
      expect(
        DateOfBirthParser.validate('06/00/2011', today: today).message,
        'Enter a real calendar date.',
      );
    });

    test('rejects incomplete and incorrectly formatted dates', () {
      expect(
        DateOfBirthParser.validate('06/2', today: today).message,
        'Enter your full date of birth.',
      );
      expect(
        DateOfBirthParser.validate('06292011', today: today).message,
        'Enter your full date of birth.',
      );
    });

    test('rejects a future date', () {
      expect(
        DateOfBirthParser.validate('06/29/2099', today: today).message,
        'Date of birth cannot be in the future.',
      );
    });

    test('round-trips display and ISO storage without timezone conversion', () {
      final date = DateTime(2011, 6, 29);
      expect(DateOfBirthParser.toIsoDate(date), '2011-06-29');
      expect(DateOfBirthParser.displayFromIso('2011-06-29'), '06/29/2011');
      expect(DateOfBirthParser.tryParseIso('2011-06-29'), date);
    });
  });

  group('DOB age and role rules', () {
    final today = DateTime(2026, 7, 11);

    test('respects whether the birthday happened this year', () {
      expect(DateOfBirthParser.ageOn(DateTime(2010, 7, 10), today), 16);
      expect(DateOfBirthParser.ageOn(DateTime(2010, 7, 12), today), 15);
    });

    test('calculates exact 13, 17, and 18 boundaries', () {
      expect(DateOfBirthParser.ageOn(DateTime(2013, 7, 11), today), 13);
      expect(DateOfBirthParser.ageOn(DateTime(2009, 7, 11), today), 17);
      expect(DateOfBirthParser.ageOn(DateTime(2008, 7, 11), today), 18);
      expect(DateOfBirthParser.ageOn(DateTime(2013, 7, 12), today), 12);
    });

    test('allows teen ages 13 through 17 only', () {
      expect(DateOfBirthRules.roleAgeError(age: 13, teenRole: true), isNull);
      expect(DateOfBirthRules.roleAgeError(age: 17, teenRole: true), isNull);
      expect(
        DateOfBirthRules.roleAgeError(age: 12, teenRole: true),
        'Teens must be ages 13-17.',
      );
      expect(
        DateOfBirthRules.roleAgeError(age: 18, teenRole: true),
        'Teens must be ages 13-17.',
      );
    });

    test('requires adults and guardians to be at least 18', () {
      expect(DateOfBirthRules.roleAgeError(age: 18, teenRole: false), isNull);
      expect(
        DateOfBirthRules.roleAgeError(age: 17, teenRole: false),
        'Adults and guardians must be 18 or older.',
      );
    });
  });
}
