import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/premium_suggestion.dart';

class SharedPreferencesPremiumSuggestionStore
    implements PremiumSuggestionStore {
  const SharedPreferencesPremiumSuggestionStore();

  String _key(String userId, String suggestionId) =>
      'mort.premium_suggestion.v1.$userId.$suggestionId';

  @override
  Future<PremiumSuggestionState> read(
    String userId,
    String suggestionId,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(userId, suggestionId));
    if (raw == null) return const PremiumSuggestionState();
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      DateTime? date(String key) => value[key] is String
          ? DateTime.tryParse(value[key] as String)?.toUtc()
          : null;
      return PremiumSuggestionState(
        impressions: (value['impressions'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(DateTime.tryParse)
            .whereType<DateTime>()
            .map((item) => item.toUtc())
            .toList(),
        dismissedAt: date('dismissed_at'),
        convertedAt: date('converted_at'),
      );
    } catch (_) {
      return const PremiumSuggestionState();
    }
  }

  @override
  Future<void> write(
    String userId,
    String suggestionId,
    PremiumSuggestionState state,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(userId, suggestionId),
      jsonEncode({
        'impressions': state.impressions
            .map((value) => value.toUtc().toIso8601String())
            .toList(),
        'dismissed_at': state.dismissedAt?.toUtc().toIso8601String(),
        'converted_at': state.convertedAt?.toUtc().toIso8601String(),
      }),
    );
  }
}
