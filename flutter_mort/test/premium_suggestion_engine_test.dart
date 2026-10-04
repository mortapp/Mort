import 'package:flutter_mort/features/monetization/domain/premium_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements PremiumSuggestionStore {
  final values = <String, PremiumSuggestionState>{};

  String key(String userId, String suggestionId) => '$userId/$suggestionId';

  @override
  Future<PremiumSuggestionState> read(
    String userId,
    String suggestionId,
  ) async =>
      values[key(userId, suggestionId)] ?? const PremiumSuggestionState();

  @override
  Future<void> write(
    String userId,
    String suggestionId,
    PremiumSuggestionState state,
  ) async => values[key(userId, suggestionId)] = state;
}

void main() {
  const inline = PremiumSuggestion(
    id: 'progression_v1',
    surface: PremiumSuggestionSurface.progression,
    presentation: PremiumSuggestionPresentation.inline,
    title: 'Customize your profile',
    message: 'Optional cosmetics are available.',
    cta: 'Explore MORT Pro',
  );
  const sheet = PremiumSuggestion(
    id: 'success_v1',
    surface: PremiumSuggestionSurface.applicationSuccess,
    presentation: PremiumSuggestionPresentation.sheet,
    title: 'Application sent',
    message: 'Explore optional benefits.',
    cta: 'See benefits',
  );

  late _MemoryStore store;
  late DateTime now;
  late PremiumSuggestionEngine engine;

  setUp(() {
    store = _MemoryStore();
    now = DateTime.utc(2026, 10, 3, 12);
    engine = PremiumSuggestionEngine(store: store, now: () => now);
  });

  test('free user sees an eligible contextual suggestion', () async {
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: inline,
        isSubscriber: false,
      ),
      isTrue,
    );
  });

  test(
    'subscriber and safety critical surfaces never receive prompts',
    () async {
      expect(
        await engine.shouldShow(
          userId: 'user-a',
          suggestion: inline,
          isSubscriber: true,
        ),
        isFalse,
      );
      expect(
        await engine.shouldShow(
          userId: 'user-a',
          suggestion: inline,
          isSubscriber: false,
          isSafetyCriticalSurface: true,
        ),
        isFalse,
      );
    },
  );

  test('impression cooldown and weekly cap prevent repeated nagging', () async {
    await engine.recordImpression('user-a', inline);
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: inline,
        isSubscriber: false,
      ),
      isFalse,
    );
    now = now.add(const Duration(days: 1, minutes: 1));
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: inline,
        isSubscriber: false,
      ),
      isTrue,
    );
    await engine.recordImpression('user-a', inline);
    now = now.add(const Duration(days: 1, minutes: 1));
    await engine.recordImpression('user-a', inline);
    now = now.add(const Duration(days: 1, minutes: 1));
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: inline,
        isSubscriber: false,
      ),
      isFalse,
    );
  });

  test('dismissal has longer cooldown and remains account scoped', () async {
    await engine.recordDismissal('user-a', inline);
    now = now.add(const Duration(days: 6));
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: inline,
        isSubscriber: false,
      ),
      isFalse,
    );
    expect(
      await engine.shouldShow(
        userId: 'user-b',
        suggestion: inline,
        isSubscriber: false,
      ),
      isTrue,
    );
    now = now.add(const Duration(days: 2));
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: inline,
        isSubscriber: false,
      ),
      isTrue,
    );
  });

  test(
    'interruptive prompt is capped once per week and 14 days after dismiss',
    () async {
      await engine.recordImpression('user-a', sheet);
      now = now.add(const Duration(days: 2));
      expect(
        await engine.shouldShow(
          userId: 'user-a',
          suggestion: sheet,
          isSubscriber: false,
        ),
        isFalse,
      );
      now = now.add(const Duration(days: 6));
      expect(
        await engine.shouldShow(
          userId: 'user-a',
          suggestion: sheet,
          isSubscriber: false,
        ),
        isTrue,
      );
      await engine.recordDismissal('user-a', sheet);
      now = now.add(const Duration(days: 13));
      expect(
        await engine.shouldShow(
          userId: 'user-a',
          suggestion: sheet,
          isSubscriber: false,
        ),
        isFalse,
      );
    },
  );

  test('conversion permanently suppresses the same suggestion', () async {
    await engine.recordConversion('user-a', inline);
    now = now.add(const Duration(days: 365));
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: inline,
        isSubscriber: false,
      ),
      isFalse,
    );
  });

  test('global caps apply across different suggestion IDs', () async {
    for (var index = 0; index < 3; index++) {
      final suggestion = PremiumSuggestion(
        id: 'inline_$index',
        surface: PremiumSuggestionSurface.values[index],
        presentation: PremiumSuggestionPresentation.inline,
        title: 'Optional benefit',
        message: 'Benefit details',
        cta: 'Explore',
      );
      expect(
        await engine.claimImpression(
          userId: 'user-a',
          suggestion: suggestion,
          isSubscriber: false,
        ),
        isTrue,
      );
      now = now.add(const Duration(days: 1, minutes: 1));
    }
    expect(
      await engine.shouldShow(
        userId: 'user-a',
        suggestion: const PremiumSuggestion(
          id: 'fourth_inline',
          surface: PremiumSuggestionSurface.analytics,
          presentation: PremiumSuggestionPresentation.inline,
          title: 'Another benefit',
          message: 'More details',
          cta: 'Explore',
        ),
        isSubscriber: false,
      ),
      isFalse,
    );
  });

  test(
    'simultaneous interruptive claims reserve only one impression',
    () async {
      final results = await Future.wait([
        engine.claimImpression(
          userId: 'user-a',
          suggestion: sheet,
          isSubscriber: false,
        ),
        engine.claimImpression(
          userId: 'user-a',
          suggestion: const PremiumSuggestion(
            id: 'completion_v1',
            surface: PremiumSuggestionSurface.jobCompletion,
            presentation: PremiumSuggestionPresentation.fullScreen,
            title: 'Job complete',
            message: 'Optional benefits',
            cta: 'Explore',
          ),
          isSubscriber: false,
        ),
      ]);
      expect(results.where((value) => value), hasLength(1));
    },
  );
}
