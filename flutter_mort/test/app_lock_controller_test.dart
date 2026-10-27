import 'package:flutter_mort/services/app_lock_controller.dart';
import 'package:flutter_mort/services/device_authentication_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLockController.initialize', () {
    test(
      'keeps an enabled app locked when device auth is unavailable',
      () async {
        final controller = AppLockController(
          settingsStore: _SettingsStore({'mort.app_lock.enabled': 'true'}),
          authentication: _Authentication(
            const DeviceAuthenticationCapability.unavailable(),
          ),
        );

        await controller.initialize();

        expect(controller.initialized, isTrue);
        expect(controller.enabled, isTrue);
        expect(controller.isLocked, isTrue);
        expect(controller.capability.supported, isFalse);
        await controller.unlock();
        expect(controller.isLocked, isTrue);
        expect(controller.failureMessage, contains('unavailable'));
        controller.dispose();
      },
    );

    test(
      'fails closed when saved app-lock settings cannot be restored',
      () async {
        final controller = AppLockController(
          settingsStore: _SettingsStore({}, failRead: true),
          authentication: _Authentication(
            const DeviceAuthenticationCapability(
              supported: true,
              hasEnrolledBiometrics: false,
              label: 'Device PIN, pattern, or passcode',
            ),
          ),
        );

        await controller.initialize();

        expect(controller.initialized, isTrue);
        expect(controller.enabled, isTrue);
        expect(controller.isLocked, isTrue);
        expect(controller.failureMessage, contains('could not be restored'));
        controller.dispose();
      },
    );
  });
}

class _SettingsStore implements AppLockSettingsStore {
  _SettingsStore(this.values, {this.failRead = false});

  final Map<String, String> values;
  final bool failRead;

  @override
  Future<Map<String, String>> readAll() async {
    if (failRead) throw StateError('storage unavailable');
    return values;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _Authentication implements AppLockAuthentication {
  _Authentication(this.resultCapability);

  final DeviceAuthenticationCapability resultCapability;

  @override
  Future<DeviceAuthenticationCapability> capability() async => resultCapability;

  @override
  Future<DeviceAuthenticationResult> authenticate(String reason) async =>
      resultCapability.supported
      ? const DeviceAuthenticationResult(
          DeviceAuthenticationStatus.authenticated,
          'Authenticated',
        )
      : const DeviceAuthenticationResult(
          DeviceAuthenticationStatus.unavailable,
          'Device authentication is unavailable.',
        );
}
