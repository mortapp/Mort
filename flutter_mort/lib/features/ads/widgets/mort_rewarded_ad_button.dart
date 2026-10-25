import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../../../data/repositories/providers.dart';
import '../../monetization/providers/revenuecat_providers.dart';
import '../data/admob_service.dart';
import '../data/ad_session_identity.dart';
import '../data/ad_startup_coordinator.dart';

class MortNativeRewardedAdButton extends ConsumerStatefulWidget {
  const MortNativeRewardedAdButton({
    super.key,
    required this.placement,
    required this.label,
    this.onReward,
  });

  final String placement;
  final String label;
  final VoidCallback? onReward;

  @override
  ConsumerState<MortNativeRewardedAdButton> createState() =>
      _MortNativeRewardedAdButtonState();
}

class _MortNativeRewardedAdButtonState
    extends ConsumerState<MortNativeRewardedAdButton> {
  RewardedAd? _ad;
  String? _pendingAdUnitId;
  bool _pendingNonPersonalized = true;
  bool _loading = false;
  bool _showing = false;
  final _sessionGuard = AdRequestSessionGuard();
  final _eligibilityRequests = <(String, String, DateTime?, String)>{};
  bool _awaitingEntitlementsAfterAuth = false;
  AdSessionIdentity? _adSession;
  Timer? _sessionExpiryTimer;

  int get _generation => _sessionGuard.generation;

  @override
  void initState() {
    super.initState();
    if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
      _loadIfNeeded();
    }
  }

  @override
  void dispose() {
    _sessionGuard.invalidate();
    _sessionExpiryTimer?.cancel();
    if (!_showing) _ad?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MortNativeRewardedAdButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) {
      _invalidateAndReload();
    }
  }

  Future<void> _loadIfNeeded() async {
    if (_ad != null || _loading || _showing || !mounted) return;
    final identity = ref.read(adSessionIdentityReaderProvider)();
    if (identity == null ||
        !identity.isActive ||
        !_serverEntitlementsAllowAds() ||
        !_adStartupReady) {
      return;
    }
    final eligibilityKey = (
      identity.userId,
      identity.accessToken,
      identity.expiresAt,
      widget.placement,
    );
    if (!_eligibilityRequests.add(eligibilityKey)) return;

    final generation = _sessionGuard.begin();
    final placement = widget.placement;
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = Timer(
      identity.expiresAt!.difference(DateTime.now().toUtc()),
      _invalidateAndReload,
    );
    setState(() => _loading = true);
    final local = const AdMobService().rewardedDecision(placement: placement);
    late final AdMobDecision decision;
    try {
      decision = await const AdMobService().confirmWithServer(
        decision: local,
        repository: ref.read(monetizationRepositoryProvider),
        placement: placement,
        adFormat: 'rewarded',
      );
    } finally {
      _eligibilityRequests.remove(eligibilityKey);
    }
    if (!_isCurrent(identity, generation, placement)) {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
      return;
    }
    if (!decision.canShow || decision.adUnitId == null) {
      _sessionExpiryTimer?.cancel();
      setState(() => _loading = false);
      return;
    }
    RewardedAd.load(
      adUnitId: decision.adUnitId!,
      request: AdRequest(nonPersonalizedAds: decision.requestNonPersonalized),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!_isCurrent(identity, generation, placement)) {
            ad.dispose();
            if (mounted && generation == _generation) {
              _sessionExpiryTimer?.cancel();
              setState(() => _loading = false);
            }
            return;
          }
          setState(() {
            _ad = ad;
            _pendingAdUnitId = decision.adUnitId;
            _pendingNonPersonalized = decision.requestNonPersonalized;
            _adSession = identity;
            _loading = false;
          });
        },
        onAdFailedToLoad: (error) {
          if (_isCurrent(identity, generation, placement)) {
            setState(() => _loading = false);
          } else if (mounted && generation == _generation) {
            _sessionExpiryTimer?.cancel();
            setState(() => _loading = false);
          }
        },
      ),
    );
  }

  void _show() {
    final ad = _ad;
    final identity = _adSession;
    final generation = _generation;
    final placement = widget.placement;
    if (ad == null ||
        identity == null ||
        !_isCurrent(identity, generation, placement)) {
      _invalidateAndReload();
      return;
    }
    setState(() {
      _ad = null;
      _showing = true;
    });
    var impressionRecorded = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (ad) {
        if (impressionRecorded ||
            !_isCurrent(identity, generation, placement)) {
          return;
        }
        impressionRecorded = true;
        ref
            .read(monetizationRepositoryProvider)
            .recordAdImpression(
              placement: placement,
              format: 'rewarded',
              adUnitId: _pendingAdUnitId,
              requestNonPersonalized: _pendingNonPersonalized,
            );
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!mounted) return;
        setState(() => _showing = false);
        _loadIfNeeded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!mounted) return;
        setState(() => _showing = false);
        _loadIfNeeded();
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) {
        if (!_isCurrent(identity, generation, placement)) return;
        // The reward is granted only here, inside the SDK's own
        // earned-reward callback -- never on tap, and never before the ad
        // has actually been watched to completion.
        widget.onReward?.call();
      },
    );
  }

  bool _isCurrent(
    AdSessionIdentity identity,
    int generation,
    String placement,
  ) {
    return mounted &&
        generation == _generation &&
        placement == widget.placement &&
        _serverEntitlementsAllowAds() &&
        _sessionGuard.isCurrent(
          generation,
          identity,
          ref.read(adSessionIdentityReaderProvider)(),
        );
  }

  bool _serverEntitlementsAllowAds() {
    return const AdMobService().entitlementsAllowAds(
      ref.read(backendEntitlementsProvider).asData?.value,
    );
  }

  bool get _adStartupReady =>
      ref.read(adStartupStateProvider).asData?.value == AdStartupResult.ready;

  void _handleAuthChange() {
    _awaitingEntitlementsAfterAuth = true;
    ref.invalidate(backendEntitlementsProvider);
    _invalidateAndReload(reload: false);
  }

  void _handleEntitlementsChange(
    AsyncValue<Map<String, dynamic>>? previous,
    AsyncValue<Map<String, dynamic>> next,
  ) {
    if (next.isLoading || next.hasError || next.asData == null) return;
    if (_awaitingEntitlementsAfterAuth) {
      _awaitingEntitlementsAfterAuth = false;
      _invalidateAndReload();
      return;
    }
    final previousValue = previous?.asData?.value;
    if (previousValue == null) {
      if (!_loading && _ad == null) _loadIfNeeded();
      return;
    }
    if (const AdMobService().entitlementsAllowAds(previousValue) !=
        _serverEntitlementsAllowAds()) {
      _invalidateAndReload();
    }
  }

  void _invalidateAndReload({bool reload = true}) {
    _sessionGuard.invalidate();
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    final ad = _ad;
    _ad = null;
    if (!_showing) ad?.dispose();
    _adSession = null;
    _pendingAdUnitId = null;
    _loading = false;
    if (mounted) {
      setState(() {});
      if (reload && AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
        _loadIfNeeded();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
      ref.listen(authStateProvider, (previous, next) {
        _handleAuthChange();
      });
      ref.listen(backendEntitlementsProvider, (previous, next) {
        _handleEntitlementsChange(previous, next);
      });
    }
    if (!AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled) {
      final decision = const AdMobService().rewardedDecision(
        placement: widget.placement,
      );
      return MortRewardedAdButton(
        label: decision.canShow ? widget.label : decision.reason,
        enabled: false,
        onRewardReady: null,
      );
    }

    final identity = ref.read(adSessionIdentityReaderProvider)();
    if (identity == null ||
        !identity.isActive ||
        !_serverEntitlementsAllowAds()) {
      return MortRewardedAdButton(
        label: 'Ads unavailable',
        enabled: false,
        onRewardReady: null,
      );
    }

    ref.watch(adStartupStateProvider);
    ref.listen(adStartupStateProvider, (previous, next) {
      if (next.asData?.value == AdStartupResult.ready) {
        _loadIfNeeded();
      } else if (previous?.asData?.value == AdStartupResult.ready) {
        _invalidateAndReload();
      }
    });

    final startupResult = ref.read(adStartupStateProvider).asData?.value;
    if (startupResult != AdStartupResult.ready && !_showing && _ad == null) {
      return MortRewardedAdButton(
        label: startupResult == null ? 'Preparing ads...' : 'Ads unavailable',
        enabled: false,
        onRewardReady: null,
      );
    }

    if (_showing) {
      return MortRewardedAdButton(
        label: 'Ad playing...',
        enabled: false,
        onRewardReady: null,
      );
    }

    if (_ad != null) {
      return MortRewardedAdButton(
        label: widget.label,
        enabled: true,
        onRewardReady: _show,
      );
    }

    return MortRewardedAdButton(
      label: _loading ? 'Loading...' : widget.label,
      enabled: false,
      onRewardReady: null,
    );
  }
}
