import 'dart:io';

import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String relativePath) => File(relativePath).readAsStringSync();

void main() {
  test('release modes are explicit and public mode is not the default', () {
    expect(
      AppConfig.supportedReleaseStages,
      equals({
        'development',
        'internal_test',
        'closed_test',
        'production_pilot',
        'production_public',
      }),
    );
    expect(AppConfig.publicMarketplaceEnabled, isFalse);
    expect(AppConfig.identityVerificationEnabled, isFalse);
  });

  test('native ads, billing, and Stripe SDKs stay excluded', () {
    final pubspec = _read('pubspec.yaml');
    final pluginRegistry = _read(
      'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java',
    );

    for (final dependency in [
      'google_mobile_ads',
      'purchases_flutter',
      'purchases_ui_flutter',
      'flutter_stripe',
    ]) {
      expect(pubspec, isNot(contains(dependency)));
      expect(pluginRegistry, isNot(contains(dependency)));
    }
    expect(AppConfig.nativeAdsCompiledIn, isFalse);
    expect(AppConfig.nativeBillingCompiledIn, isFalse);
    expect(AppConfig.supportsNativeAds, isFalse);
    expect(AppConfig.supportsNativePurchases, isFalse);
    expect(pubspec, isNot(contains('in_app_purchase:')));
    expect(AppConfig.nativeStripePaymentSheetCompiledIn, isFalse);
    expect(AppConfig.supportsStripePaymentSheet, isFalse);
  });

  test('version source is valid and greater than the previous Play build', () {
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(_read('pubspec.yaml'));
    expect(match, isNotNull);
    expect(int.parse(match!.group(2)!), greaterThanOrEqualTo(98));
  });

  test(
    'partner routes are mapped and no developer coming-soon route remains',
    () {
      final router = _read('lib/core/routing/app_router.dart');
      expect(router, contains("'/partner/home'"));
      expect(router, contains("'/partner/participants/:organizationId'"));
      expect(router, contains("'/partner/invites/:organizationId'"));
      expect(router, isNot(contains('Coming Later')));
      expect(router, isNot(contains('additive backend expansion')));
    },
  );

  test('Android manifest removes Billing and explicitly strips ad IDs', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, isNot(contains('com.android.vending.BILLING')));
    for (final permission in [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES_AD_ID',
    ]) {
      final declaration = RegExp(
        '<uses-permission[^>]*android:name="$permission"[^>]*tools:node="remove"',
      );
      expect(manifest, matches(declaration));
    }
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
  });

  test('review fixtures and ordinary jobs remain separated in the feed', () {
    final repository = _read('lib/data/repositories/jobs_repository.dart');
    final feed = _read('lib/features/jobs/teen_job_screens.dart');

    expect(repository, contains("'list_open_jobs_page'"));
    expect(repository, isNot(contains(".from('jobs').select(_jobSelect)")));
    expect(feed, isNot(contains('Test and QA jobs')));
  });

  test('agreement screens show readable labels instead of internal hashes', () {
    final screen = _read('lib/features/legal/contract_payment_screens.dart');
    final repository = _read(
      'lib/data/repositories/legal_contract_repository.dart',
    );

    expect(screen, isNot(contains('SHA-256:')));
    expect(screen, contains('_contractTitle(contract)'));
    expect(repository, contains('jobs:job_id(title)'));
  });

  test('store-facing jobs do not expose fixture implementation labels', () {
    final model = _read('lib/data/models/job.dart');

    expect(model, contains('Approved pilot participant'));
    expect(model, isNot(contains('Sandbox test account')));
  });

  test('saved jobs use the owner-scoped server contract', () {
    final repository = _read('lib/data/repositories/jobs_repository.dart');

    expect(repository, contains("rpc('list_my_saved_jobs')"));
    expect(
      repository,
      isNot(contains(".select(\n          'created_at, jobs(*")),
    );
  });
}
