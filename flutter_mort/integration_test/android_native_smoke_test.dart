import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_mort/data/services/secure_device_storage.dart';
import 'package:flutter_mort/services/device_authentication_service.dart';
import 'package:flutter_mort/services/native_permissions_service.dart';
import 'package:flutter_mort/services/screen_security_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android native services initialize without plugin errors', (
    tester,
  ) async {
    expect(defaultTargetPlatform, TargetPlatform.android);

    const testKey = 'mort.integration.secure_storage';
    await mortSecureDeviceStorage.write(key: testKey, value: 'round-trip');
    expect(await mortSecureDeviceStorage.read(key: testKey), 'round-trip');
    await mortSecureDeviceStorage.delete(key: testKey);
    expect(await mortSecureDeviceStorage.read(key: testKey), isNull);

    final capability = await DeviceAuthenticationService().capability();
    expect(capability.label, isNotEmpty);

    final permissions = await const NativePermissionsService().snapshot();
    expect(permissions.photoPickerNeedsBroadPermission, isFalse);

    await ScreenSecurityService.acquire();
    await ScreenSecurityService.release();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Android native smoke OK'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Android native smoke OK'), findsOneWidget);
  });
}
