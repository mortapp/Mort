import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
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

  test('MORT Pro and legacy Plus both grant only optional perks', () {
    for (final id in [
      AppConfig.revenueCatEntitlementPro,
      AppConfig.revenueCatEntitlementPlus,
    ]) {
      final state = RevenueCatEntitlementState(activeEntitlements: {id});
      final access = FeatureAccess.fromEntitlements(state);
      expect(state.isPro, isTrue);
      expect(state.isAdFree, isTrue);
      expect(access.canUsePremiumThemes, isTrue);
      expect(access.safetyToolsFree, isTrue);
    }
    const free = RevenueCatEntitlementState(activeEntitlements: {});
    expect(free.isPro, isFalse);
    expect(free.isAdFree, isFalse);
  });

  test(
    'RevenueCat Test Store key can only be selected in native development',
    () {
      String choose({
        required TargetPlatform platform,
        required bool release,
        bool web = false,
        bool enabled = true,
      }) => AppConfig.selectRevenueCatKey(
        enabled: enabled,
        isWeb: web,
        platform: platform,
        isDevelopment: true,
        isReleaseBinary: release,
        testKey: 'test_example',
        androidKey: 'goog_android-example',
        iosKey: 'appl_ios-example',
      );

      expect(
        choose(platform: TargetPlatform.android, release: false),
        'test_example',
      );
      expect(
        choose(platform: TargetPlatform.iOS, release: false),
        'test_example',
      );
      expect(
        choose(platform: TargetPlatform.android, release: true),
        'goog_android-example',
      );
      expect(
        choose(platform: TargetPlatform.iOS, release: true),
        'appl_ios-example',
      );
      expect(
        choose(platform: TargetPlatform.android, release: false, web: true),
        isEmpty,
      );
      expect(choose(platform: TargetPlatform.windows, release: false), isEmpty);
      expect(
        choose(
          platform: TargetPlatform.android,
          release: false,
          enabled: false,
        ),
        isEmpty,
      );
    },
  );

  test('Test Store and Google Play validate their own four products', () {
    expect(RevenueCatService.expectedProductIds(testStore: true), {
      r'$rc_weekly': 'weekly',
      r'$rc_monthly': 'monthly',
      r'$rc_annual': 'yearly',
      r'$rc_lifetime': 'lifetime',
    });
    expect(RevenueCatService.expectedProductIds(testStore: false), {
      r'$rc_weekly': 'mort_pro:weekly',
      r'$rc_monthly': 'mort_pro:monthly',
      r'$rc_annual': 'mort_pro:annual',
      r'$rc_lifetime': 'lifetime',
    });
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
