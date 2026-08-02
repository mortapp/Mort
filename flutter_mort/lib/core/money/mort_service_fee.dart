class MortServiceFee {
  const MortServiceFee._();

  static const int serviceFeeCents = 0;
  static const int maximumJobAmountCents = 10000000;

  static int? tryParseAdultAmount(String? value) {
    final text = value?.trim() ?? '';
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (match == null) return null;

    final dollars = int.tryParse(match.group(1)!);
    if (dollars == null) return null;
    final decimal = match.group(2) ?? '';
    final cents = switch (decimal.length) {
      0 => 0,
      1 => int.parse(decimal) * 10,
      _ => int.parse(decimal),
    };
    final amount = dollars * 100 + cents;
    if (amount <= 0 || amount > maximumJobAmountCents) {
      return null;
    }
    return amount;
  }

  static String? validateAdultAmount(String? value, {bool optional = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty && optional) return null;
    if (text.isEmpty) return 'Enter the total job amount.';
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) {
      return 'Enter dollars with no more than 2 decimal places.';
    }
    final cents = _parseUnchecked(text);
    if (cents == null || cents > maximumJobAmountCents) {
      return 'Enter a job amount of \$100,000 or less.';
    }
    if (cents <= 0) {
      return 'The offered job amount must be greater than zero.';
    }
    return null;
  }

  static MortFeeBreakdown? breakdown(String? value) {
    final adultAmount = tryParseAdultAmount(value);
    if (adultAmount == null) return null;
    return MortFeeBreakdown(
      adultJobAmountCents: adultAmount,
      serviceFeeCents: serviceFeeCents,
      teenPayoutCents: adultAmount - serviceFeeCents,
    );
  }

  static int? _parseUnchecked(String value) {
    final parts = value.split('.');
    final dollars = int.tryParse(parts.first);
    if (dollars == null) return null;
    final cents = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
    return dollars * 100 + cents;
  }
}

class MortFeeBreakdown {
  const MortFeeBreakdown({
    required this.adultJobAmountCents,
    required this.serviceFeeCents,
    required this.teenPayoutCents,
  });

  final int adultJobAmountCents;
  final int serviceFeeCents;
  final int teenPayoutCents;
}
