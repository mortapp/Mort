import 'package:flutter/material.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../widgets/monetization_disclaimer.dart';

class MonetizationHomeScreen extends StatelessWidget {
  const MonetizationHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Optional perks',
          title: 'Make MORT yours.',
          subtitle:
              'Free stays useful. Pro adds optional style, convenience, ad-free browsing, and personal analytics.',
        ),
        MonetizationDisclaimer(),
        SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: [
            MortAction(
              label: 'MORT Pro',
              icon: Icons.auto_awesome,
              route: '/monetization/paywall',
            ),
            MortAction(
              label: 'Ad-free',
              icon: Icons.visibility_off,
              route: '/monetization/ad-free',
            ),
            MortAction(
              label: 'Username token',
              icon: Icons.alternate_email,
              route: '/monetization/username-change',
            ),
            MortAction(
              label: 'Job boost',
              icon: Icons.rocket_launch,
              route: '/monetization/job-boost',
            ),
            MortAction(
              label: 'Restore',
              icon: Icons.restore,
              route: '/monetization/restore',
            ),
            MortAction(
              label: 'Manage',
              icon: Icons.manage_accounts,
              route: '/monetization/manage',
            ),
          ],
        ),
      ],
    );
  }
}
