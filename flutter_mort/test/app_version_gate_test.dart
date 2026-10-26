import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.isAppVersionSupported', () {
    test('accepts the minimum and newer semantic versions', () {
      expect(
        AppConfig.isAppVersionSupported('0.9.11', minimum: '0.9.11'),
        isTrue,
      );
      expect(
        AppConfig.isAppVersionSupported('0.9.12', minimum: '0.9.11'),
        isTrue,
      );
      expect(
        AppConfig.isAppVersionSupported('0.10.0', minimum: '0.9.11'),
        isTrue,
      );
      expect(
        AppConfig.isAppVersionSupported('1.0.0', minimum: '0.9.11'),
        isTrue,
      );
    });

    test('rejects versions below the minimum', () {
      expect(
        AppConfig.isAppVersionSupported('0.9.10', minimum: '0.9.11'),
        isFalse,
      );
      expect(
        AppConfig.isAppVersionSupported('0.8.99', minimum: '0.9.11'),
        isFalse,
      );
      expect(
        AppConfig.isAppVersionSupported('0.9.11', minimum: '0.10.0'),
        isFalse,
      );
    });

    test('rejects malformed versions instead of guessing', () {
      expect(
        AppConfig.isAppVersionSupported('unknown', minimum: '0.9.11'),
        isFalse,
      );
      expect(
        AppConfig.isAppVersionSupported('0.9.12', minimum: 'next'),
        isFalse,
      );
      expect(
        AppConfig.isAppVersionSupported('0.9.12.1', minimum: '0.9.11'),
        isFalse,
      );
    });
  });

  test('throws an update-required error for a known old version', () async {
    await expectLater(
      AppConfig.assertSupportedAppVersion(
        currentVersion: '0.9.10',
        minimumVersion: '0.9.11',
      ),
      throwsA(
        isA<AppUpdateRequiredException>()
            .having((error) => error.currentVersion, 'current', '0.9.10')
            .having((error) => error.minimumVersion, 'minimum', '0.9.11'),
      ),
    );
  });

  test('accepts a known supported version', () async {
    await AppConfig.assertSupportedAppVersion(
      currentVersion: '0.9.12',
      minimumVersion: '0.9.11',
    );
  });
}
