import '../../../core/config/app_config.dart';

class RevenueCatStatus {
  const RevenueCatStatus({
    required this.available,
    required this.message,
    this.entitlements = const <String>[],
  });

  final bool available;
  final String message;
  final List<String> entitlements;
}

class RevenueCatOperationResult {
  const RevenueCatOperationResult({
    required this.success,
    required this.message,
    this.cancelled = false,
  });

  final bool success;
  final bool cancelled;
  final String message;
}

class RevenueCatEntitlementState {
  const RevenueCatEntitlementState({required this.activeEntitlements});

  final Set<String> activeEntitlements;

  bool has(String entitlementId) => activeEntitlements.contains(entitlementId);

  bool get isPlus => has(AppConfig.revenueCatEntitlementPlus);
  bool get isAdFree => has(AppConfig.revenueCatEntitlementAdFree) || isPlus;
  bool get isAdultPro => has(AppConfig.revenueCatEntitlementAdultPro);
  bool get isGuardianPlus => has(AppConfig.revenueCatEntitlementGuardianPlus);
  bool get hasUsernameToken =>
      has(AppConfig.revenueCatEntitlementUsernameToken);
  bool get hasJobBoost => has(AppConfig.revenueCatEntitlementJobBoost);
  bool get hasProfileStylePack =>
      has(AppConfig.revenueCatEntitlementProfileStylePack) || isPlus;
}

/// Closed-pilot purchase facade. Native billing is deliberately not linked into
/// this release, so every operation fails closed without invoking platform code.
class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const _disabledMessage =
      'Optional purchases are not included in this closed-pilot release.';

  RevenueCatStatus status({String? supabaseUserId}) =>
      const RevenueCatStatus(available: false, message: _disabledMessage);

  Future<RevenueCatStatus> initialize({String? supabaseUserId}) async =>
      status(supabaseUserId: supabaseUserId);

  Future<RevenueCatOperationResult> identifyUser(String supabaseUserId) async =>
      const RevenueCatOperationResult(success: true, message: _disabledMessage);

  Future<RevenueCatOperationResult> logOut() async =>
      const RevenueCatOperationResult(success: true, message: _disabledMessage);

  Future<RevenueCatOperationResult> restorePurchases({
    String? supabaseUserId,
  }) async => const RevenueCatOperationResult(
    success: false,
    message: _disabledMessage,
  );

  Future<RevenueCatOperationResult> presentRevenueCatPaywall({
    String? supabaseUserId,
    String? offeringIdentifier,
  }) async => const RevenueCatOperationResult(
    success: false,
    message: _disabledMessage,
  );

  Future<RevenueCatOperationResult> presentCustomerCenter({
    String? supabaseUserId,
  }) async => const RevenueCatOperationResult(
    success: false,
    message: _disabledMessage,
  );
}
