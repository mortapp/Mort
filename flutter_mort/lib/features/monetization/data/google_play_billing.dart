import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../data/services/supabase_service.dart';

const mortPlusProductId = 'mort_plus';
const mortOneTimeProductIds = <String>{
  'mort_theme_neon_pack',
  'mort_theme_midnight_pack',
  'mort_profile_frames_pack_01',
  'mort_portfolio_layouts_pack_01',
};
const mortGooglePlayProductIds = <String>{
  mortPlusProductId,
  ...mortOneTimeProductIds,
};

class BillingCatalogResult {
  const BillingCatalogResult({
    required this.available,
    required this.products,
    required this.missingProductIds,
    this.message,
  });

  final bool available;
  final List<ProductDetails> products;
  final Set<String> missingProductIds;
  final String? message;
}

class BillingProductRepository {
  BillingProductRepository({InAppPurchase? billing})
    : _billing = billing ?? InAppPurchase.instance;

  final InAppPurchase _billing;

  Future<BillingCatalogResult> loadProducts() async {
    if (!AppConfig.supportsNativePurchases) {
      return const BillingCatalogResult(
        available: false,
        products: [],
        missingProductIds: mortGooglePlayProductIds,
        message:
            'Google Play purchases are disabled for this build. Core MORT remains available.',
      );
    }
    final available = await _billing.isAvailable();
    if (!available) {
      return const BillingCatalogResult(
        available: false,
        products: [],
        missingProductIds: mortGooglePlayProductIds,
        message: 'Google Play Billing is unavailable on this device.',
      );
    }
    final response = await _billing.queryProductDetails(
      mortGooglePlayProductIds,
    );
    final products = [...response.productDetails]
      ..sort((left, right) => left.rawPrice.compareTo(right.rawPrice));
    return BillingCatalogResult(
      available: response.error == null,
      products: products,
      missingProductIds: response.notFoundIDs.toSet(),
      message: response.error?.message,
    );
  }
}

class GooglePlayBillingService {
  GooglePlayBillingService._();

  static final instance = GooglePlayBillingService._();
  final InAppPurchase _billing = InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchaseStream => _billing.purchaseStream;

  Future<bool> purchase(ProductDetails product, String userId) {
    final accountHash = sha256.convert(utf8.encode(userId)).toString();
    final parameter = PurchaseParam(
      productDetails: product,
      applicationUserName: accountHash,
    );
    return _billing.buyNonConsumable(purchaseParam: parameter);
  }

  Future<void> restore(String userId) {
    final accountHash = sha256.convert(utf8.encode(userId)).toString();
    return _billing.restorePurchases(applicationUserName: accountHash);
  }

  Future<void> complete(PurchaseDetails purchase) =>
      _billing.completePurchase(purchase);
}

class PurchaseVerificationResult {
  const PurchaseVerificationResult({
    required this.verified,
    required this.state,
    this.entitlementStatus,
    this.code,
  });

  final bool verified;
  final String state;
  final String? entitlementStatus;
  final String? code;
}

