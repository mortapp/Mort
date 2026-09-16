import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_spacing.dart';
import 'package:flutter_mort/core/utils/formatters.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import '../models/fair_pay.dart';
import '../models/payment_state.dart';
import '../models/tipping.dart';
import '../widgets/fair_pay_panel.dart';
import '../widgets/payment_state_panel.dart';
import '../widgets/tip_selector.dart';

class PaymentReviewUnavailableScreen extends StatelessWidget {
  const PaymentReviewUnavailableScreen({super.key, this.contractId});

  final String? contractId;

  @override
  Widget build(BuildContext context) {
    return const MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Payment review',
          title: 'Payment details unavailable',
          subtitle:
              'MORT needs an authoritative job payment quote before showing a payable review.',
        ),
        MortErrorState(
          title: 'Payment details unavailable',
          message:
              'No authorized quote is available for this job. No payment action is enabled.',
        ),
      ],
    );
  }
}

class PaymentReviewScreen extends StatefulWidget {
  const PaymentReviewScreen({
    super.key,
    required this.basePayCents,
    required this.serviceFeeCents,
    this.jobTitle = 'Job payment',
    this.initialState = MortPaymentState.ready,
    this.fairPay,
    this.authoritativeTotalCents,
    this.paymentContextAvailable = true,
  });

  final int basePayCents;
  final int serviceFeeCents;
  final String jobTitle;
  final MortPaymentState initialState;
  final MortFairPayAssessment? fairPay;
  final int? authoritativeTotalCents;
  final bool paymentContextAvailable;

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  MortTipSelection _tip = const MortTipSelection(
    preset: MortTipPreset.none,
    amountCents: 0,
  );

  @override
  Widget build(BuildContext context) {
    final previewTotal =
        widget.basePayCents + widget.serviceFeeCents + _tip.amountCents;
    return MortScreen(
      children: [
        MortHeader(eyebrow: 'Payment review', title: widget.jobTitle),
        MortCard(
          child: Column(
            children: [
              _row('JOB', widget.jobTitle),
              _row('SERVICE', 'Authoritative service payment'),
              _row('BASE PAY', formatCents(widget.basePayCents)),
              _row('TIP', formatCents(_tip.amountCents)),
              _row('MORT SERVICE FEE', formatCents(widget.serviceFeeCents)),
              const Divider(),
              _row(
                widget.authoritativeTotalCents == null
                    ? 'PREVIEW TOTAL'
                    : 'TOTAL',
                formatCents(widget.authoritativeTotalCents ?? previewTotal),
                strong: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortTipSelector(
          basePayCents: widget.basePayCents,
          onChanged: (value) => setState(() => _tip = value),
        ),
        if (widget.fairPay != null) ...[
          const SizedBox(height: MortSpacing.md),
          MortFairPayPanel(assessment: widget.fairPay!),
        ],
        const SizedBox(height: MortSpacing.md),
        if (!widget.paymentContextAvailable)
          const MortErrorState(
            title: 'Payment details unavailable',
            message:
                'An authoritative job payment quote is required before continuing.',
          )
        else
          MortPaymentStatePanel(state: widget.initialState),
      ],
    );
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final valueText = Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: stacked ? TextAlign.left : TextAlign.right,
          style: strong ? const TextStyle(fontWeight: FontWeight.w900) : null,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(label), valueText],
                )
              : Row(
                  children: [
                    Expanded(child: Text(label)),
                    Flexible(child: valueText),
                  ],
                ),
        );
      },
    );
  }
}
