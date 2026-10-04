import 'package:flutter_mort/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_mort/features/ads/data/admob_service.dart';
import 'package:flutter_mort/features/monetization/data/revenuecat_service.dart';
import 'package:flutter_mort/features/monetization/domain/feature_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

rc.CustomerInfo customerWith({
  required String entitlement,
  required String product,
  bool active = true,
  bool renews = true,
  String? expiration,
  String? billingIssue,
}) {
  final item = rc.EntitlementInfo(
    entitlement,
    active,
    renews,
    '2026-10-01T00:00:00Z',
    '2026-10-01T00:00:00Z',
    product,
    true,
    store: rc.Store.playStore,
    expirationDate: expiration,
    billingIssueDetectedAt: billingIssue,
  );
  return rc.CustomerInfo(
    rc.EntitlementInfos({entitlement: item}, active ? {entitlement: item} : {}),
    const {},
    active ? [product] : const [],
    [product],
    const [],
    '2026-10-01T00:00:00Z',
    'user-id',
    const {},
    '2026-10-04T00:00:00Z',
  );
}

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

  test('Free, Plus, and Pro remain separate while Pro inherits Plus', () {
    const free = RevenueCatEntitlementState(activeEntitlements: {});
    const plus = RevenueCatEntitlementState(
      activeEntitlements: {AppConfig.revenueCatEntitlementPlus},
    );
    const pro = RevenueCatEntitlementState(
      activeEntitlements: {AppConfig.revenueCatEntitlementPro},
    );
    expect(free.isFree, isTrue);
    expect(free.hasPlusOrHigher, isFalse);
    expect(free.isPro, isFalse);
    expect(free.isAdFree, isFalse);
    expect(plus.tier, MortSubscriptionTier.plus);
    expect(plus.hasPlusOrHigher, isTrue);
    expect(plus.hasPro, isFalse);
    expect(plus.hasProfileStylePack, isFalse);
    expect(FeatureAccess.fromEntitlements(plus).canUsePremiumThemes, isTrue);
    expect(pro.tier, MortSubscriptionTier.pro);
    expect(pro.isPlus, isFalse);
    expect(pro.hasPlusOrHigher, isTrue);
    expect(pro.hasProfileStylePack, isTrue);
    expect(FeatureAccess.fromEntitlements(pro).canUsePremiumThemes, isTrue);
  });

  test('unknown entitlement cannot promote an account', () {
    const state = RevenueCatEntitlementState(
      activeEntitlements: {'unknown_premium'},
    );
    expect(state.tier, MortSubscriptionTier.free);
    expect(state.hasPlusOrHigher, isFalse);
    expect(state.hasPro, isFalse);
  });

  test('historical Plus products retain their prior Pro-equivalent access', () {
    for (final product
        in RevenueCatEntitlementState.legacyProEquivalentPlusProducts) {
      final state = RevenueCatEntitlementState(
        activeEntitlements: const {AppConfig.revenueCatEntitlementPlus},
        activeProducts: {product},
      );
      expect(state.tier, MortSubscriptionTier.pro);
    }
    const newPlus = RevenueCatEntitlementState(
      activeEntitlements: {AppConfig.revenueCatEntitlementPlus},
      activeProducts: {'distinct_future_plus_product'},
    );
    expect(newPlus.tier, MortSubscriptionTier.plus);
    const staleProductOnly = RevenueCatEntitlementState(
      activeEntitlements: {},
      activeProducts: {'mort_plus_lifetime'},
    );
    expect(staleProductOnly.tier, MortSubscriptionTier.free);
  });

  test(
    'RevenueCat active metadata distinguishes cancellation and billing issue',
    () {
      final cancelled = RevenueCatEntitlementState.fromCustomerInfo(
        customerWith(
          entitlement: AppConfig.revenueCatEntitlementPro,
          product: 'mort_pro:annual',
          renews: false,
          expiration: '2027-10-01T00:00:00Z',
        ),
      );
      expect(cancelled.tier, MortSubscriptionTier.pro);
      expect(
        cancelled.subscriptionState,
        MortSubscriptionState.cancelledActive,
      );
      expect(cancelled.expiration, DateTime.utc(2027, 10, 1));
      expect(cancelled.productIdentifier, 'mort_pro:annual');
      expect(cancelled.store, rc.Store.playStore);

      final issue = RevenueCatEntitlementState.fromCustomerInfo(
        customerWith(
          entitlement: AppConfig.revenueCatEntitlementPlus,
          product: 'new_plus_monthly',
          billingIssue: '2026-10-03T00:00:00Z',
        ),
      );
      expect(issue.tier, MortSubscriptionTier.plus);
      expect(issue.subscriptionState, MortSubscriptionState.billingIssueActive);
      expect(issue.gracePeriod, isNull);

      final expired = RevenueCatEntitlementState.fromCustomerInfo(
        customerWith(
          entitlement: AppConfig.revenueCatEntitlementPro,
          product: 'mort_pro:monthly',
          active: false,
        ),
      );
      expect(expired.tier, MortSubscriptionTier.free);
      expect(expired.subscriptionState, MortSubscriptionState.inactive);
    },
  );

  test(
    'historical SKU is grandfathered only with an active Plus entitlement',
    () {
      final legacy = RevenueCatEntitlementState.fromCustomerInfo(
        customerWith(
          entitlement: AppConfig.revenueCatEntitlementPlus,
          product: 'mort_plus_lifetime',
          renews: false,
        ),
      );
      expect(legacy.tier, MortSubscriptionTier.pro);
      final revoked = RevenueCatEntitlementState.fromCustomerInfo(
        customerWith(
          entitlement: AppConfig.revenueCatEntitlementPlus,
          product: 'mort_plus_lifetime',
          active: false,
        ),
      );
      expect(revoked.tier, MortSubscriptionTier.free);
    },
  );

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
