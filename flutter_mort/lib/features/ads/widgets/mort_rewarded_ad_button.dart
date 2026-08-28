import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../../../data/repositories/providers.dart';
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
  bool _pendingNonPersonalized = true;
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
    final local = const AdMobService().rewardedDecision(
      placement: widget.placement,
    );
    final decision = await const AdMobService().confirmWithServer(
      decision: local,
      repository: ref.read(monetizationRepositoryProvider),
      placement: widget.placement,
      adFormat: 'rewarded',
    );
    if (!mounted || !decision.canShow || decision.adUnitId == null) return;
    setState(() => _loading = true);
    RewardedAd.load(
      adUnitId: decision.adUnitId!,
      request: AdRequest(nonPersonalizedAds: decision.requestNonPersonalized),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad;
            _pendingAdUnitId = decision.adUnitId;
            _pendingNonPersonalized = decision.requestNonPersonalized;
            _loading = false;
          });
        },
        onAdFailedToLoad: (error) {
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
  }

  void _show() {
    final ad = _ad;
    if (ad == null) return;
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
        ref
            .read(monetizationRepositoryProvider)
            .recordAdImpression(
              placement: widget.placement,
              format: 'rewarded',
              adUnitId: _pendingAdUnitId,
              requestNonPersonalized: _pendingNonPersonalized,
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
