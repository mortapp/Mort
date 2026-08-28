import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter_mort/features/ads/data/admob_service.dart';
import 'package:flutter_mort/features/monetization/data/revenuecat_service.dart';
import 'package:flutter_mort/features/monetization/domain/feature_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all core safety access remains free without entitlements', () {
    const state = RevenueCatEntitlementState(activeEntitlements: {});
    final access = FeatureAccess.fromEntitlements(state);

    expect(access.safetyToolsFree, isTrue);
    expect(access.basicApplyingFree, isTrue);
    expect(access.basicGuardianModeFree, isTrue);
    expect(access.proofUploadFree, isTrue);
    expect(access.reportBlockSafetyPingFree, isTrue);
  });

  test('Plus grants perks without changing safety access', () {
    const state = RevenueCatEntitlementState(
      activeEntitlements: {AppConfig.revenueCatEntitlementPlus},
    );
    final access = FeatureAccess.fromEntitlements(state);

    expect(access.canUsePlus, isTrue);
    expect(access.canUsePremiumThemes, isTrue);
    expect(access.canUseAdvancedFilters, isTrue);
    expect(access.safetyToolsFree, isTrue);
  });

  test('sensitive placements always block banner and rewarded ads', () {
    const service = AdMobService();
    for (final placement in AdMobService.sensitivePlacements) {
      expect(service.bannerDecision(placement: placement).canShow, isFalse);
      expect(service.rewardedDecision(placement: placement).canShow, isFalse);
    }
  });

  test('RevenueCat is guarded off on unsupported test platform', () {
    final status = RevenueCatService.instance.status(supabaseUserId: 'user-id');
    expect(status.available, isFalse);
  });
}
