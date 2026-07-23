import 'package:flutter/material.dart';

import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../data/admob_service.dart';

class MortBannerAd extends StatelessWidget {
  const MortBannerAd({
    super.key,
    required this.placement,
    this.userAdFree = false,
  });

  final String placement;
  final bool userAdFree;

  @override
  Widget build(BuildContext context) {
    final decision = const AdMobService().bannerDecision(
      placement: placement,
      userAdFree: userAdFree,
    );
    if (!decision.canShow) return const SizedBox.shrink();
    return MortCard(
      color: MortColors.cardAlt,
      child: Row(
        children: [
          const TestAdBadge(),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(
              'Native AdMob banner slot ready for $placement.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class TestAdBadge extends StatelessWidget {
  const TestAdBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortBadge(label: 'Test ads first', color: MortColors.warning);
  }
}
