import 'package:flutter/material.dart';
import '../../../core/widgets/mort_widgets.dart';

class RestorePurchasesButton extends StatelessWidget {
  const RestorePurchasesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortButton(
      label: 'Purchases not included',
      icon: Icons.block,
      style: MortButtonStyle.disabled,
      onPressed: null,
    );
  }
}
