import 'dart:io';

import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('RevenueCat native billing is present but disabled by default', () {
    final pubspec = _read('pubspec.yaml');

    expect(AppConfig.nativeBillingCompiledIn, isTrue);
    expect(AppConfig.iapEnabled, isFalse);
    expect(AppConfig.supportsNativePurchases, isFalse);
    expect(pubspec, isNot(contains('in_app_purchase:')));
    expect(pubspec, isNot(contains('in_app_purchase_android:')));
    expect(pubspec, contains('purchases_flutter:'));
    expect(pubspec, contains('purchases_ui_flutter:'));
    expect(
      File(
        'lib/features/monetization/data/google_play_billing.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('purchase routes use MORT Pro while keeping core safety free', () {
    final screen = _read(
      'lib/features/monetization/screens/google_play_billing_screens.dart',
    );
    expect(screen, contains('MORT Pro'));
    expect(screen, contains('RevenueCatPaywallScreen'));
    expect(screen, contains('Restore purchases'));
    expect(screen, isNot(contains('ProductDetails')));
  });

  test('ads and billing are native but independently gated', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final config = _read('lib/core/config/app_config.dart');
    expect(config, contains('static const nativeAdsCompiledIn = true'));
    expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
    expect(manifest, contains('tools:node="remove"'));
  });

  test(
    'Play catalog uses the active annual base plan and RevenueCat scheme',
    () {
      final catalog = _read('../scripts/revenuecat-common.mjs');
      final service = _read(
        'lib/features/monetization/data/revenuecat_service.dart',
      );
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      for (final product in [
        'mort_pro:weekly',
        'mort_pro:monthly',
        'mort_pro:annual',
        'lifetime',
      ]) {
        expect(catalog, contains('"$product"'));
      }
      expect(catalog, isNot(contains('mort_pro:yearly')));
      expect(service, contains("r'\$rc_annual': 'mort_pro:annual'"));
      expect(service, contains("getOffering('default')"));
      expect(manifest, contains('android:scheme="rc-8eaa6ee77f"'));
      expect(manifest, contains('android:scheme="com.mortapp.mobile"'));
      expect(manifest, contains('com.amazon.device.iap.ResponseReceiver'));
      expect(
        manifest,
        matches(
          RegExp(
            r'com\.amazon\.device\.iap\.ResponseReceiver"\s+tools:node="remove"',
          ),
        ),
      );
      final releaseBuild = _read(
        '../scripts/android-release-profile-common.ps1',
      );
      expect(releaseBuild, contains('MORT_ENABLE_PLAY_BILLING'));
      expect(releaseBuild, contains(r'^goog_[A-Za-z0-9]+$'));
      expect(releaseBuild, contains('REVENUECAT_ANDROID_API_KEY'));
    },
  );
}
