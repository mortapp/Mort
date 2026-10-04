import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mort/features/monetization/domain/premium_suggestion.dart';
import 'package:flutter_mort/features/monetization/providers/premium_suggestion_providers.dart';
import 'package:flutter_mort/features/monetization/widgets/premium_suggestion_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _eligibilityStreamProvider = StreamProvider<PremiumMarketingEligibility>(
  (_) => const Stream.empty(),
);

class _Store implements PremiumSuggestionStore {
  var writes = 0;
  final users = <String>[];

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
    users.add(userId);
  }
}

class _FailingStore implements PremiumSuggestionStore {
  @override
  Future<PremiumSuggestionState> read(String userId, String suggestionId) =>
      Future.error(StateError('local storage unavailable'));

  @override
  Future<void> write(
    String userId,
    String suggestionId,
    PremiumSuggestionState state,
  ) => Future.error(StateError('local storage unavailable'));
}

const _suggestion = PremiumSuggestion(
  id: 'progression_v1',
  surface: PremiumSuggestionSurface.progression,
  presentation: PremiumSuggestionPresentation.inline,
  title: 'Optional benefit',
  message: 'MORT Pro adds customization.',
  cta: 'Explore MORT Pro',
);

Widget _card({required String userId, bool safetyCritical = false}) =>
    MaterialApp(
      home: Scaffold(
        body: PremiumSuggestionCard(
          userId: userId,
          suggestion: _suggestion,
          isSafetyCriticalSurface: safetyCritical,
        ),
      ),
    );

void main() {
  testWidgets('unknown entitlement fails closed without an impression', (
    tester,
  ) async {
    final store = _Store();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumSuggestionStoreProvider.overrideWithValue(store),
          premiumMarketingEligibilityProvider.overrideWithValue(
            PremiumMarketingEligibility.unknown,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PremiumSuggestionCard(
              userId: 'user-a',
              suggestion: _suggestion,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsNothing);
    expect(store.writes, 0);
  });

  testWidgets('unavailable local prompt storage suppresses the card safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumSuggestionStoreProvider.overrideWithValue(_FailingStore()),
          premiumMarketingEligibilityProvider.overrideWithValue(
            PremiumMarketingEligibility.free,
          ),
        ],
        child: _card(userId: 'user-a'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subscriber transition immediately hides a visible suggestion', (
    tester,
  ) async {
    final store = _Store();
    final controller = StreamController<PremiumMarketingEligibility>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumSuggestionStoreProvider.overrideWithValue(store),
          _eligibilityStreamProvider.overrideWith((_) => controller.stream),
          premiumMarketingEligibilityProvider.overrideWith(
            (ref) =>
                ref.watch(_eligibilityStreamProvider).asData?.value ??
                PremiumMarketingEligibility.unknown,
          ),
        ],
        child: _card(userId: 'user-a'),
      ),
    );
    controller.add(PremiumMarketingEligibility.free);
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsOneWidget);
    final writesAfterClaim = store.writes;
    controller.add(PremiumMarketingEligibility.free);
    await tester.pumpAndSettle();
    expect(store.writes, writesAfterClaim);
    controller.add(PremiumMarketingEligibility.subscriber);
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsNothing);
    expect(store.writes, writesAfterClaim);
  });

  testWidgets('changing account re-evaluates for the new user', (tester) async {
    final store = _Store();
    final controller =
        StreamController<PremiumMarketingEligibility>.broadcast();
    addTearDown(controller.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumSuggestionStoreProvider.overrideWithValue(store),
          _eligibilityStreamProvider.overrideWith((_) => controller.stream),
          premiumMarketingEligibilityProvider.overrideWith(
            (ref) =>
                ref.watch(_eligibilityStreamProvider).asData?.value ??
                PremiumMarketingEligibility.unknown,
          ),
        ],
        child: _card(userId: 'user-a'),
      ),
    );
    controller.add(PremiumMarketingEligibility.free);
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsOneWidget);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumSuggestionStoreProvider.overrideWithValue(store),
          _eligibilityStreamProvider.overrideWith((_) => controller.stream),
          premiumMarketingEligibilityProvider.overrideWith(
            (ref) =>
                ref.watch(_eligibilityStreamProvider).asData?.value ??
                PremiumMarketingEligibility.unknown,
          ),
        ],
        child: _card(userId: 'user-b'),
      ),
    );
    controller.add(PremiumMarketingEligibility.free);
    await tester.pumpAndSettle();
    expect(store.users, contains('user-b'));
  });

  testWidgets('a safety-critical transition hides an existing suggestion', (
    tester,
  ) async {
    final store = _Store();
    Widget app(bool safetyCritical) => ProviderScope(
      overrides: [
        premiumSuggestionStoreProvider.overrideWithValue(store),
        premiumMarketingEligibilityProvider.overrideWithValue(
          PremiumMarketingEligibility.free,
        ),
      ],
      child: _card(userId: 'user-a', safetyCritical: safetyCritical),
    );
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsOneWidget);

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.text('Optional benefit'), findsNothing);
  });
}
