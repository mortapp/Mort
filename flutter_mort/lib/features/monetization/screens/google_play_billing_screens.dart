import 'package:flutter/material.dart';

import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';

class MortPlusView extends StatelessWidget {
  const MortPlusView({super.key});

  @override
  Widget build(BuildContext context) => const _PurchasesDisabledScreen();
}

class RestorePurchasesView extends StatelessWidget {
  const RestorePurchasesView({super.key});

  @override
  Widget build(BuildContext context) => const _PurchasesDisabledScreen();
}

class ManageSubscriptionView extends StatelessWidget {
  const ManageSubscriptionView({super.key});

  @override
  Widget build(BuildContext context) => const _PurchasesDisabledScreen();
}

class SubscriptionStatusView extends StatelessWidget {
  const SubscriptionStatusView({super.key, required this.entitlements});

  final Map<String, dynamic> entitlements;

  @override
  Widget build(BuildContext context) => const MortCard(
    child: Text(
      'This release has no Google Play products, subscriptions, or purchase restoration.',
    ),
  );
}

class _PurchasesDisabledScreen extends StatelessWidget {
  const _PurchasesDisabledScreen();

  @override
  Widget build(BuildContext context) => const MortScreen(
    children: [
      MortHeader(
        eyebrow: 'Free experience',
        title: 'Purchases are not offered',
        subtitle:
            'MORT jobs, applications, messaging, reports, blocking, Safety Ping, and basic Guardian Mode remain available without an upgrade.',
      ),
      MortCard(
        child: Text(
          'This build does not include Google Play Billing. It cannot charge, restore, or manage a purchase.',
        ),
      ),
      SizedBox(height: MortSpacing.md),
      MortPaymentDisclaimer(),
    ],
  );
}
