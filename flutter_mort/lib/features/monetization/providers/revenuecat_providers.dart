import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/providers.dart';
import '../data/revenuecat_service.dart';
import '../domain/feature_access.dart';

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => RevenueCatService.instance,
);

final revenueCatStatusProvider = FutureProvider<RevenueCatStatus>((ref) async {
  final userId = ref.watch(authRepositoryProvider).currentUser?.id;
  return ref.read(revenueCatServiceProvider).initialize(supabaseUserId: userId);
});

final entitlementStateProvider = FutureProvider<RevenueCatEntitlementState>((
  ref,
) async {
  ref.watch(authRepositoryProvider).currentUser?.id;
  return const RevenueCatEntitlementState(activeEntitlements: <String>{});
});

final featureAccessProvider = FutureProvider<FeatureAccess>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return FeatureAccess.fromEntitlements(entitlements);
});

final isPlusProvider = FutureProvider<bool>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return entitlements.isPlus;
});

final isAdFreeProvider = FutureProvider<bool>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return entitlements.isAdFree;
});

final isAdultProProvider = FutureProvider<bool>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return entitlements.isAdultPro;
});

final isGuardianPlusProvider = FutureProvider<bool>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return entitlements.isGuardianPlus;
});

final backendEntitlementsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(authRepositoryProvider).currentUser?.id;
  return ref.read(monetizationRepositoryProvider).getMyEntitlements();
});

final jobBoostCreditStatusProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(authRepositoryProvider).currentUser?.id;
  return ref.read(monetizationRepositoryProvider).getJobBoostCreditStatus();
});

final usernameChangeStatusProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  ref.watch(authRepositoryProvider).currentUser?.id;
  return ref.read(profileRepositoryProvider).getUsernameChangeStatus();
});

final purchaseControllerProvider = Provider<PurchaseController>((ref) {
  return PurchaseController(ref);
});

class PurchaseController {
  PurchaseController(this._ref);

  final Ref _ref;

  String? get _userId => _ref.read(authRepositoryProvider).currentUser?.id;

  Future<RevenueCatOperationResult> restorePurchases() => _ref
      .read(revenueCatServiceProvider)
      .restorePurchases(supabaseUserId: _userId);

  Future<RevenueCatOperationResult> presentPaywall({
    String? offeringIdentifier,
  }) => _ref
      .read(revenueCatServiceProvider)
      .presentRevenueCatPaywall(
        supabaseUserId: _userId,
        offeringIdentifier: offeringIdentifier,
      );

  Future<RevenueCatOperationResult> presentCustomerCenter() => _ref
      .read(revenueCatServiceProvider)
      .presentCustomerCenter(supabaseUserId: _userId);
}
