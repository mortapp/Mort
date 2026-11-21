import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/data/services/secure_device_storage.dart';
import 'package:flutter_mort/services/device_authentication_service.dart';
import 'package:flutter_mort/services/native_permissions_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS native build has expected bundle and callback routes', (
    tester,
  ) async {
    expect(defaultTargetPlatform, TargetPlatform.iOS);
    final package = await PackageInfo.fromPlatform();
    expect(package.packageName, 'com.mortapp.mobile');
    expect(
      AppConfig.resolvedAuthRedirectUrl,
      'com.mortapp.mobile://app/auth-callback',
    );
    expect(
      AppConfig.resolvedPasswordRecoveryRedirectUrl,
      'com.mortapp.mobile://app/auth-recovery',
    );
  });

  testWidgets('iOS native storage and permissions plugins are available', (
    tester,
  ) async {
    expect(defaultTargetPlatform, TargetPlatform.iOS);
    const key = 'mort.integration.ios.secure_storage';
    try {
      await mortSecureDeviceStorage.write(key: key, value: 'round-trip');
      expect(await mortSecureDeviceStorage.read(key: key), 'round-trip');
    } finally {
      await mortSecureDeviceStorage.delete(key: key);
    }
    expect(await mortSecureDeviceStorage.read(key: key), isNull);

    final capability = await DeviceAuthenticationService().capability();
    expect(capability.label, isNotEmpty);

    final permissions = await const NativePermissionsService().snapshot();
    expect(permissions.photoPickerNeedsBroadPermission, isTrue);
  });
}
