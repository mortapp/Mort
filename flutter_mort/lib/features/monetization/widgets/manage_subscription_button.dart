import 'package:flutter/material.dart';
import '../../../core/widgets/mort_widgets.dart';

class ManageSubscriptionButton extends StatelessWidget {
  const ManageSubscriptionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortButton(
      label: 'Subscriptions unavailable',
      icon: Icons.block,
      style: MortButtonStyle.disabled,
      onPressed: null,
    );
  }
}
