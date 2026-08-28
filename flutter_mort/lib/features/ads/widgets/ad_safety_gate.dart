import 'package:flutter/material.dart';

import '../data/admob_service.dart';

class AdSafetyGate extends StatelessWidget {
  const AdSafetyGate({
    super.key,
    required this.placement,
    required this.child,
    this.userAdFree = false,
  });

  final String placement;
  final Widget child;
  final bool userAdFree;

  @override
  Widget build(BuildContext context) {
    final decision = const AdMobService().bannerDecision(
      placement: placement,
      userAdFree: userAdFree,
    );
    if (!decision.canShow) return const SizedBox.shrink();
    return child;
  }
}
