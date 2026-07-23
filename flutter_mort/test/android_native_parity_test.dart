import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final activity = File(
    'android/app/src/main/kotlin/com/mortapp/mobile/MainActivity.kt',
  ).readAsStringSync();
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

  test('Android package and launch activity use the same namespace', () {
    expect(gradle, contains('namespace = "com.mortapp.mobile"'));
    expect(gradle, contains('applicationId = "com.mortapp.mobile"'));
    expect(activity, contains('package com.mortapp.mobile'));
    expect(activity, contains('FlutterFragmentActivity'));
    expect(
      File(
        'android/app/src/main/kotlin/com/mortapp/flutter_mort/MainActivity.kt',
      ).existsSync(),
      isFalse,
    );
  });

  test('Android release permissions are foreground-only and optional', () {
    for (final permission in [
      'android.permission.INTERNET',
      'android.permission.CAMERA',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.USE_BIOMETRIC',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_FINE_LOCATION',
    ]) {
      expect(manifest, contains(permission));
    }
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(manifest, contains('android.hardware.camera.any'));
    expect(
      manifest,
      contains(
        'android.hardware.camera" android:required="false" tools:replace="android:required"',
      ),
    );
    expect(manifest, contains('android:required="false"'));
    expect(
      manifest,
      contains(
        '<uses-permission android:name="com.android.vending.BILLING" />',
      ),
    );
    for (final removedPermission in [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES_AD_ID',
      'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
      'android.permission.ACCESS_ADSERVICES_TOPICS',
      'android.permission.FOREGROUND_SERVICE',
      'android.permission.WAKE_LOCK',
    ]) {
      expect(
        manifest,
        contains('android:name="$removedPermission" tools:node="remove"'),
      );
    }
  });

  test('Android blocks cleartext and protects selected sensitive screens', () {
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, contains('@xml/network_security_config'));
    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
  });

  test('release signing never silently uses the debug key', () {
    expect(gradle, isNot(contains('getByName("debug")')));
    expect(gradle, contains('MORT_UPLOAD_KEYSTORE_PATH'));
    expect(gradle, contains('MORT_UPLOAD_KEY_PASSWORD'));
    expect(
      gradle,
      contains('Debug-signing fallback is intentionally disabled'),
    );
  });

  test('Firebase notification requirements are enabled for release builds', () {
    expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(
      gradle,
      contains(
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
      ),
    );
    expect(gradle, contains('multiDexEnabled = true'));
  });

  test('Android and iOS declare equivalent foreground capabilities', () {
    expect(infoPlist, contains('NSFaceIDUsageDescription'));
    expect(infoPlist, contains('NSLocationWhenInUseUsageDescription'));
    expect(infoPlist, isNot(contains('NSLocationAlwaysUsageDescription')));
    expect(infoPlist, contains('<string>mort</string>'));
    expect(manifest, contains('android:scheme="mort"'));
  });

  test('manual area search remains available when location is denied', () {
    final feed = File(
      'lib/features/jobs/teen_job_screens.dart',
    ).readAsStringSync();
    final permissions = File(
      'lib/services/native_permissions_service.dart',
    ).readAsStringSync();
    expect(
      feed,
      contains('Manual entry works even when location access is denied'),
    );
    expect(feed, contains("city: _city.text.trim().isEmpty"));
    expect(
      permissions,
      contains('Manual city and state search remains available'),
    );
  });
}
