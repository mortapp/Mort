import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../../../data/repositories/providers.dart';
import '../data/revenuecat_service.dart';
import '../domain/feature_access.dart';

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => RevenueCatService.instance,
);

final revenueCatStatusProvider = FutureProvider<RevenueCatStatus>((ref) async {
  ref.watch(authStateProvider);
  final userId = ref.watch(authRepositoryProvider).currentUser?.id;
  return ref.read(revenueCatServiceProvider).initialize(supabaseUserId: userId);
});

final revenueCatInitializationProvider = revenueCatStatusProvider;

final customerInfoProvider = StreamProvider<rc.CustomerInfo?>((ref) async* {
  ref.watch(authStateProvider);
  final userId = ref.watch(authRepositoryProvider).currentUser?.id;
  final service = ref.read(revenueCatServiceProvider);
  if (userId == null) {
    await service.logOut();
    yield null;
  } else {
    yield await service.getCustomerInfo(userId);
  }
  yield* service.customerInfoUpdates;
});

final offeringsProvider = FutureProvider<rc.Offerings?>((ref) async {
  ref.watch(authStateProvider);
  final userId = ref.watch(authRepositoryProvider).currentUser?.id;
  if (userId == null) return null;
  return ref.read(revenueCatServiceProvider).getOfferings(userId);
});

final currentOfferingProvider = FutureProvider<rc.Offering?>(
  (ref) async =>
      RevenueCatService.proOffering(await ref.watch(offeringsProvider.future)),
);

final entitlementStateProvider = FutureProvider<RevenueCatEntitlementState>((
  ref,
) async {
  ref.watch(authStateProvider);
  final userId = ref.watch(authRepositoryProvider).currentUser?.id;
  if (userId == null) {
    return const RevenueCatEntitlementState(activeEntitlements: <String>{});
  }
  final info = await ref.watch(customerInfoProvider.future);
  return info == null
      ? const RevenueCatEntitlementState(activeEntitlements: <String>{})
      : RevenueCatEntitlementState.fromCustomerInfo(info);
});

final featureAccessProvider = FutureProvider<FeatureAccess>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return FeatureAccess.fromEntitlements(entitlements);
});

final isPlusProvider = FutureProvider<bool>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return entitlements.isPlus;
});

final isMortProProvider = FutureProvider<bool>((ref) async {
  final entitlements = await ref.watch(entitlementStateProvider.future);
  return entitlements.isPro;
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
  ref.watch(authStateProvider);
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

  void _refresh() {
    _ref.invalidate(customerInfoProvider);
    _ref.invalidate(entitlementStateProvider);
    _ref.invalidate(offeringsProvider);
    _ref.invalidate(backendEntitlementsProvider);
  }

  Future<RevenueCatOperationResult> restorePurchases() async {
    final result = await _ref
        .read(revenueCatServiceProvider)
        .restorePurchases(supabaseUserId: _userId);
    _refresh();
    return result;
  }

  Future<RevenueCatOperationResult> presentPaywall({
    String? offeringIdentifier,
  }) async {
    final result = await _ref
        .read(revenueCatServiceProvider)
        .presentRevenueCatPaywall(
          supabaseUserId: _userId,
          offeringIdentifier: offeringIdentifier,
        );
    _refresh();
    return result;
  }

  Future<RevenueCatOperationResult> presentCustomerCenter() async {
    final result = await _ref
        .read(revenueCatServiceProvider)
        .presentCustomerCenter(supabaseUserId: _userId);
    _refresh();
    return result;
  }

  Future<RevenueCatOperationResult> purchasePackage(rc.Package package) async {
    final userId = _userId;
    if (userId == null) {
      return const RevenueCatOperationResult(
        success: false,
        message: 'Sign in to view MORT Pro.',
      );
    }
    final result = await _ref
        .read(revenueCatServiceProvider)
        .purchasePackage(userId: userId, package: package);
    _refresh();
    return result;
  }
}
