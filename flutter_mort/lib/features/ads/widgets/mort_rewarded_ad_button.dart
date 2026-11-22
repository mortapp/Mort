import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/services/supabase_service.dart';
import '../data/ad_consent_service.dart';
import '../data/admob_service.dart';

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
  String? _adOwner;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.nativeAdsCompiledIn && AppConfig.adsEnabled) {
      _loadIfNeeded();
    }
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _loadIfNeeded() async {
    if (_ad != null || _loading) return;
    final owner = _signedInUserId;
    final placement = widget.placement;
    bool stillEligible() =>
        mounted &&
        placement == widget.placement &&
        _isEligible(owner, ref.read(currentProfileProvider).asData?.value);
    if (!stillEligible()) return;
    final local = const AdMobService().rewardedDecision(placement: placement);
    final decision = await const AdMobService().confirmWithServer(
      decision: local,
      repository: ref.read(monetizationRepositoryProvider),
      placement: placement,
      adFormat: 'rewarded',
    );
    if (!decision.canShow || decision.adUnitId == null) return;
    if (!await AdRequestGate.instance.prepare(stillEligible: stillEligible)) {
      return;
    }
    setState(() => _loading = true);
    RewardedAd.load(
      adUnitId: decision.adUnitId!,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!stillEligible()) {
            ad.dispose();
            if (mounted) setState(() => _loading = false);
            return;
          }
          setState(() {
            _ad = ad;
            _pendingAdUnitId = decision.adUnitId;
            _adOwner = owner;
            _loading = false;
          });
        },
        onAdFailedToLoad: (error) {
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
  }

  String? get _signedInUserId => SupabaseService.isInitialized
      ? SupabaseService.client.auth.currentUser?.id
      : null;

  bool _isEligible(String? owner, Profile? profile) =>
      owner == _signedInUserId &&
      isEligibleAdultAdAccount(profile, owner, DateTime.now());

  void _show() {
    final ad = _ad;
    final owner = _adOwner;
    bool stillEligible() =>
        mounted &&
        _isEligible(owner, ref.read(currentProfileProvider).asData?.value);
    if (ad == null || !stillEligible()) return;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (mounted) setState(() => _ad = null);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (mounted) setState(() => _ad = null);
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) {
        // The reward is granted only here, inside the SDK's own
        // earned-reward callback -- never on tap, and never before the ad
        // has actually been watched to completion.
        if (!stillEligible()) return;
        ref
            .read(monetizationRepositoryProvider)
            .recordAdImpression(
              placement: widget.placement,
              format: 'rewarded',
              adUnitId: _pendingAdUnitId,
              requestNonPersonalized: true,
            );
        widget.onReward?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final profile = ref.watch(currentProfileProvider).asData?.value;
    if (_ad != null && _isEligible(_adOwner, profile)) {
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
