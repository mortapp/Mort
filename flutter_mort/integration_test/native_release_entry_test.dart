import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/data/services/secure_device_storage.dart';
import 'package:flutter_mort/main.dart' as mort;
import 'package:flutter_mort/services/device_authentication_service.dart';
import 'package:flutter_mort/services/native_permissions_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native plugins and actual MORT entry fail closed offline', (
    tester,
  ) async {
    binding.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    expect(
      defaultTargetPlatform,
      anyOf(TargetPlatform.iOS, TargetPlatform.android),
    );
    expect(AppConfig.isSupabaseConfigured, isFalse);
    expect(AppConfig.browserStackQaMode, isFalse);
    final package = await PackageInfo.fromPlatform();
    expect(package.packageName, 'com.mortapp.mobile');
    expect(package.version, '0.9.16');
    expect(package.buildNumber, '111');

    const key = 'mort.native_release_entry_fixture';
    await mortSecureDeviceStorage.write(key: key, value: 'synthetic-test');
    try {
      expect(await mortSecureDeviceStorage.read(key: key), 'synthetic-test');
    } finally {
      await mortSecureDeviceStorage.delete(key: key);
    }
    expect(await mortSecureDeviceStorage.read(key: key), isNull);
    expect(
      (await DeviceAuthenticationService().capability()).label,
      isNotEmpty,
    );
    final permissions = await const NativePermissionsService().snapshot();
    expect(
      permissions.photoPickerNeedsBroadPermission,
      defaultTargetPlatform == TargetPlatform.iOS,
    );

    final frameworkHandler = FlutterError.onError;
    final platformHandler = PlatformDispatcher.instance.onError;
    try {
      await mort.main();
    } finally {
      FlutterError.onError = frameworkHandler;
      PlatformDispatcher.instance.onError = platformHandler;
    }
    await tester.pumpAndSettle();
    expect(find.text('MORT cannot start securely'), findsOneWidget);
    expect(find.text('I already have an account'), findsNothing);
    expect(tester.takeException(), isNull);
    // This is not a backend or physical-device pass.
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'startup': 'actual app fail-closed without backend configuration',
      'storage': 'native isolated write, read and removal',
      'biometric': 'capability query only; no authentication',
      'physical_device': 'not established',
    };
  });
}
