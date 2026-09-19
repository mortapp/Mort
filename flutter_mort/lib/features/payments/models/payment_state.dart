import 'package:flutter/material.dart';
import 'package:flutter_mort/core/theme/mort_colors.dart';
import 'package:flutter_mort/core/widgets/mort_widgets.dart';

enum MortPaymentState {
  ready,
  processing,
  requiresAction,
  pending,
  succeeded,
  declined,
  failed,
  cancelled,
  unknown,
  providerUnavailable,
  duplicateBlocked,
}

extension MortPaymentStateX on MortPaymentState {
  String get label => switch (this) {
    MortPaymentState.ready => 'Ready',
    MortPaymentState.processing => 'Processing',
    MortPaymentState.requiresAction => 'Requires action',
    MortPaymentState.pending => 'Pending',
    MortPaymentState.succeeded => 'Succeeded',
    MortPaymentState.declined => 'Declined',
    MortPaymentState.failed => 'Failed',
    MortPaymentState.cancelled => 'Cancelled',
    MortPaymentState.unknown => 'Unknown',
    MortPaymentState.providerUnavailable => 'Provider unavailable',
    MortPaymentState.duplicateBlocked => 'Duplicate blocked',
  };

  IconData get icon => switch (this) {
    MortPaymentState.ready => Icons.check_circle_outline_rounded,
    MortPaymentState.processing => Icons.autorenew_rounded,
    MortPaymentState.requiresAction => Icons.warning_amber_rounded,
    MortPaymentState.pending => Icons.pending_rounded,
    MortPaymentState.succeeded => Icons.check_circle_rounded,
    MortPaymentState.declined => Icons.cancel_outlined,
    MortPaymentState.failed => Icons.error_outline_rounded,
    MortPaymentState.cancelled => Icons.block_rounded,
    MortPaymentState.unknown => Icons.help_outline_rounded,
    MortPaymentState.providerUnavailable => Icons.cloud_off_rounded,
    MortPaymentState.duplicateBlocked => Icons.verified_outlined,
  };

  Color get color => switch (this) {
    MortPaymentState.ready => MortColors.paymentInfo,
    MortPaymentState.processing => MortColors.paymentWarning,
    MortPaymentState.requiresAction => MortColors.paymentWarning,
    MortPaymentState.pending => MortColors.paymentInfo,
    MortPaymentState.succeeded => MortColors.paymentSuccess,
    MortPaymentState.declined => MortColors.paymentDanger,
    MortPaymentState.failed => MortColors.paymentDanger,
    MortPaymentState.cancelled => MortColors.paymentDanger,
    MortPaymentState.unknown => MortColors.paymentSilverLow,
    MortPaymentState.providerUnavailable => MortColors.paymentWarning,
    MortPaymentState.duplicateBlocked => MortColors.paymentInfo,
  };

  String get semanticLabel => 'Payment state $label';

  bool get isTerminal => switch (this) {
    MortPaymentState.succeeded => true,
    MortPaymentState.declined => true,
    MortPaymentState.failed => true,
    MortPaymentState.cancelled => true,
    _ => false,
  };
}

class MortPaymentStateBadge extends StatelessWidget {
  const MortPaymentStateBadge({super.key, required this.state, this.child});

  final MortPaymentState state;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return MortPaymentStatusBadge(
      label: state.label,
      color: state.color,
      icon: state.icon,
      semanticLabel: state.semanticLabel,
    );
  }
}
