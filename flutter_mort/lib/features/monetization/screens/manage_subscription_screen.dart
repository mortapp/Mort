import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';

class ManageSubscriptionScreen extends StatelessWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Optional perks',
          title: 'Subscriptions unavailable',
          subtitle:
              'Subscriptions and in-app purchases are not available right now.',
        ),
        const MortSafetyBanner(
          message:
              'MORT does not process, hold, guarantee, or escrow job payments. Job payment preferences are separate from app-store purchases.',
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
