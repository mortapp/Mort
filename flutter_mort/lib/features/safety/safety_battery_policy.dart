class SafetyBatteryDecision {
  const SafetyBatteryDecision(
    this.label,
    this.enableSaver,
    this.criticalSnapshot,
  );
  final String label;
  final bool enableSaver;
  final bool criticalSnapshot;
  static SafetyBatteryDecision evaluate({
    required int? percent,
    double? drainPerMinute,
    int travelMinutes = 0,
    int jobMinutes = 0,
    int marginMinutes = 20,
  }) {
    if (percent == null || percent < 0 || percent > 100) {
      return const SafetyBatteryDecision('Battery unavailable', false, false);
    }
    if (percent <= 5)
      return const SafetyBatteryDecision('Battery critically low', true, true);
    final known =
        drainPerMinute != null && drainPerMinute > 0 && drainPerMinute.isFinite;
    final insufficient =
        known &&
        drainPerMinute * (travelMinutes + jobMinutes + marginMinutes) > percent;
    return SafetyBatteryDecision(
      percent <= 15
          ? 'Battery low'
          : !known
          ? 'Battery estimate unavailable'
          : insufficient
          ? 'Battery may not last'
          : 'Battery looks sufficient',
      percent <= 25 && insufficient,
      false,
    );
  }
}

class SafetyLocationPolicy {
  const SafetyLocationPolicy(this.pollEvery, this.highAccuracy);
  final Duration? pollEvery;
  final bool highAccuracy;
  static SafetyLocationPolicy forState({
    required bool travelActive,
    required bool sharingActive,
    bool criticalBattery = false,
    bool stationary = false,
  }) {
    if (!travelActive && !sharingActive)
      return const SafetyLocationPolicy(null, false);
    if (criticalBattery)
      return const SafetyLocationPolicy(Duration(minutes: 2), false);
    if (sharingActive)
      return const SafetyLocationPolicy(Duration(seconds: 30), true);
    return SafetyLocationPolicy(
      stationary ? const Duration(minutes: 3) : const Duration(minutes: 1),
      false,
    );
  }
}
