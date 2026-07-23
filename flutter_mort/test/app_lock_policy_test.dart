import 'package:flutter_mort/services/app_lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLockPolicy', () {
    final now = DateTime.utc(2026, 7, 19, 12);

    test('does not lock when the user has not enabled app lock', () {
      expect(
        AppLockPolicy.shouldLock(
          enabled: false,
          backgroundedAt: now.subtract(const Duration(hours: 1)),
          now: now,
          inactivityMinutes: 15,
        ),
        isFalse,
      );
    });

    test('locks only after the configured inactivity threshold', () {
      expect(
        AppLockPolicy.shouldLock(
          enabled: true,
          backgroundedAt: now.subtract(const Duration(minutes: 14)),
          now: now,
          inactivityMinutes: 15,
        ),
        isFalse,
      );
      expect(
        AppLockPolicy.shouldLock(
          enabled: true,
          backgroundedAt: now.subtract(const Duration(minutes: 15)),
          now: now,
          inactivityMinutes: 15,
        ),
        isTrue,
      );
    });

    test('clamps invalid inactivity values to the safe range', () {
      expect(
        AppLockPolicy.shouldLock(
          enabled: true,
          backgroundedAt: now.subtract(const Duration(seconds: 30)),
          now: now,
          inactivityMinutes: 0,
        ),
        isFalse,
      );
      expect(
        AppLockPolicy.shouldLock(
          enabled: true,
          backgroundedAt: now.subtract(const Duration(minutes: 1)),
          now: now,
          inactivityMinutes: 0,
        ),
        isTrue,
      );
    });
  });
}
