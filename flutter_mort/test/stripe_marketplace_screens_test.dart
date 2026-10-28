import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/legal_contract_repository.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/stripe_marketplace_repository.dart';
import 'package:flutter_mort/features/legal/contract_payment_screens.dart';
import 'package:flutter_mort/features/payments/stripe_marketplace_screens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DisabledStripeRepository extends StripeMarketplaceRepository {
  int payoutStatusCalls = 0;
  int fundingPreviewCalls = 0;
  int paymentSummaryCalls = 0;

  @override
  Future<Map<String, dynamic>> runtimeStatus() async => const {
    'mode': 'disabled',
    'connected_onboarding_enabled': false,
    'payments_enabled': false,
    'job_funding_enabled': false,
  };

  @override
  Future<Map<String, dynamic>> payoutStatus() async {
    payoutStatusCalls++;
    throw StateError(
      'Payout details should not load while Stripe is disabled.',
    );
  }

  @override
  Future<Map<String, dynamic>> fundingPreview(String contractId) async {
    fundingPreviewCalls++;
    throw StateError(
      'Funding preview should not load while Stripe is disabled.',
    );
  }

  @override
  Future<Map<String, dynamic>> paymentSummary(String contractId) async {
    paymentSummaryCalls++;
    throw StateError(
      'Payment summary should not load while Stripe is disabled.',
    );
  }
}

class _UnavailablePaymentRecordRepository extends LegalContractRepository {
  int obligationCalls = 0;
  int disputeCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> paymentObligations(
    String contractId,
  ) async {
    obligationCalls++;
    throw StateError('Unavailable obligations must not be queried.');
  }

  @override
  Future<List<Map<String, dynamic>>> paymentDisputes(String contractId) async {
    disputeCalls++;
    throw StateError('Unavailable disputes must not be queried.');
  }
}

void main() {
  testWidgets('disabled payout setup does not query unavailable payout RPCs', (
    tester,
  ) async {
    final repository = _DisabledStripeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stripeMarketplaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: StripePayoutSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payout setup is not available yet'), findsOneWidget);
    expect(find.textContaining('sandbox'), findsNothing);
    expect(repository.payoutStatusCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled job funding skips preview and payment summary RPCs', (
    tester,
  ) async {
    final repository = _DisabledStripeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stripeMarketplaceRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: StripeJobFundingScreen(
            contractId: '00000000-0000-4000-8000-000000000201',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Job funding is currently disabled'), findsOneWidget);
    expect(find.textContaining('sandbox'), findsNothing);
    expect(repository.fundingPreviewCalls, 0);
    expect(repository.paymentSummaryCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled payment status skips unavailable payment tables', (
    tester,
  ) async {
    final stripe = _DisabledStripeRepository();
    final records = _UnavailablePaymentRecordRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stripeMarketplaceRepositoryProvider.overrideWithValue(stripe),
          legalContractRepositoryProvider.overrideWithValue(records),
          currentProfileProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: MortTheme.dark(),
          home: PaymentStatusScreen(
            contractId: '00000000-0000-4000-8000-000000000201',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment tracking is disabled'), findsOneWidget);
    expect(records.obligationCalls, 0);
    expect(records.disputeCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
