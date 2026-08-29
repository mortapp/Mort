import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';

class RevenueCatRestorePurchasesScreen extends StatelessWidget {
  const RevenueCatRestorePurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Optional perks',
          title: 'Purchases unavailable',
          subtitle: 'App-store purchases cannot be made or restored right now.',
        ),
        const MortEmptyState(
          title: 'Nothing to restore in this release',
          message:
              'Your account and all core safety features continue to work without a purchase.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Back to optional perks',
          icon: Icons.arrow_back,
          onPressed: () => context.go('/monetization'),
          style: MortButtonStyle.secondary,
        ),
      ],
    );
  }
}
