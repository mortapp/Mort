import 'dart:async';

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
  Future<void> _queue = Future<void>.value();

  static const _globalInlineId = '__global_inline__';
  static const _globalInterruptiveId = '__global_interruptive__';

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
  }) => _shouldShow(
    userId: userId,
    suggestion: suggestion,
    isSubscriber: isSubscriber,
    isSafetyCriticalSurface: isSafetyCriticalSurface,
  );

  Future<bool> _shouldShow({
    required String userId,
    required PremiumSuggestion suggestion,
    required bool isSubscriber,
    required bool isSafetyCriticalSurface,
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
    final global = await store.read(
      userId,
      isInline ? _globalInlineId : _globalInterruptiveId,
    );
    final globalRecent = global.impressions
        .where((value) => now.difference(value.toUtc()) < impressionWindow)
        .toList();
    if (globalRecent.length >= maximum) return false;
    if (globalRecent.isNotEmpty &&
        now.difference(globalRecent.last.toUtc()) < inlineCooldown) {
      return false;
    }
    return true;
  }

  /// Atomically checks and reserves an impression across all suggestion IDs
  /// handled by this engine instance.
  Future<bool> claimImpression({
    required String userId,
    required PremiumSuggestion suggestion,
    required bool isSubscriber,
    bool isSafetyCriticalSurface = false,
  }) => _serialized(() async {
    final eligible = await _shouldShow(
      userId: userId,
      suggestion: suggestion,
      isSubscriber: isSubscriber,
      isSafetyCriticalSurface: isSafetyCriticalSurface,
    );
    if (!eligible) return false;
    await _recordImpression(userId, suggestion);
    return true;
  });

  Future<void> recordImpression(String userId, PremiumSuggestion suggestion) =>
      _serialized(() => _recordImpression(userId, suggestion));

  Future<void> _recordImpression(
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
    final isInline =
        suggestion.presentation == PremiumSuggestionPresentation.inline;
    final globalId = isInline ? _globalInlineId : _globalInterruptiveId;
    final global = await store.read(userId, globalId);
    await store.write(
      userId,
      globalId,
      PremiumSuggestionState(
        impressions: [
          ...global.impressions.where(
            (value) => now.difference(value.toUtc()) < impressionWindow,
          ),
          now,
        ],
      ),
    );
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
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
