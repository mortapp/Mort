import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/utils/formatters.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import 'package:flutter_mort/features/payments/models/fair_pay.dart';

class MortFairPayPanel extends StatelessWidget {
  const MortFairPayPanel({super.key, required this.assessment});

  final MortFairPayAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final color = switch (assessment.status) {
      MortFairPayStatus.green => MortColors.paymentSuccess,
      MortFairPayStatus.yellow => MortColors.paymentWarning,
      MortFairPayStatus.red => MortColors.paymentDanger,
    };
    final label = assessment.status.name.toUpperCase();
    return Semantics(
      container: true,
      label: 'Fair Pay $label',
      child: MortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MortBadge(label: label, color: color, icon: Icons.balance_outlined),
            const SizedBox(height: 8),
            Text(
              'Recommended range: ${formatCents(assessment.recommendedFloorCents)} – ${formatCents(assessment.recommendedCeilingCents)}',
            ),
            Text('Entered base pay: ${formatCents(assessment.actualCents)}'),
            Text('Hard minimum: ${formatCents(assessment.hardMinimumCents)}'),
            const SizedBox(height: 8),
            Text(
              assessment.blocksContinue
                  ? 'This amount is below MORT’s hard minimum. Increase base pay before posting.'
                  : assessment.status == MortFairPayStatus.yellow
                  ? 'This amount is outside the recommended range and may require policy review.'
                  : 'This amount is within the recommended range.',
            ),
          ],
        ),
      ),
    );
  }
}
