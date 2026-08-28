import 'package:flutter/material.dart';

import '../../../core/widgets/mort_widgets.dart';

class TeenPurchaseNotice extends StatelessWidget {
  const TeenPurchaseNotice({super.key, required this.show});

  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return const MortSafetyBanner(
      message: 'Ask your guardian before making purchases.',
    );
  }
}
