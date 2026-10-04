import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/premium_suggestion_store.dart';
import '../domain/premium_suggestion.dart';

final premiumSuggestionStoreProvider = Provider<PremiumSuggestionStore>(
  (_) => const SharedPreferencesPremiumSuggestionStore(),
);

final premiumSuggestionEngineProvider = Provider<PremiumSuggestionEngine>(
  (ref) =>
      PremiumSuggestionEngine(store: ref.watch(premiumSuggestionStoreProvider)),
);
