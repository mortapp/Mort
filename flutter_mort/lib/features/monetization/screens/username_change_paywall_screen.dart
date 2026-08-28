import 'package:flutter/material.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import 'paywall_screen.dart';

class UsernameChangePaywallScreen extends RevenueCatPaywallScreen {
  const UsernameChangePaywallScreen({super.key})
    : super(
        placement: 'username-change',
        title: 'Need another username change?',
        subtitle:
            'You used your 3 free username changes. Grab a cheap username change token if you want. Your account still works if you do not pay.',
      );
}

class UsernameChangeExplainer extends StatelessWidget {
  const UsernameChangeExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Changing your name is optional.'),
          SizedBox(height: MortSpacing.xs),
          Text(
            'MORT Plus allowance, username token, or admin credit can unlock more changes after the free three.',
          ),
        ],
      ),
    );
  }
}