class PurchaseVerificationRepository {
  Future<PurchaseVerificationResult> verify(PurchaseDetails purchase) async {
    if (!SupabaseService.isInitialized) {
      return const PurchaseVerificationResult(
        verified: false,
        state: 'failed',
        code: 'backend_not_configured',
      );
    }
    try {
      final response = await SupabaseService.client.functions.invoke(
        'google-play-verify-purchase',
        body: {
          'product_id': purchase.productID,
          'purchase_token': purchase.verificationData.serverVerificationData,
          'client_request_id': const Uuid().v4(),
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      return PurchaseVerificationResult(
        verified: data['ok'] == true && data['provider_verified'] == true,
        state: data['purchase_state']?.toString() ?? 'failed',
        entitlementStatus: data['entitlement_status']?.toString(),
        code: data['code']?.toString(),
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['code']?.toString() : null;
      return PurchaseVerificationResult(
        verified: false,
        state: 'failed',
        code: code ?? 'verification_unavailable',
      );
    } catch (_) {
      return const PurchaseVerificationResult(
        verified: false,
        state: 'failed',
        code: 'verification_unavailable',
      );
    }
  }
}

class EntitlementRepository {
  Future<Map<String, dynamic>> loadMine() async {
    if (!SupabaseService.isInitialized) return const {};
    final response = await SupabaseService.client.rpc(
      'get_my_play_entitlements',
    );
    return response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
  }
}

class RestorePurchasesService {
  RestorePurchasesService({GooglePlayBillingService? billing})
    : _billing = billing ?? GooglePlayBillingService.instance;

  final GooglePlayBillingService _billing;

  Future<void> restore() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before restoring purchases.');
    await _billing.restore(userId);
  }
}

class ManageSubscriptionService {
  Future<bool> openGooglePlay() {
    return launchUrl(
      Uri.https('play.google.com', '/store/account/subscriptions', {
        'package': AppConfig.androidPackage,
        'sku': mortPlusProductId,
      }),
      mode: LaunchMode.externalApplication,
    );
  }
}

enum PurchaseFlowState {
  idle,
  loadingProducts,
  ready,
  pending,
  verifying,
  success,
  cancelled,
  failed,
  unavailable,
}

class PurchaseController extends ChangeNotifier {
  PurchaseController._();

  static final instance = PurchaseController._();
  final _billing = GooglePlayBillingService.instance;
  final _catalog = BillingProductRepository();
  final _verification = PurchaseVerificationRepository();
  final _entitlements = EntitlementRepository();
  final _restore = RestorePurchasesService();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;

  PurchaseFlowState state = PurchaseFlowState.idle;
  List<ProductDetails> products = const [];
  Set<String> missingProductIds = const {};
  Map<String, dynamic> entitlements = const {};
  String? message;

  Future<void> initialize() async {
    if (_initialized || !AppConfig.supportsNativePurchases) return;
    _initialized = true;
    _subscription = _billing.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {
        state = PurchaseFlowState.failed;
        message = 'Google Play purchase updates are unavailable.';
        notifyListeners();
      },
    );
    await refresh();
  }

  Future<void> refresh() async {
    state = PurchaseFlowState.loadingProducts;
    message = null;
    notifyListeners();
    final result = await _catalog.loadProducts();
    products = result.products;
    missingProductIds = result.missingProductIds;
    message = result.message;
    state = result.available
        ? PurchaseFlowState.ready
        : PurchaseFlowState.unavailable;
    try {
      entitlements = await _entitlements.loadMine();
    } catch (_) {
      message ??= 'Entitlement status could not be refreshed.';
    }
    notifyListeners();
  }

  Future<void> buy(ProductDetails product) async {
    if (!AppConfig.supportsNativePurchases) return;
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      state = PurchaseFlowState.failed;
      message = 'Sign in before purchasing an optional perk.';
      notifyListeners();
      return;
    }
    state = PurchaseFlowState.pending;
    message = null;
    notifyListeners();
    try {
      final launched = await _billing.purchase(product, userId);
      if (!launched) {
        state = PurchaseFlowState.failed;
        message = 'Google Play did not open the purchase sheet.';
        notifyListeners();
      }
    } catch (_) {
      state = PurchaseFlowState.failed;
      message = 'The purchase could not be started.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    state = PurchaseFlowState.pending;
    message = 'Checking Google Play purchases...';
    notifyListeners();
    try {
      await _restore.restore();
    } catch (_) {
      state = PurchaseFlowState.failed;
      message = 'Purchases could not be restored right now.';
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = PurchaseFlowState.pending;
          message = 'Google Play is still processing this purchase.';
        case PurchaseStatus.canceled:
          state = PurchaseFlowState.cancelled;
          message = 'The purchase was canceled. Nothing was charged by MORT.';
        case PurchaseStatus.error:
          state = PurchaseFlowState.failed;
          message = purchase.error?.message ?? 'Google Play reported an error.';
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          state = PurchaseFlowState.verifying;
          message = 'Confirming this purchase with Google Play...';
          notifyListeners();
          final result = await _verification.verify(purchase);
          if (result.verified) {
            if (purchase.pendingCompletePurchase) {
              await _billing.complete(purchase);
            }
            entitlements = await _entitlements.loadMine();
            state = PurchaseFlowState.success;
            message = 'Google Play verified your optional perk.';
          } else {
            state = PurchaseFlowState.failed;
            message = _verificationMessage(result.code);
          }
      }
      notifyListeners();
    }
  }

  String _verificationMessage(String? code) => switch (code) {
    'billing_provider_disabled' || 'provider_verification_disabled' =>
      'Purchases are not enabled for this closed test yet.',
    'wrong_user' =>
      'Google Play could not bind this purchase to the signed-in MORT account.',
    'purchase_token_replayed' =>
      'This purchase is already linked to a different MORT account.',
    'wrong_package' || 'wrong_product' || 'wrong_environment' =>
      'This purchase does not match the approved MORT test catalog.',
    _ =>
      'MORT could not verify this purchase. No perk was unlocked. Try Restore later.',
  };

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    super.dispose();
  }
}
