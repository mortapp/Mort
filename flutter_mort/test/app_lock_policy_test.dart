import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_mort/services/app_lock_controller.dart';
import 'package:flutter_mort/services/device_authentication_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLockController settings restore', () {
    test(
      'keeps initialization closed and allows retry after a read failure',
      () async {
        var shouldFail = true;
        final controller = AppLockController(
          storage: const FlutterSecureStorage(),
          authentication: _SupportedDeviceAuthentication(),
          settingsReader: () async {
            if (shouldFail) throw StateError('secure storage unavailable');
            return {'mort.app_lock.enabled': 'true'};
          },
        );

        await controller.initialize();

        expect(controller.initialized, isFalse);
        expect(controller.failureMessage, isNotNull);
        expect(
          await controller.updateSettings(requireLock: false, minutes: 15),
          isFalse,
        );

        shouldFail = false;
        await controller.initialize();

        expect(controller.initialized, isTrue);
        expect(controller.enabled, isTrue);
        expect(controller.isLocked, isTrue);
        expect(controller.failureMessage, isNull);
      },
    );
  });

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

class _SupportedDeviceAuthentication extends DeviceAuthenticationService {
  @override
  Future<DeviceAuthenticationCapability> capability() async =>
      const DeviceAuthenticationCapability(
        supported: true,
        hasEnrolledBiometrics: true,
        label: 'Test device authentication',
      );
}
