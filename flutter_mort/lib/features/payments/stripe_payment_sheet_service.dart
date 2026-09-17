import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/errors/mort_error.dart';

class StripePaymentSheetService {
  const StripePaymentSheetService();

  Future<bool> present(Map<String, dynamic> initialization) async {
    final publishableKey = initialization['publishable_key'];
    final clientSecret = initialization['payment_intent_client_secret'];
    final customerId = initialization['customer_id'];
    final ephemeralKey = initialization['customer_ephemeral_key_secret'];
    if (publishableKey is! String ||
        !publishableKey.startsWith('pk_test_') ||
        clientSecret is! String ||
        customerId is! String ||
        ephemeralKey is! String) {
      throw const MortCodedError(
        'stripe_sandbox_configuration_invalid',
        'Secure sandbox payment setup is unavailable. No payment was confirmed.',
      );
    }

    try {
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.applySettings();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'MORT',
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          allowsDelayedPaymentMethods: false,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) return false;
      throw const MortCodedError(
        'stripe_payment_failed',
        'The payment provider did not confirm this payment. No funded status was recorded.',
      );
    }
  }
}
