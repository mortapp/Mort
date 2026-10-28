import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_theme.dart';
import 'package:flutter_mort/data/repositories/providers.dart';
import 'package:flutter_mort/data/repositories/stripe_marketplace_repository.dart';
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
}
