enum MortTipPreset {
  none,
  two,
  five,
  ten,
  tenPercent,
  fifteenPercent,
  twentyPercent,
  custom,
  lateTip,
}

enum MortTipValidationState { empty, typing, valid, tooLow, tooHigh, invalid }

class MortTipPolicy {
  const MortTipPolicy({
    required this.minTipCents,
    required this.maxTipCents,
    required this.backendAuthoritative,
  });

  final int minTipCents;
  final int maxTipCents;
  final bool backendAuthoritative;

  bool get isUsable =>
      backendAuthoritative && minTipCents >= 0 && maxTipCents >= minTipCents;
}

class MortTipValidation {
  const MortTipValidation({
    required this.state,
    this.amountCents,
    this.policyAvailable = false,
  });

  final MortTipValidationState state;
  final int? amountCents;
  final bool policyAvailable;

  bool get canConfirm =>
      state == MortTipValidationState.valid && policyAvailable;
}

int? parseMortCurrencyToCents(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final unsigned = value.startsWith(r'$') ? value.substring(1) : value;
  if (unsigned.isEmpty || unsigned.contains(r'$')) return null;
  final parts = unsigned.split('.');
  if (parts.length > 2) return null;
  final whole = parts.first;
  final grouped = RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(whole);
  final ungrouped = RegExp(r'^\d+$').hasMatch(whole);
  if (!grouped && !ungrouped) return null;
  if (parts.length == 2 && !RegExp(r'^\d{1,2}$').hasMatch(parts.last)) {
    return null;
  }
  final normalizedWhole = whole.replaceAll(',', '');
  final dollars = int.tryParse(normalizedWhole);
  if (dollars == null) return null;
  final cents = parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
  return dollars * 100 + cents;
}

MortTipValidation validateMortCustomTip(String input, MortTipPolicy? policy) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const MortTipValidation(state: MortTipValidationState.empty);
  }
  if (_isPotentiallyIncompleteCurrency(trimmed)) {
    return const MortTipValidation(state: MortTipValidationState.typing);
  }
  final amount = parseMortCurrencyToCents(trimmed);
  if (amount == null) {
    return const MortTipValidation(state: MortTipValidationState.invalid);
  }
  if (policy == null || !policy.isUsable) {
    return MortTipValidation(
      state: MortTipValidationState.valid,
      amountCents: amount,
    );
  }
  if (amount < policy.minTipCents) {
    return MortTipValidation(
      state: MortTipValidationState.tooLow,
      amountCents: amount,
    );
  }
  if (amount > policy.maxTipCents) {
    return MortTipValidation(
      state: MortTipValidationState.tooHigh,
      amountCents: amount,
    );
  }
  return MortTipValidation(
    state: MortTipValidationState.valid,
    amountCents: amount,
    policyAvailable: true,
  );
}

bool _isPotentiallyIncompleteCurrency(String value) =>
    value == r'$' ||
    RegExp(r'^\$?\d+(?:,\d{3})*\.$').hasMatch(value) ||
    RegExp(r'^\$?\d{1,3},\d{0,2}$').hasMatch(value);

class MortTipSelection {
  const MortTipSelection({required this.preset, required this.amountCents});

  final MortTipPreset preset;
  final int amountCents;

  bool get isCustom => preset == MortTipPreset.custom;

  bool get excludesTipFromServiceFee => true;

  bool get excludesFeeFromFairPay => true;

  int toTeenCents(int jobTotalCents) => amountCents;

  static MortTipSelection fixed(MortTipPreset preset) {
    final amount = switch (preset) {
      MortTipPreset.none => 0,
      MortTipPreset.two => 200,
      MortTipPreset.five => 500,
      MortTipPreset.ten => 1000,
      _ => throw ArgumentError.value(
        preset,
        'preset',
        'Only fixed-dollar presets can use fixed().',
      ),
    };
    return MortTipSelection(preset: preset, amountCents: amount);
  }

  static MortTipSelection percentage(MortTipPreset preset, int baseCents) {
    final percent = switch (preset) {
      MortTipPreset.tenPercent => 10,
      MortTipPreset.fifteenPercent => 15,
      MortTipPreset.twentyPercent => 20,
      _ => throw ArgumentError.value(
        preset,
        'preset',
        'Only percentage presets can use percentage().',
      ),
    };
    if (baseCents < 0) {
      throw ArgumentError.value(baseCents, 'baseCents');
    }
    return MortTipSelection(
      preset: preset,
      amountCents: (baseCents * percent + 50) ~/ 100,
    );
  }

  static MortTipSelection custom(int amountCents, {bool late = false}) {
    if (amountCents < 0) {
      throw ArgumentError.value(amountCents, 'amountCents');
    }
    return MortTipSelection(
      preset: late ? MortTipPreset.lateTip : MortTipPreset.custom,
      amountCents: amountCents,
    );
  }
}
