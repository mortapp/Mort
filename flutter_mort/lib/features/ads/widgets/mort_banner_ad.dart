import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/services/supabase_service.dart';
import '../data/ad_consent_service.dart';
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
  String? _adOwner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
      _loadRealAd();
    }
  }

  Future<void> _loadRealAd() async {
    final owner = _signedInUserId;
    final placement = widget.placement;
    bool stillEligible() =>
        mounted &&
        placement == widget.placement &&
        !widget.userAdFree &&
        _isEligible(owner, ref.read(currentProfileProvider).asData?.value);
    if (!stillEligible()) return;
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
    if (!decision.canShow || decision.adUnitId == null) return;
    if (!await AdRequestGate.instance.prepare(stillEligible: stillEligible)) {
      return;
    }

    final ad = BannerAd(
      adUnitId: decision.adUnitId!,
      size: AdSize.banner,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!stillEligible()) return;
          setState(() => _loaded = true);
          ref
              .read(monetizationRepositoryProvider)
              .recordAdImpression(
                placement: widget.placement,
                format: 'banner',
                adUnitId: decision.adUnitId,
                requestNonPersonalized: true,
              );
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _adOwner = owner;
    _ad = ad;
    ad.load();
  }

  String? get _signedInUserId => SupabaseService.isInitialized
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  bool _isEligible(String? owner, Profile? profile) =>
      owner == _signedInUserId &&
      isEligibleAdultAdAccount(profile, owner, DateTime.now());

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
    final profile = ref.watch(currentProfileProvider).asData?.value;
    if (!_loaded ||
        _ad == null ||
        widget.userAdFree ||
        !_isEligible(_adOwner, profile)) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
