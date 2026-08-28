import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/mort_error.dart';
import 'repository_base.dart';

class StripeMarketplaceRepository extends RepositoryBase {
  static const _uuid = Uuid();
  static const savedPaymentConsentVersion = 'saved-payment-consent-v1';
  static const savedPaymentConsentText =
      'Save this payment method for faster funding of future MORT jobs that I choose to confirm. MORT will not create a new job charge only because a reviewer approved evidence.';

  Future<Map<String, dynamic>> runtimeStatus() async {
    requireUserId();
    return _map(await client.rpc('get_stripe_runtime_status'));
  }

  Future<Map<String, dynamic>> payoutStatus() async {
    requireUserId();
    return _map(await client.rpc('get_my_stripe_payout_status'));
  }

  Future<Map<String, dynamic>> fundingPreview(String contractId) async {
    requireUserId();
    return _map(
      await client.rpc(
        'preview_job_funding',
        params: {'p_contract_id': contractId},
      ),
    );
  }

  Future<Map<String, dynamic>> paymentSummary(String contractId) async {
    requireUserId();
    return _map(
      await client.rpc(
        'get_job_payment_summary',
        params: {'p_contract_id': contractId},
      ),
    );
  }

  Future<Map<String, dynamic>> paymentOperationsQueue() async {
    requireUserId();
    return _map(await client.rpc('get_my_payment_operations_queue'));
  }

  Future<Map<String, dynamic>> reviewPaymentDispute({
    required String disputeId,
    required String decisionType,
    required String rationale,
    int? recommendedAmountCents,
  }) async {
    requireUserId();
    final result = _map(
      await client.rpc(
        'review_payment_dispute',
        params: {
          'p_dispute_id': disputeId,
          'p_decision_type': decisionType,
          'p_rationale': rationale,
          'p_recommended_amount_cents': recommendedAmountCents,
          'p_restrict_poster': false,
          'p_restriction_type': 'block_new_job_publication',
          'p_restriction_expires_at': null,
        },
      ),
    );
    if (result['ok'] != true) {
      final code = result['code']?.toString() ?? 'payment_review_failed';
      throw MortCodedError(code, _messageFor(code));
    }
    return result;
  }

  Future<Map<String, dynamic>> prepareDisputeResolution(String disputeId) =>
      _invoke(
        'stripe-resolve-job-payment',
        body: {
          'action': 'prepare_dispute',
          'dispute_id': disputeId,
          'request_id': _uuid.v4(),
        },
      );

  Future<Map<String, dynamic>> executePreparedResolution(String resolutionId) =>
      _invoke(
        'stripe-resolve-job-payment',
        body: {
          'action': 'execute',
          'resolution_id': resolutionId,
          'request_id': _uuid.v4(),
        },
      );

  Future<Map<String, dynamic>> createConnectedAccount() {
    return _invoke('stripe-create-connected-account');
  }

  Future<Map<String, dynamic>> createOnboardingLink({
    required String returnUrl,
    required String refreshUrl,
  }) {
    return _invoke(
      'stripe-create-onboarding-link',
      body: {'return_url': returnUrl, 'refresh_url': refreshUrl},
    );
  }

  Future<Map<String, dynamic>> synchronizePayoutStatus() {
    return _invoke('stripe-get-connected-account-status');
  }

  Future<Map<String, dynamic>> createPaymentSheet({
    required String contractId,
    required bool savePaymentMethod,
    String? savedPaymentConsentVersion,
  }) {
    return _invoke(
      'stripe-create-job-payment-intent',
      body: {
        'contract_id': contractId,
        'operation_version': 1,
        'request_id': _uuid.v4(),
        'save_payment_method': savePaymentMethod,
        if (savePaymentMethod)
          'saved_payment_consent_version': savedPaymentConsentVersion,
      },
    );
  }

  Future<Map<String, dynamic>> recordSavedPaymentConsent(
    String contractId,
  ) async {
    requireUserId();
    final result = _map(
      await client.rpc(
        'record_my_saved_payment_consent',
        params: {
          'p_contract_id': contractId,
          'p_consent_version': savedPaymentConsentVersion,
          'p_consent_text': savedPaymentConsentText,
        },
      ),
    );
    if (result['ok'] != true) {
      throw const MortCodedError(
        'explicit_saved_payment_consent_required',
        'Payment method saving requires explicit consent.',
      );
    }
    return result;
  }

  Future<Map<String, dynamic>> revokeSavedPaymentConsent(
    String contractId,
  ) async {
    requireUserId();
    return _map(
      await client.rpc(
        'revoke_my_saved_payment_consent',
        params: {
          'p_contract_id': contractId,
          'p_consent_version': savedPaymentConsentVersion,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _invoke(
    String name, {
    Map<String, dynamic>? body,
  }) async {
    requireUserId();
    try {
      final response = await client.functions.invoke(name, body: body ?? {});
      final data = _map(response.data);
      if (data['ok'] != true) {
        final code = data['code']?.toString() ?? 'stripe_operation_failed';
        throw MortCodedError(code, _messageFor(code));
      }
      return data;
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : 'stripe_operation_failed';
      throw MortCodedError(code, _messageFor(code));
    }
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const MortCodedError(
      'invalid_stripe_response',
      'The payment service returned an invalid response. Nothing was charged.',
    );
  }

  String _messageFor(String code) => switch (code) {
    'stripe_disabled' ||
    'stripe_server_not_configured' ||
    'stripe_job_funding_disabled' ||
    'stripe_connected_onboarding_disabled' =>
      'Stripe sandbox setup is not enabled yet. No payment or payout account was created.',
    'sandbox_test_account_required' || 'sandbox_test_contract_required' =>
      'This sandbox action is limited to isolated MORT test accounts.',
    'rate_limit_exceeded' =>
      'Too many payment attempts were made. Wait before trying again.',
    'active_contract_required' || 'fundable_obligation_required' =>
      'The accepted job agreement is not ready for funding.',
    'connected_account_required' =>
      'Create the Stripe payout account before opening onboarding.',
    'assigned_ready_reviewer_required' ||
    'payment_reviewer_role_required' ||
    'payment_operations_role_required' =>
      'This action requires a current, separately assigned payment-review role.',
    'reviewer_financial_operator_separation_required' =>
      'A different authorized payment operator must execute this reviewed resolution.',
    'stripe_transfers_disabled' || 'stripe_refunds_disabled' =>
      'Stripe test-mode transfer or refund execution is disabled at the server.',
    _ =>
      'The Stripe sandbox action could not be completed. Nothing was charged.',
  };
}
