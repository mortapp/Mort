enum PremiumSuggestionSurface {
  profile,
  jobFeed,
  applicationSuccess,
  jobCompletion,
  settings,
  progression,
  analytics,
  checkout,
}

enum PremiumSuggestionPresentation { inline, sheet, fullScreen }

class PremiumSuggestion {
  const PremiumSuggestion({
    required this.id,
    required this.surface,
    required this.presentation,
    required this.title,
    required this.message,
    required this.cta,
  });

  final String id;
  final PremiumSuggestionSurface surface;
  final PremiumSuggestionPresentation presentation;
  final String title;
  final String message;
  final String cta;
}

class PremiumSuggestionState {
  const PremiumSuggestionState({
    this.impressions = const <DateTime>[],
    this.dismissedAt,
    this.convertedAt,
  });

  final List<DateTime> impressions;
  final DateTime? dismissedAt;
  final DateTime? convertedAt;
}

abstract interface class PremiumSuggestionStore {
  Future<PremiumSuggestionState> read(String userId, String suggestionId);
  Future<void> write(
    String userId,
    String suggestionId,
    PremiumSuggestionState state,
  );
}

/// Central anti-spam policy for optional premium prompts.
///
/// Explicit visits to the paywall do not use this engine. Subscriber state is
/// supplied by the authoritative RevenueCat view; local state can only suppress
/// a prompt and can never grant an entitlement.
class PremiumSuggestionEngine {
  PremiumSuggestionEngine({required this.store, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final PremiumSuggestionStore store;
  final DateTime Function() _now;

  static const inlineCooldown = Duration(hours: 24);
  static const dismissedInlineCooldown = Duration(days: 7);
  static const dismissedInterruptiveCooldown = Duration(days: 14);
  static const impressionWindow = Duration(days: 7);
  static const maxInlineImpressionsPerWindow = 3;
  static const maxInterruptiveImpressionsPerWindow = 1;

  Future<bool> shouldShow({
    required String userId,
    required PremiumSuggestion suggestion,
    required bool isSubscriber,
    bool isSafetyCriticalSurface = false,
  }) async {
    if (userId.isEmpty || isSubscriber || isSafetyCriticalSurface) return false;
    final state = await store.read(userId, suggestion.id);
    if (state.convertedAt != null) return false;
    final now = _now().toUtc();
    final isInline =
        suggestion.presentation == PremiumSuggestionPresentation.inline;
    final dismissedCooldown = isInline
        ? dismissedInlineCooldown
        : dismissedInterruptiveCooldown;
    if (state.dismissedAt case final dismissed?) {
      if (now.difference(dismissed.toUtc()) < dismissedCooldown) return false;
    }
    final recent = state.impressions
        .where((value) => now.difference(value.toUtc()) < impressionWindow)
        .toList();
    final maximum = isInline
        ? maxInlineImpressionsPerWindow
        : maxInterruptiveImpressionsPerWindow;
    if (recent.length >= maximum) return false;
    if (recent.isNotEmpty &&
        now.difference(recent.last.toUtc()) < inlineCooldown) {
      return false;
    }
    return true;
  }

  Future<void> recordImpression(
    String userId,
    PremiumSuggestion suggestion,
  ) async {
    final state = await store.read(userId, suggestion.id);
    final now = _now().toUtc();
    await store.write(
      userId,
      suggestion.id,
      PremiumSuggestionState(
        impressions: [
          ...state.impressions.where(
            (value) => now.difference(value.toUtc()) < impressionWindow,
          ),
          now,
        ],
        dismissedAt: state.dismissedAt,
        convertedAt: state.convertedAt,
      ),
    );
  }

  Future<void> recordDismissal(
    String userId,
    PremiumSuggestion suggestion,
  ) async {
    final state = await store.read(userId, suggestion.id);
    await store.write(
      userId,
      suggestion.id,
      PremiumSuggestionState(
        impressions: state.impressions,
        dismissedAt: _now().toUtc(),
        convertedAt: state.convertedAt,
      ),
    );
  }

  Future<void> recordConversion(
    String userId,
    PremiumSuggestion suggestion,
  ) async {
    final state = await store.read(userId, suggestion.id);
    await store.write(
      userId,
      suggestion.id,
      PremiumSuggestionState(
        impressions: state.impressions,
        dismissedAt: state.dismissedAt,
        convertedAt: _now().toUtc(),
      ),
    );
  }
}
