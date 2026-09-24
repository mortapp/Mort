import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' as rc_ui;

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

  bool has(String id) => activeEntitlements.contains(id);
  bool get isPro =>
      has(AppConfig.revenueCatEntitlementPro) ||
      has(AppConfig.revenueCatEntitlementPlus);
  bool get isPlus => isPro;
  bool get isAdFree => has(AppConfig.revenueCatEntitlementAdFree) || isPro;
  bool get isAdultPro => has(AppConfig.revenueCatEntitlementAdultPro);
  bool get isGuardianPlus => has(AppConfig.revenueCatEntitlementGuardianPlus);
  bool get hasUsernameToken =>
      has(AppConfig.revenueCatEntitlementUsernameToken);
  bool get hasJobBoost => has(AppConfig.revenueCatEntitlementJobBoost);
  bool get hasProfileStylePack =>
      has(AppConfig.revenueCatEntitlementProfileStylePack) || isPro;

  factory RevenueCatEntitlementState.fromCustomerInfo(rc.CustomerInfo info) =>
      RevenueCatEntitlementState(
        activeEntitlements: info.entitlements.active.keys.toSet(),
      );
}

/// Only the RevenueCat webhook writes the Supabase entitlement cache.
class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  final _updates = StreamController<rc.CustomerInfo?>.broadcast();
  bool _configured = false;
  String? _userId;
  int _generation = 0;
  Future<RevenueCatStatus>? _pendingInit;
  rc.CustomerInfo? _info;

  rc.CustomerInfo? get currentCustomerInfo => _info;
  Stream<rc.CustomerInfo?> get customerInfoUpdates => _updates.stream;
  RevenueCatEntitlementState get currentEntitlements => _info == null
      ? const RevenueCatEntitlementState(activeEntitlements: <String>{})
      : RevenueCatEntitlementState.fromCustomerInfo(_info!);

  RevenueCatStatus status({String? supabaseUserId}) {
    if (!AppConfig.supportsNativePurchases) {
      return const RevenueCatStatus(
        available: false,
        message: 'Optional purchases are not available right now.',
      );
    }
    if (supabaseUserId == null || !_uuid.hasMatch(supabaseUserId)) {
      return const RevenueCatStatus(
        available: false,
        message: 'Sign in to view MORT Pro.',
      );
    }
    return RevenueCatStatus(
      available: true,
      message: 'MORT Pro is available.',
      entitlements: currentEntitlements.activeEntitlements.toList(),
    );
  }

  Future<RevenueCatStatus> initialize({String? supabaseUserId}) {
    final pending = _pendingInit;
    if (pending != null) {
      return pending.then(
        (_) => _userId == supabaseUserId
            ? status(supabaseUserId: supabaseUserId)
            : initialize(supabaseUserId: supabaseUserId),
      );
    }
    final operation = _initialize(supabaseUserId);
    _pendingInit = operation;
    return operation.whenComplete(() => _pendingInit = null);
  }

  Future<RevenueCatStatus> _initialize(String? userId) async {
    final readiness = status(supabaseUserId: userId);
    if (!readiness.available) {
      if (_userId != null) await logOut();
      return readiness;
    }
    try {
      if (!_configured) {
        await rc.Purchases.setLogLevel(
          kReleaseMode ? rc.LogLevel.warn : rc.LogLevel.debug,
        );
        final configuration =
            rc.PurchasesConfiguration(AppConfig.revenueCatApiKey)
              ..appUserID = userId
              ..automaticDeviceIdentifierCollectionEnabled = false;
        await rc.Purchases.configure(configuration);
        _configured = true;
        _userId = userId;
        _generation++;
        rc.Purchases.addCustomerInfoUpdateListener(_onUpdate);
      } else if (_userId != userId) {
        _clear();
        _userId = null;
        final login = await rc.Purchases.logIn(userId!);
        _userId = userId;
        _generation++;
        if (!await _acceptForUser(login.customerInfo, userId)) {
          throw StateError('Purchase identity changed during sign in.');
        }
      }
      if (!await _acceptForUser(
        await rc.Purchases.getCustomerInfo(),
        userId!,
      )) {
        throw StateError('Purchase identity changed during refresh.');
      }
      return status(supabaseUserId: userId);
    } catch (_) {
      _clear();
      return const RevenueCatStatus(
        available: false,
        message: 'MORT Pro could not connect. Try again later.',
      );
    }
  }

  void _onUpdate(rc.CustomerInfo info) {
    final userId = _userId;
    final generation = _generation;
    if (userId == null) return;
    unawaited(() async {
      try {
        final actualUserId = await rc.Purchases.appUserID;
        if (_userId == userId &&
            _generation == generation &&
            actualUserId == userId) {
          _accept(info);
        }
      } catch (_) {
        // A callback whose identity cannot be checked grants no access.
      }
    }());
  }

  void _accept(rc.CustomerInfo info) {
    if (_userId == null) return;
    _info = info;
    _updates.add(info);
  }

  Future<bool> _acceptForUser(rc.CustomerInfo info, String userId) async {
    try {
      if (_userId != userId) return false;
      final generation = _generation;
      final actualUserId = await rc.Purchases.appUserID;
      if (_userId != userId ||
          _generation != generation ||
          actualUserId != userId) {
        return false;
      }
      _accept(info);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _clear() {
    _generation++;
    _info = null;
    _updates.add(null);
  }

  Future<RevenueCatOperationResult> identifyUser(String userId) async {
    final result = await initialize(supabaseUserId: userId);
    return RevenueCatOperationResult(
      success: result.available,
      message: result.message,
    );
  }

  Future<RevenueCatOperationResult> logOut() async {
    final hadUser = _userId != null;
    _userId = null;
    _clear();
    if (_configured && hadUser) {
      try {
        await rc.Purchases.logOut();
      } catch (_) {
        return const RevenueCatOperationResult(
          success: false,
          message: 'Purchase account sign out needs a retry.',
        );
      }
    }
    return const RevenueCatOperationResult(
      success: true,
      message: 'Purchase account cleared.',
    );
  }

  Future<rc.CustomerInfo?> getCustomerInfo(String userId) async =>
      (await initialize(supabaseUserId: userId)).available ? _info : null;

  Future<rc.Offerings?> getOfferings(String userId) async {
    if (!(await initialize(supabaseUserId: userId)).available) return null;
    try {
      return await rc.Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  static rc.Offering? proOffering(rc.Offerings? offerings) {
    final offering = offerings?.getOffering('default');
    if (offering == null) return null;
    const expected = {
      r'$rc_weekly': 'mort_pro:weekly',
      r'$rc_monthly': 'mort_pro:monthly',
      r'$rc_annual': 'mort_pro:annual',
      r'$rc_lifetime': 'lifetime',
    };
    final packages = offering.availablePackages;
    if (packages.length != expected.length ||
        packages.map((item) => item.identifier).toSet().length !=
            expected.length ||
        packages.any(
          (item) => expected[item.identifier] != item.storeProduct.identifier,
        )) {
      return null;
    }
    return offering;
  }

  Future<RevenueCatOperationResult> purchasePackage({
    required String userId,
    required rc.Package package,
  }) async {
    final ready = await initialize(supabaseUserId: userId);
    if (!ready.available) {
      return RevenueCatOperationResult(success: false, message: ready.message);
    }
    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(package),
      );
      if (!await _acceptForUser(result.customerInfo, userId)) {
        return const RevenueCatOperationResult(
          success: false,
          message: 'Purchase account changed. Sign in and refresh MORT Pro.',
        );
      }
      return _proResult(
        result.customerInfo,
        absent: 'Payment is pending. MORT Pro is not active yet.',
      );
    } on PlatformException catch (error) {
      return _operationError(error);
    } catch (_) {
      return const RevenueCatOperationResult(
        success: false,
        message: 'Purchase could not be completed. Please try again.',
      );
    }
  }

  Future<RevenueCatOperationResult> restorePurchases({
    String? supabaseUserId,
  }) async {
    final ready = await initialize(supabaseUserId: supabaseUserId);
    if (!ready.available) {
      return RevenueCatOperationResult(success: false, message: ready.message);
    }
    try {
      final info = await rc.Purchases.restorePurchases();
      if (!await _acceptForUser(info, supabaseUserId!)) {
        return const RevenueCatOperationResult(
          success: false,
          message: 'Purchase account changed. Sign in and refresh MORT Pro.',
        );
      }
      return _proResult(info, absent: 'No active MORT Pro purchase was found.');
    } on PlatformException catch (error) {
      return _operationError(error);
    } catch (_) {
      return const RevenueCatOperationResult(
        success: false,
        message: 'Restore could not be completed. Please try again.',
      );
    }
  }

  Future<RevenueCatOperationResult> presentRevenueCatPaywall({
    String? supabaseUserId,
    String? offeringIdentifier,
  }) async {
    final ready = await initialize(supabaseUserId: supabaseUserId);
    if (!ready.available) {
      return RevenueCatOperationResult(success: false, message: ready.message);
    }
    try {
      final offerings = await rc.Purchases.getOfferings();
      final offering =
          offeringIdentifier == null || offeringIdentifier == 'default'
          ? proOffering(offerings)
          : null;
      if (offering == null || offering.availablePackages.isEmpty) {
        return const RevenueCatOperationResult(
          success: false,
          message: 'MORT Pro plans are not available yet.',
        );
      }
      final result = await rc_ui.RevenueCatUI.presentPaywall(
        offering: offering,
      );
      if (result == rc_ui.PaywallResult.cancelled) {
        return const RevenueCatOperationResult(
          success: false,
          cancelled: true,
          message: 'Purchase cancelled.',
        );
      }
      if (result == rc_ui.PaywallResult.error) {
        return const RevenueCatOperationResult(
          success: false,
          message: 'Purchase could not be completed.',
        );
      }
      final info = await rc.Purchases.getCustomerInfo();
      if (!await _acceptForUser(info, supabaseUserId!)) {
        return const RevenueCatOperationResult(
          success: false,
          message: 'Purchase account changed. Sign in and refresh MORT Pro.',
        );
      }
      return _proResult(info, absent: 'MORT Pro is not active yet.');
    } on PlatformException catch (error) {
      return _operationError(error);
    } catch (_) {
      return const RevenueCatOperationResult(
        success: false,
        message: 'MORT Pro plans are unavailable. Please try again.',
      );
    }
  }

  Future<RevenueCatOperationResult> presentCustomerCenter({
    String? supabaseUserId,
  }) async {
    final ready = await initialize(supabaseUserId: supabaseUserId);
    if (!ready.available) {
      return RevenueCatOperationResult(success: false, message: ready.message);
    }
    try {
      await rc_ui.RevenueCatUI.presentCustomerCenter();
      if (!await _acceptForUser(
        await rc.Purchases.getCustomerInfo(),
        supabaseUserId!,
      )) {
        return const RevenueCatOperationResult(
          success: false,
          message: 'Purchase account changed. Sign in and refresh MORT Pro.',
        );
      }
      return const RevenueCatOperationResult(
        success: true,
        message: 'Subscription status refreshed.',
      );
    } catch (_) {
      return const RevenueCatOperationResult(
        success: false,
        message: 'Subscription management is unavailable. Please try again.',
      );
    }
  }

  RevenueCatOperationResult _proResult(
    rc.CustomerInfo info, {
    required String absent,
  }) {
    final active = RevenueCatEntitlementState.fromCustomerInfo(info).isPro;
    return RevenueCatOperationResult(
      success: active,
      message: active ? 'MORT Pro is active.' : absent,
    );
  }

  RevenueCatOperationResult _operationError(PlatformException error) {
    rc.PurchasesErrorCode? code;
    try {
      code = rc.PurchasesErrorHelper.getErrorCode(error);
    } catch (_) {
      // Some platform errors use non-numeric codes.
    }
    if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
      return const RevenueCatOperationResult(
        success: false,
        cancelled: true,
        message: 'Purchase cancelled.',
      );
    }
    if (code == rc.PurchasesErrorCode.paymentPendingError) {
      return const RevenueCatOperationResult(
        success: false,
        message: 'Payment is pending. MORT Pro will appear when confirmed.',
      );
    }
    if (code == rc.PurchasesErrorCode.networkError ||
        code == rc.PurchasesErrorCode.offlineConnectionError) {
      return const RevenueCatOperationResult(
        success: false,
        message: 'Connection unavailable. Check your network and retry.',
      );
    }
    return const RevenueCatOperationResult(
      success: false,
      message: 'The store could not complete this request. Please try again.',
    );
  }
}
