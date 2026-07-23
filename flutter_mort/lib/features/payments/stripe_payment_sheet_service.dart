import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/mort_error.dart';

class StripePaymentSheetService {
  const StripePaymentSheetService();

  Future<bool> present(Map<String, dynamic> initialization) async {
    if (!AppConfig.supportsStripePaymentSheet ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const MortCodedError(
        'native_payment_sheet_required',
        'Stripe Payment Sheet requires the native Android or iPhone app.',
      );
    }

    final environment = initialization['environment']?.toString();
    final publishableKey = initialization['publishable_key']?.toString() ?? '';
    final paymentIntentSecret =
        initialization['payment_intent_client_secret']?.toString() ?? '';
    final customerId = initialization['customer_id']?.toString() ?? '';
    final ephemeralKey =
        initialization['customer_ephemeral_key_secret']?.toString() ?? '';
    final currency = initialization['currency_code']?.toString() ?? 'USD';
    final keyMatchesMode = environment == 'test'
        ? publishableKey.startsWith('pk_test_')
        : environment == 'live' && publishableKey.startsWith('pk_live_');
    if (!keyMatchesMode ||
        !paymentIntentSecret.startsWith('pi_') ||
        !paymentIntentSecret.contains('_secret_') ||
        !customerId.startsWith('cus_') ||
        !ephemeralKey.startsWith('ek_')) {
      throw const MortCodedError(
        'invalid_payment_sheet_contract',
        'The payment setup was incomplete. Nothing was charged.',
      );
    }

    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: paymentIntentSecret,
        customerId: customerId,
        customerEphemeralKeySecret: ephemeralKey,
        merchantDisplayName: 'MORT',
        style: ThemeMode.dark,
        allowsDelayedPaymentMethods: false,
        returnURL: AppConfig.authRedirectUrl,
        googlePay: defaultTargetPlatform == TargetPlatform.android
            ? PaymentSheetGooglePay(
                merchantCountryCode: 'US',
                currencyCode: currency,
                testEnv: environment == 'test',
              )
            : null,
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) return false;
      throw const MortCodedError(
        'payment_sheet_failed',
        'Payment Sheet did not finish. Check the payment status before retrying.',
      );
    }
  }
}
