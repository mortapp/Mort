import 'package:flutter/material.dart';

import '../../../core/widgets/mort_widgets.dart';

class MonetizationFeatureLockCard extends StatelessWidget {
  const MonetizationFeatureLockCard({
    super.key,
    required this.feature,
    required this.reason,
  });

  final String feature;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return MortFeatureLockCard(feature: feature, reason: reason);
  }
}
