import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mort/features/mort_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

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

  testWidgets(
    'Android onboarding safety acknowledgements remain usable at large text',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.android);
      final package = await PackageInfo.fromPlatform();
      expect(package.packageName, 'com.mortapp.mobile');
      expect(package.version, '0.9.13');
      expect(package.buildNumber, '103');

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: SafetyRulesScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review the closed-pilot rules'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(5));
      final finishButton = find.widgetWithText(
        ElevatedButton,
        'Save acknowledgments and review',
      );
      expect(finishButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(finishButton).onPressed, isNull);

      for (final checkbox in find.byType(CheckboxListTile).evaluate()) {
        await tester.ensureVisible(find.byWidget(checkbox.widget));
        await tester.tap(find.byWidget(checkbox.widget));
        await tester.pump();
      }

      await tester.ensureVisible(finishButton);
      expect(tester.widget<ElevatedButton>(finishButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
