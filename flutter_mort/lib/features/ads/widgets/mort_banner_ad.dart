import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/providers.dart';
import '../../monetization/providers/revenuecat_providers.dart';
import '../data/admob_service.dart';
import '../data/ad_session_identity.dart';
import '../data/ad_startup_coordinator.dart';

class MortBannerAd extends ConsumerStatefulWidget {
  const MortBannerAd({
    super.key,
    required this.placement,
    this.userAdFree = false,
  });

  final String placement;
  final bool userAdFree;

  @override
  ConsumerState<MortBannerAd> createState() => _MortBannerAdState();
}

class _MortBannerAdState extends ConsumerState<MortBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  final _sessionGuard = AdRequestSessionGuard();
  Timer? _sessionExpiryTimer;

  int get _generation => _sessionGuard.generation;

  @override
  void initState() {
    super.initState();
    if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
      _loadRealAd();
    }
  }

  @override
  void didUpdateWidget(covariant MortBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement ||
        oldWidget.userAdFree != widget.userAdFree) {
      _invalidateAndReload();
    }
  }

  Future<void> _loadRealAd() async {
    if (_loading || _ad != null || !mounted) return;
    final identity = ref.read(adSessionIdentityReaderProvider)();
    if (identity == null ||
        !identity.isActive ||
        widget.userAdFree ||
        !_serverEntitlementsAllowAds() ||
        !_adStartupReady) {
      return;
    }

    final generation = _sessionGuard.begin();
    final placement = widget.placement;
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = Timer(
      identity.expiresAt!.difference(DateTime.now().toUtc()),
      _invalidateAndReload,
    );
    setState(() => _loading = true);
    final local = const AdMobService().bannerDecision(
      placement: placement,
      userAdFree: widget.userAdFree,
    );
    final decision = await const AdMobService().confirmWithServer(
      decision: local,
      repository: ref.read(monetizationRepositoryProvider),
      placement: placement,
      adFormat: 'banner',
    );
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

    final ad = BannerAd(
      adUnitId: decision.adUnitId!,
      size: AdSize.banner,
      request: AdRequest(nonPersonalizedAds: decision.requestNonPersonalized),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!_isCurrent(identity, generation, placement)) {
            if (identical(_ad, loadedAd)) {
              loadedAd.dispose();
              _ad = null;
            }
            if (mounted && generation == _generation) {
              _sessionExpiryTimer?.cancel();
              setState(() {
                _loaded = false;
                _loading = false;
              });
            }
            return;
          }
          setState(() {
            _loaded = true;
            _loading = false;
          });
          ref
              .read(monetizationRepositoryProvider)
              .recordAdImpression(
                placement: placement,
                format: 'banner',
                adUnitId: decision.adUnitId,
                requestNonPersonalized: decision.requestNonPersonalized,
              );
        },
        onAdFailedToLoad: (ad, error) {
          if (identical(_ad, ad)) {
            ad.dispose();
            _ad = null;
          }
          if (!_isCurrent(identity, generation, placement)) {
            if (mounted && generation == _generation) {
              setState(() => _loading = false);
            }
            return;
          }
          setState(() {
            _ad = null;
            _loaded = false;
            _loading = false;
          });
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  bool _isCurrent(
    AdSessionIdentity identity,
    int generation,
    String placement,
  ) {
    return mounted &&
        generation == _generation &&
        placement == widget.placement &&
        !widget.userAdFree &&
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
    ref.invalidate(backendEntitlementsProvider);
    _invalidateAndReload();
  }

  void _invalidateAndReload() {
    _sessionGuard.invalidate();
    _sessionExpiryTimer?.cancel();
    _sessionExpiryTimer = null;
    final ad = _ad;
    _ad = null;
    ad?.dispose();
    _loaded = false;
    _loading = false;
    if (mounted) {
      setState(() {});
      if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
        _loadRealAd();
      }
    }
  }

  @override
  void dispose() {
    _sessionGuard.invalidate();
    _sessionExpiryTimer?.cancel();
    final ad = _ad;
    _ad = null;
    ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
      ref.listen(authStateProvider, (previous, next) {
        _handleAuthChange();
      });
      ref.listen(backendEntitlementsProvider, (previous, next) {
        _invalidateAndReload();
      });
    }
    if (!AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled) {
      return const SizedBox.shrink();
    }
    final identity = ref.read(adSessionIdentityReaderProvider)();
    if (identity == null ||
        !identity.isActive ||
        widget.userAdFree ||
        !_serverEntitlementsAllowAds()) {
      return const SizedBox.shrink();
    }
    ref.watch(adStartupStateProvider);
    ref.listen(adStartupStateProvider, (previous, next) {
      if (next.asData?.value == AdStartupResult.ready) {
        _loadRealAd();
      } else if (previous?.asData?.value == AdStartupResult.ready) {
        _invalidateAndReload();
      }
    });
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
