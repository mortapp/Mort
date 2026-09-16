import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_spacing.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';
import '../models/payment_state.dart';

class MortPaymentStatePanel extends StatelessWidget {
  const MortPaymentStatePanel({
    super.key,
    required this.state,
    this.reason,
    this.onPrimaryAction,
    this.onViewReceipt,
  });

  final MortPaymentState state;
  final String? reason;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final actionLabel = switch (state) {
      MortPaymentState.unknown => 'Check status',
      MortPaymentState.requiresAction => 'Complete required action',
      MortPaymentState.succeeded => 'View receipt',
      _ => null,
    };
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MortPaymentStateBadge(state: state),
          const SizedBox(height: MortSpacing.sm),
          Text(_title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(reason ?? _copy),
          if (state == MortPaymentState.duplicateBlocked)
            const Padding(
              padding: EdgeInsets.only(top: MortSpacing.sm),
              child: Text(
                'Do not start another charge. MORT is protecting you from a duplicate payment.',
              ),
            ),
          if (actionLabel != null) ...[
            const SizedBox(height: MortSpacing.md),
            if (state == MortPaymentState.succeeded && onViewReceipt != null ||
                state != MortPaymentState.succeeded && onPrimaryAction != null)
              MortButton(
                label: actionLabel,
                icon: state == MortPaymentState.succeeded
                    ? Icons.receipt_long_outlined
                    : Icons.refresh,
                onPressed: state == MortPaymentState.succeeded
                    ? onViewReceipt
                    : onPrimaryAction,
              ),
          ],
        ],
      ),
    );
  }

  String get _title => switch (state) {
    MortPaymentState.ready => 'Ready to pay',
    MortPaymentState.processing => 'Payment processing',
    MortPaymentState.requiresAction => 'Action required',
    MortPaymentState.pending => 'Payment pending',
    MortPaymentState.succeeded => 'Payment succeeded',
    MortPaymentState.declined => 'Payment declined',
    MortPaymentState.failed => 'Payment failed',
    MortPaymentState.cancelled => 'Payment cancelled',
    MortPaymentState.unknown => 'Payment status unknown',
    MortPaymentState.providerUnavailable => 'Payments unavailable',
    MortPaymentState.duplicateBlocked => 'Duplicate payment blocked',
  };

  String get _copy => switch (state) {
    MortPaymentState.ready =>
      'Review the authoritative amount before continuing.',
    MortPaymentState.processing =>
      'Do not close MORT or submit another payment.',
    MortPaymentState.requiresAction =>
      'Complete the provider-required step before MORT can confirm payment.',
    MortPaymentState.pending =>
      'MORT has not received a completed confirmation yet.',
    MortPaymentState.succeeded =>
      'The backend confirmed this payment. A receipt may now be available.',
    MortPaymentState.declined =>
      'The provider declined this attempt. No receipt was issued.',
    MortPaymentState.failed =>
      'This payment attempt failed. No receipt was issued.',
    MortPaymentState.cancelled =>
      'This payment was cancelled. No receipt was issued.',
    MortPaymentState.unknown =>
      'MORT cannot safely determine the final provider state.',
    MortPaymentState.providerUnavailable =>
      'Payment provider capability is not enabled for this environment.',
    MortPaymentState.duplicateBlocked =>
      'A matching attempt already exists and another charge is blocked.',
  };
}
