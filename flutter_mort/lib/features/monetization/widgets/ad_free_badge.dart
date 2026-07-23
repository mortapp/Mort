import 'package:flutter/material.dart';

import '../../../core/theme/mort_colors.dart';
import '../../../core/widgets/mort_widgets.dart';

class AdFreeBadge extends StatelessWidget {
  const AdFreeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortBadge(
      label: 'Ad-free perk',
      color: MortColors.neon,
      icon: Icons.visibility_off_outlined,
    );
  }
}
