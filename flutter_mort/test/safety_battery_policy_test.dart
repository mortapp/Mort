import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mort/features/safety/safety_battery_policy.dart';

void main() {
  test('25 percent saver depends on job and travel drain budget', () {
    final enough = SafetyBatteryDecision.evaluate(
      percent: 25,
      drainPerMinute: .05,
      travelMinutes: 10,
      jobMinutes: 60,
    );
    expect(enough.enableSaver, false);
    final insufficient = SafetyBatteryDecision.evaluate(
      percent: 25,
      drainPerMinute: .3,
      travelMinutes: 20,
      jobMinutes: 100,
    );
    expect(insufficient.enableSaver, true);
    expect(insufficient.label, 'Battery may not last');
    expect(
      SafetyBatteryDecision.evaluate(
        percent: 30,
        drainPerMinute: .3,
        travelMinutes: 20,
        jobMinutes: 100,
      ).enableSaver,
      false,
    );
  });
  test(
    'unknown readings cannot claim sufficient battery or an exact death time',
    () {
      expect(
        SafetyBatteryDecision.evaluate(percent: null).label,
        'Battery unavailable',
      );
      expect(
        SafetyBatteryDecision.evaluate(percent: 25).label,
        'Battery estimate unavailable',
      );
      expect(SafetyBatteryDecision.evaluate(percent: 25).enableSaver, false);
      final critical = SafetyBatteryDecision.evaluate(percent: 5);
      expect(critical.criticalSnapshot, true);
      expect(critical.enableSaver, true);
      expect(critical.label, 'Battery critically low');
    },
  );
  test(
    'location polling requires explicit session and backs off at critical battery',
    () {
      expect(
        SafetyLocationPolicy.forState(
          travelActive: false,
          sharingActive: false,
        ).pollEvery,
        isNull,
      );
      expect(
        SafetyLocationPolicy.forState(
          travelActive: true,
          sharingActive: false,
        ).highAccuracy,
        false,
      );
      expect(
        SafetyLocationPolicy.forState(
          travelActive: false,
          sharingActive: true,
        ).pollEvery,
        const Duration(seconds: 30),
      );
      final low = SafetyLocationPolicy.forState(
        travelActive: false,
        sharingActive: true,
        criticalBattery: true,
      );
      expect(low.highAccuracy, false);
      expect(low.pollEvery, const Duration(minutes: 2));
    },
  );
}
