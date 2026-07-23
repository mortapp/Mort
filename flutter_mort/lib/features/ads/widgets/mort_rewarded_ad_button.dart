import 'package:flutter/material.dart';

import '../../../core/widgets/mort_widgets.dart';
import '../data/admob_service.dart';

class MortNativeRewardedAdButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final decision = const AdMobService().rewardedDecision(
      placement: placement,
    );
    return MortRewardedAdButton(
      label: decision.canShow ? label : decision.reason,
      enabled: decision.canShow,
      onRewardReady: onReward,
    );
  }
}
