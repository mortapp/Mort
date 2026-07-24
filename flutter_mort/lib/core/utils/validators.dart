class MortValidators {
  const MortValidators._();

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Enter a valid email.';
  }

  static String? password(
    String? value, {
    int minimumLength = 12,
    bool requireComplexity = true,
  }) {
    final password = value ?? '';
    if (password.length < minimumLength) {
      return 'Use at least $minimumLength characters.';
    }
    if (requireComplexity &&
        (!RegExp('[a-z]').hasMatch(password) ||
            !RegExp('[A-Z]').hasMatch(password) ||
            !RegExp('[0-9]').hasMatch(password) ||
            !RegExp(r'[^A-Za-z0-9]').hasMatch(password))) {
      return 'Use uppercase, lowercase, a number, and a symbol.';
    }
    return null;
  }

  static String? requiredText(
    String? value, {
    String message = 'Required.',
    int minimumLength = 1,
    int maximumLength = 500,
  }) {
    final text = value?.trim() ?? '';
    if (text.length < minimumLength) return message;
    if (text.length > maximumLength) {
      return 'Keep this under $maximumLength characters.';
    }
    return null;
  }

  static String? stateCode(String? value) {
    final state = value?.trim() ?? '';
    return RegExp(r'^[A-Za-z]{2}$').hasMatch(state)
        ? null
        : 'Use a 2-letter state code.';
  }

  static String? dollarAmount(String? value, {bool optional = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty && optional) return null;
    final amount = num.tryParse(text);
    if (amount == null || amount <= 0 || amount > 100000) {
      return 'Enter a valid positive dollar amount.';
    }
    if (amount * 100 != (amount * 100).roundToDouble()) {
      return 'Use no more than 2 decimal places.';
    }
    return null;
  }

  static int? dollarsToCents(String? value) {
    final text = value?.trim() ?? '';
    final amount = num.tryParse(text);
    if (amount == null || amount <= 0) return null;
    return (amount * 100).round();
  }

  static const _unsafeJobTerms = <String>{
    'adult entertainment',
    'buy gift card',
    'dangerous machinery',
    'drug delivery',
    'firearm',
    'hazardous chemical',
    'pay upfront',
    'roofing',
    'weapon',
  };

  static String? teenSafeJobText(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    for (final term in _unsafeJobTerms) {
      if (text.contains(term)) {
        return 'This includes a prohibited or high-risk job term: $term.';
      }
    }
    return null;
  }
}
