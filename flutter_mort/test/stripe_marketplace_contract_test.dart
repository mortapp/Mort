import 'dart:io';

import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Stripe SDK is absent and payment sheet fails closed', () {
    expect(AppConfig.nativeStripePaymentSheetCompiledIn, isFalse);
    expect(AppConfig.marketplacePaymentsEnabled, isFalse);
    expect(AppConfig.supportsStripePaymentSheet, isFalse);

    final service = _read(
      'lib/features/payments/stripe_payment_sheet_service.dart',
    );
    expect(service, contains("'marketplace_payments_disabled'"));
    expect(service, isNot(contains('package:flutter_stripe')));
    expect(service, isNot(matches(RegExp(r'pk_(test|live)_[A-Za-z0-9]'))));
    expect(service, isNot(matches(RegExp(r'sk_(test|live)_[A-Za-z0-9]'))));
  });

  test('job funding amount and state remain server owned', () {
    final repository = _read(
      'lib/data/repositories/stripe_marketplace_repository.dart',
    );
    final screen = _read(
      'lib/features/payments/stripe_marketplace_screens.dart',
    );

    expect(repository, contains("'preview_job_funding'"));
    expect(repository, contains("'stripe-create-job-payment-intent'"));
    expect(repository, isNot(contains("'amount_cents':")));
    expect(repository, isNot(contains("from('stripe_job_payment_intents')")));
    expect(screen, contains('waiting for Stripe webhook confirmation'));
    expect(screen, isNot(contains("status': 'funded'")));
  });

  test('Stripe and Google Play billing boundaries stay separate', () {
    final migration = _read(
      '../supabase/migrations/20260722032907_stripe_connect_sandbox_foundation.sql',
    );
    final pubspec = _read('pubspec.yaml');

    expect(
      migration,
      contains("'digital_purchases_provider', 'google_play_billing'"),
    );
    expect(pubspec, isNot(contains('flutter_stripe')));
    expect(pubspec, isNot(contains('google_mobile_ads')));
    expect(pubspec, isNot(contains('purchases_flutter')));
  });

  test('Stripe provider secrets do not appear in mobile sources', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(sources, isNot(matches(RegExp(r'sk_(test|live)_[A-Za-z0-9]+'))));
    expect(sources, isNot(matches(RegExp(r'whsec_[A-Za-z0-9]+'))));
    expect(sources, isNot(contains('STRIPE_SECRET_KEY')));
    expect(sources, isNot(contains('STRIPE_WEBHOOK_SECRET')));
  });
}
