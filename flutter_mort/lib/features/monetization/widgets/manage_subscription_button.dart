import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/mort_widgets.dart';

class ManageSubscriptionButton extends StatelessWidget {
  const ManageSubscriptionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return MortButton(
      label: 'Manage subscription',
      icon: Icons.manage_accounts,
      style: MortButtonStyle.secondary,
      onPressed: () => context.go('/monetization/manage'),
    );
  }
}
