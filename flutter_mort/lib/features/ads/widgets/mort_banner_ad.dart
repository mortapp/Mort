import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../data/repositories/providers.dart';
import '../data/admob_service.dart';

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

  @override
  void initState() {
    super.initState();
    if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
      _loadRealAd();
    }
  }

  Future<void> _loadRealAd() async {
    final local = const AdMobService().bannerDecision(
      placement: widget.placement,
      userAdFree: widget.userAdFree,
    );
    final decision = await const AdMobService().confirmWithServer(
      decision: local,
      repository: ref.read(monetizationRepositoryProvider),
      placement: widget.placement,
      adFormat: 'banner',
    );
    if (!mounted || !decision.canShow || decision.adUnitId == null) return;

    final ad = BannerAd(
      adUnitId: decision.adUnitId!,
      size: AdSize.banner,
      request: AdRequest(nonPersonalizedAds: decision.requestNonPersonalized),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
          ref
              .read(monetizationRepositoryProvider)
              .recordAdImpression(
                placement: widget.placement,
                format: 'banner',
                adUnitId: decision.adUnitId,
                requestNonPersonalized: decision.requestNonPersonalized,
              );
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled) {
      return const SizedBox.shrink();
    }
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
