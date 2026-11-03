import '../../core/errors/mort_error.dart';

class StripePaymentSheetService {
  const StripePaymentSheetService();

  Future<bool> present(Map<String, dynamic> initialization) async {
    throw const MortCodedError(
      'marketplace_payments_disabled',
      'MORT does not process job payments in this release.',
    );
  }
}
