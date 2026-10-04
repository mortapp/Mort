import 'package:flutter/material.dart';
import 'package:flutter_mort/features/monetization/domain/premium_suggestion.dart';
import 'package:flutter_mort/features/monetization/providers/premium_suggestion_providers.dart';
import 'package:flutter_mort/features/monetization/providers/revenuecat_providers.dart';
import 'package:flutter_mort/features/monetization/widgets/premium_suggestion_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

class _Store implements PremiumSuggestionStore {
  var writes = 0;

  @override
  Future<PremiumSuggestionState> read(
    String userId,
    String suggestionId,
  ) async => const PremiumSuggestionState();

  @override
  Future<void> write(
    String userId,
    String suggestionId,
    PremiumSuggestionState state,
  ) async {
    writes++;
  }
}

void main() {
  testWidgets('unknown RevenueCat state fails closed without an impression', (
    tester,
  ) async {
    final store = _Store();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumSuggestionStoreProvider.overrideWithValue(store),
          customerInfoProvider.overrideWith(
            (_) => Stream<rc.CustomerInfo?>.error(StateError('unavailable')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PremiumSuggestionCard(
              userId: 'user-a',
              suggestion: PremiumSuggestion(
                id: 'progression_v1',
                surface: PremiumSuggestionSurface.progression,
                presentation: PremiumSuggestionPresentation.inline,
                title: 'Optional benefit',
                message: 'MORT Pro adds customization.',
                cta: 'Explore MORT Pro',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsNothing);
    expect(store.writes, 0);
  });
}
