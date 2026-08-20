import 'dart:io';

import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Google Play Billing is absent from the free pilot binary', () {
    final pubspec = _read('pubspec.yaml');
    final manifest = _read('android/app/src/main/AndroidManifest.xml');

    expect(AppConfig.nativeBillingCompiledIn, isFalse);
    expect(AppConfig.iapEnabled, isFalse);
    expect(AppConfig.supportsNativePurchases, isFalse);
    expect(pubspec, isNot(contains('in_app_purchase:')));
    expect(pubspec, isNot(contains('in_app_purchase_android:')));
    expect(manifest, isNot(contains('com.android.vending.BILLING')));
    expect(
      File(
        'lib/features/monetization/data/google_play_billing.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('legacy purchase routes explain the real disabled state', () {
    final screen = _read(
      'lib/features/monetization/screens/google_play_billing_screens.dart',
    );
    expect(screen, contains('Purchases are not offered'));
    expect(screen, contains('does not include Google Play Billing'));
    expect(screen, contains('Safety Ping'));
    expect(screen, isNot(contains('ProductDetails')));
  });

  test(
    'ads ship for real, non-personalized-only, while IAP stays excluded',
    () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      final config = _read('lib/core/config/app_config.dart');
      expect(config, contains('static const nativeAdsCompiledIn = true'));
      expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
      expect(manifest, contains('tools:node="remove"'));
    },
  );
}
