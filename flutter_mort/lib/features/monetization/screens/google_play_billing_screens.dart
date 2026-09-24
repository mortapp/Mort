import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../providers/revenuecat_providers.dart';
import 'manage_subscription_screen.dart';
import 'paywall_screen.dart';

class MortPlusView extends RevenueCatPaywallScreen {
  const MortPlusView({super.key})
    : super(
        title: 'MORT Pro',
        subtitle: 'Optional style and convenience. The core stays free.',
      );
}

class RestorePurchasesView extends ConsumerStatefulWidget {
  const RestorePurchasesView({super.key});

  @override
  ConsumerState<RestorePurchasesView> createState() =>
      _RestorePurchasesViewState();
}

class _RestorePurchasesViewState extends ConsumerState<RestorePurchasesView> {
  bool _busy = false;
  String? _message;

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(purchaseControllerProvider)
        .restorePurchases();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(revenueCatStatusProvider).asData?.value;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Optional perks',
          title: 'Restore purchases',
          subtitle: 'Check this account for an active MORT Pro purchase.',
        ),
        const MortPaymentDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        if (_message != null) MortCard(child: Text(_message!)),
        if (_message != null) const SizedBox(height: MortSpacing.md),
        MortButton(
          label: _busy ? 'Checking purchases...' : 'Restore purchases',
          icon: Icons.restore,
          onPressed: _busy || status?.available != true ? null : _restore,
          style: status?.available == true
              ? MortButtonStyle.primary
              : MortButtonStyle.disabled,
        ),
        if (status?.available != true) ...[
          const SizedBox(height: MortSpacing.sm),
          Text(status?.message ?? 'Checking purchase availability...'),
        ],
      ],
    );
  }
}

class ManageSubscriptionView extends ManageSubscriptionScreen {
  const ManageSubscriptionView({super.key});
}

class SubscriptionStatusView extends ConsumerWidget {
  const SubscriptionStatusView({super.key, required this.entitlements});

  final Map<String, dynamic> entitlements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isMortProProvider).asData?.value == true;
    return MortCard(
      child: Text(
        isPro
            ? 'MORT Pro is active on this account.'
            : 'MORT Pro is not active on this account.',
      ),
    );
  }
}
