import 'package:flutter/material.dart';

import '../../../core/theme/mort_colors.dart';
import '../../../core/widgets/mort_widgets.dart';

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortBadge(
      label: 'Optional premium',
      color: MortColors.premium,
      icon: Icons.auto_awesome,
    );
  }
}
