import 'package:flutter/material.dart';

import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';

class PerkRow extends StatelessWidget {
  const PerkRow({super.key, required this.text, this.icon = Icons.check});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MortColors.neon, size: 18),
          const SizedBox(width: MortSpacing.xs),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
