import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/premium_suggestion_store.dart';
import '../data/revenuecat_service.dart';
import '../domain/premium_suggestion.dart';
import 'revenuecat_providers.dart';

enum PremiumMarketingEligibility { unknown, free, subscriber }

final premiumSuggestionStoreProvider = Provider<PremiumSuggestionStore>(
  (_) => const SharedPreferencesPremiumSuggestionStore(),
);

final premiumSuggestionEngineProvider = Provider<PremiumSuggestionEngine>(
  (ref) =>
      PremiumSuggestionEngine(store: ref.watch(premiumSuggestionStoreProvider)),
);

final premiumMarketingEligibilityProvider =
    Provider<PremiumMarketingEligibility>((ref) {
      final info = ref.watch(customerInfoProvider).asData?.value;
      if (info == null) return PremiumMarketingEligibility.unknown;
      return RevenueCatEntitlementState.fromCustomerInfo(info).isPro
          ? PremiumMarketingEligibility.subscriber
          : PremiumMarketingEligibility.free;
    });
