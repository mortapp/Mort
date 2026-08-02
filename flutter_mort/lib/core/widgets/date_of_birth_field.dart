import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/date_of_birth.dart';

class MmDdYyyyInputFormatter extends TextInputFormatter {
  const MmDdYyyyInputFormatter();

  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final trimmed = newValue.text.trim();
    final isoMatch = _isoPattern.firstMatch(trimmed);
    if (isoMatch != null) {
      final digits =
          '${isoMatch.group(2)}${isoMatch.group(3)}${isoMatch.group(1)}';
      final formatted = _formatDigits(digits);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final oldDigits = _digitsOnly(oldValue.text);
    var digits = _digitsOnly(newValue.text);
    final selectionOffset = newValue.selection.baseOffset.clamp(
      0,
      newValue.text.length,
    );
    var digitCursor = _digitsOnly(
      newValue.text.substring(0, selectionOffset),
    ).length;

    final deletedOnlySeparator =
        newValue.text.length < oldValue.text.length && digits == oldDigits;
    if (deletedOnlySeparator && digits.isNotEmpty) {
      final removalIndex = (digitCursor - 1).clamp(0, digits.length - 1);
      digits =
          digits.substring(0, removalIndex) +
          digits.substring(removalIndex + 1);
      digitCursor = removalIndex;
    }

    if (digits.length > 8) digits = digits.substring(0, 8);
    digitCursor = digitCursor.clamp(0, digits.length);
    final formatted = _formatDigits(digits);
    final cursor = _cursorForDigitCount(formatted, digitCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static String _formatDigits(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length < 2) return digits;
    if (digits.length == 2) return '$digits/';

    final month = digits.substring(0, 2);
    if (digits.length < 4) return '$month/${digits.substring(2)}';

    final day = digits.substring(2, 4);
    if (digits.length == 4) return '$month/$day/';
    return '$month/$day/${digits.substring(4)}';
  }

  static int _cursorForDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    var seen = 0;
    for (var index = 0; index < formatted.length; index++) {
      if (_isDigit(formatted.codeUnitAt(index))) seen++;
      if (seen == digitCount) {
        var offset = index + 1;
        if (offset < formatted.length && formatted[offset] == '/') offset++;
        return offset;
      }
    }
    return formatted.length;
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
}

class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.showDatePickerButton = true,
    this.errorText,
    this.focusNode,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool showDatePickerButton;
  final String? errorText;
  final FocusNode? focusNode;

  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime.now();
    final calendarToday = DateTime(today.year, today.month, today.day);
    final earliest = DateTime(today.year - 120, today.month, today.day);
    final parsed = DateOfBirthParser.tryParse(controller.text, today: today);
    final defaultDate = DateTime(today.year - 18, today.month, today.day);
    final initialDate =
        parsed != null &&
            !parsed.isBefore(earliest) &&
            !parsed.isAfter(calendarToday)
        ? parsed
        : defaultDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: earliest,
      lastDate: calendarToday,
      helpText: 'Select date of birth',
    );
    if (selected == null) return;
    final display = DateOfBirthParser.display(selected);
    controller.value = TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
    onChanged?.call(display);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.birthday],
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: const [MmDdYyyyInputFormatter()],
      maxLength: 10,
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      scrollPadding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + 140,
      ),
      validator:
          validator ?? (value) => DateOfBirthParser.validate(value).message,
      onChanged: onChanged,
      onFieldSubmitted: (value) {
        FocusScope.of(context).unfocus();
        onSubmitted?.call(value);
      },
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        labelText: 'Date of birth',
        hintText: 'MM/DD/YYYY',
        helperText: 'Month / Day / Year',
        errorText: errorText,
        suffixIcon: showDatePickerButton
            ? IconButton(
                tooltip: 'Choose date of birth',
                onPressed: enabled ? () => _pickDate(context) : null,
                icon: const Icon(Icons.calendar_month_outlined),
              )
            : null,
      ),
    );
  }
}
