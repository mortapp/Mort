enum MortBackendPaymentState {
  ready,
  processing,
  requiresAction,
  pending,
  succeeded,
  declined,
  failed,
  cancelled,
  unknown,
  providerUnavailable,
  duplicateBlocked,
}

MortBackendPaymentState parseMortBackendPaymentState(Object? value) =>
    MortBackendPaymentState.values.firstWhere(
      (state) =>
          state.name.replaceAll('_', '').toUpperCase() ==
          value?.toString().replaceAll('_', '').toUpperCase(),
      orElse: () => MortBackendPaymentState.unknown,
    );

class MortFundingQuote {
  const MortFundingQuote({
    required this.quoteId,
    required this.contractId,
    required this.basePayCents,
    required this.serviceFeeCents,
    required this.totalCents,
    required this.currencyCode,
    required this.state,
    required this.expiresAt,
  });

  factory MortFundingQuote.fromJson(Map<String, dynamic> json) {
    return MortFundingQuote(
      quoteId: json['quote_id'] as String,
      contractId: json['contract_id'] as String,
      basePayCents: json['base_pay_cents'] as int,
      serviceFeeCents: json['service_fee_cents'] as int,
      totalCents: json['authoritative_total_cents'] as int,
      currencyCode: json['currency_code'] as String,
      state: json['state']?.toString() ?? 'UNKNOWN',
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  final String quoteId;
  final String contractId;
  final int basePayCents;
  final int serviceFeeCents;
  final int totalCents;
  final String currencyCode;
  final String state;
  final DateTime expiresAt;
}

class MortPaymentIntentInitialization {
  const MortPaymentIntentInitialization({
    required this.tipOrJobId,
    required this.clientSecret,
    required this.publishableKey,
    required this.customerId,
    required this.ephemeralKeySecret,
    required this.state,
  });

  factory MortPaymentIntentInitialization.fromJson(Map<String, dynamic> json) {
    return MortPaymentIntentInitialization(
      tipOrJobId:
          (json['payment_intent_id'] ?? json['provider_payment_intent_id'])
              as String,
      clientSecret: json['payment_intent_client_secret'] as String,
      publishableKey: json['publishable_key'] as String,
      customerId: json['customer_id'] as String,
      ephemeralKeySecret: json['customer_ephemeral_key_secret'] as String?,
      state: parseMortBackendPaymentState(json['normalized_state']),
    );
  }

  final String tipOrJobId;
  final String clientSecret;
  final String publishableKey;
  final String customerId;
  final String? ephemeralKeySecret;
  final MortBackendPaymentState state;
}

class MortFinancialHistoryPage {
  const MortFinancialHistoryPage({
    required this.items,
    required this.nextCursor,
  });

  factory MortFinancialHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return MortFinancialHistoryPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : const [],
      nextCursor: json['next_cursor']?.toString(),
    );
  }

  final List<Map<String, dynamic>> items;
  final String? nextCursor;
}
