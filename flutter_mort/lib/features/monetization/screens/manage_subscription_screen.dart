import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../providers/revenuecat_providers.dart';

class ManageSubscriptionScreen extends ConsumerStatefulWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  ConsumerState<ManageSubscriptionScreen> createState() =>
      _ManageSubscriptionScreenState();
}

class _ManageSubscriptionScreenState
    extends ConsumerState<ManageSubscriptionScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _openCustomerCenter() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(purchaseControllerProvider)
        .presentCustomerCenter();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(revenueCatStatusProvider).asData?.value;
    final isPro = ref.watch(isMortProProvider).asData?.value == true;
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Optional perks',
          title: 'Manage MORT Pro',
          subtitle: isPro
              ? 'MORT Pro is active on this account.'
              : 'View plan status, support, and restoration options.',
        ),
        const MortSafetyBanner(
          message:
              'Store subscriptions are separate from real-world job payments. Core safety and marketplace access remain free.',
        ),
        const SizedBox(height: MortSpacing.md),
        if (_message != null) ...[
          MortCard(child: Text(_message!)),
          const SizedBox(height: MortSpacing.md),
        ],
        MortButton(
          label: _busy ? 'Opening...' : 'Manage subscription',
          icon: Icons.manage_accounts,
          onPressed: _busy || status?.available != true
              ? null
              : _openCustomerCenter,
          style: status?.available == true
              ? MortButtonStyle.primary
              : MortButtonStyle.disabled,
        ),
        if (status?.available != true) ...[
          const SizedBox(height: MortSpacing.sm),
          Text(status?.message ?? 'Checking subscription availability...'),
        ],
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Back to optional perks',
          icon: Icons.arrow_back,
          onPressed: () => context.go('/monetization'),
          style: MortButtonStyle.secondary,
        ),
      ],
    );
  }
}
