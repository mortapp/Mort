import 'package:flutter/material.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';

class MonetizationDisclaimer extends StatelessWidget {
  const MonetizationDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortSafetyBanner(
      message:
          'Safety tools stay free. Basic job applying stays free. Guardian Mode basics stay free. Report, block, and Safety Ping stay free.',
    );
  }
}

class MonetizationFinePrint extends StatelessWidget {
  const MonetizationFinePrint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MortSpacing.sm),
      child: Text(
        'Paid plans and prices are unavailable because app-store purchases are not included in this release.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
