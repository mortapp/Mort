import 'dart:io';

import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/features/monetization/data/google_play_billing.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Google Play catalog and native boundary are explicit', () {
    expect(AppConfig.nativeBillingCompiledIn, isTrue);
    expect(AppConfig.iapEnabled, isFalse);
    expect(AppConfig.supportsNativePurchases, isFalse);
    expect(mortGooglePlayProductIds, {
      'mort_plus',
      'mort_theme_neon_pack',
      'mort_theme_midnight_pack',
      'mort_profile_frames_pack_01',
      'mort_portfolio_layouts_pack_01',
    });
  });

  test(
    'purchases are verified by Edge before completion or entitlement refresh',
    () {
      final billing = _read(
        'lib/features/monetization/data/google_play_billing.dart',
      );
      final edge = _read(
        '../supabase/functions/google-play-verify-purchase/index.ts',
      );
      final migration = _read(
        '../supabase/migrations/20260722043000_google_play_billing_foundation.sql',
      );

      expect(billing, contains("'google-play-verify-purchase'"));
      expect(
        billing.indexOf('_verification.verify(purchase)'),
        lessThan(billing.indexOf('_billing.complete(purchase)')),
      );
      expect(edge, contains('verifyWithGoogle'));
      expect(edge, contains('purchase.obfuscatedAccountId'));
      expect(migration, contains("default 'license_test'"));
      expect(
        migration,
        contains('billing_enabled boolean not null default false'),
      );
      expect(migration, contains('token_hash text not null unique'));
      expect(migration, contains('grant_play_review_entitlement'));
      expect(migration, contains('play_review_test_account_required'));
      expect(migration, contains('force row level security'));
    },
  );

  test('paywall uses localized Play prices and preserves free core', () {
    final screen = _read(
      'lib/features/monetization/screens/google_play_billing_screens.dart',
    );
    expect(screen, contains('product.price'));
    expect(screen, contains('billingPeriod'));
    expect(screen, contains('Core app, jobs, and safety remain free'));
    expect(screen, contains('renew automatically until canceled'));
    expect(screen, isNot(contains(r'\$1.99')));
    expect(screen, contains('No free trial is promised'));
  });

  test('ads remain disabled and advertising identifiers remain stripped', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final config = _read('lib/core/config/app_config.dart');
    expect(config, contains('static const nativeAdsCompiledIn = false'));
    expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
    expect(manifest, contains('tools:node="remove"'));
  });
}
