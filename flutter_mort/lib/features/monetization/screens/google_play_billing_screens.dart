import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../data/google_play_billing.dart';
import '../widgets/monetization_disclaimer.dart';

class MortPlusView extends StatefulWidget {
  const MortPlusView({super.key});

  @override
  State<MortPlusView> createState() => _MortPlusViewState();
}

class _MortPlusViewState extends State<MortPlusView> {
  final controller = PurchaseController.instance;

  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
    controller.initialize();
    if (!AppConfig.supportsNativePurchases) controller.refresh();
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = controller.products
        .where((product) => product.id == mortPlusProductId)
        .toList();
    final oneTime = controller.products
        .where((product) => mortOneTimeProductIds.contains(product.id))
        .toList();
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Optional perks',
          title: 'MORT Plus',
          subtitle:
              'Cosmetic and convenience extras. Jobs, safety, reporting, basic Guardian Mode, and applying stay free.',
        ),
        const MonetizationDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        const MortPlusBenefitComparison(),
        const SizedBox(height: MortSpacing.md),
        _statePanel(),
        const SizedBox(height: MortSpacing.md),
        if (subscriptions.isNotEmpty) ...[
          const MortSectionTitle(
            title: 'Choose a Google Play plan',
            subtitle:
                'Prices and billing periods below come from Google Play. Subscriptions renew automatically until canceled in Google Play.',
          ),
          for (final product in subscriptions) ...[
            MortPlusPurchaseSheet(
              product: product,
              onPurchase: () => controller.buy(product),
              enabled: controller.state == PurchaseFlowState.ready,
            ),
            const SizedBox(height: MortSpacing.sm),
          ],
        ],
        if (oneTime.isNotEmpty) ...[
          const MortSectionTitle(
            title: 'Cosmetic packs',
            subtitle:
                'One-time purchases. They do not improve job or safety access.',
          ),
          CosmeticStoreView(
            products: oneTime,
            onPurchase: controller.buy,
            enabled: controller.state == PurchaseFlowState.ready,
          ),
        ],
        if (controller.missingProductIds.isNotEmpty) ...[
          const SizedBox(height: MortSpacing.md),
          MortCard(
            child: Text(
              'Some Play Console products are not active for this tester: ${controller.missingProductIds.join(', ')}. No fallback price is shown.',
            ),
          ),
        ],
        const SizedBox(height: MortSpacing.md),
        MortActionRow(
          actions: const [
            MortAction(
              label: 'Restore purchases',
              icon: Icons.restore,
              route: '/monetization/restore',
            ),
            MortAction(
              label: 'Manage subscription',
              icon: Icons.manage_accounts,
              route: '/monetization/manage',
            ),
          ],
        ),
      ],
    );
  }

  Widget _statePanel() => switch (controller.state) {
    PurchaseFlowState.loadingProducts => const MortLoading(
      label: 'Loading Google Play products...',
      fullScreen: false,
    ),
    PurchaseFlowState.pending || PurchaseFlowState.verifying =>
      MortPlusPendingView(message: controller.message),
    PurchaseFlowState.success => MortPlusSuccessView(
      message: controller.message,
    ),
    PurchaseFlowState.failed || PurchaseFlowState.cancelled =>
      MortPlusErrorView(message: controller.message),
    PurchaseFlowState.unavailable => MortCard(
      child: Text(
        controller.message ??
            'Google Play Billing is unavailable. Core MORT remains available.',
      ),
    ),
    _ => const SizedBox.shrink(),
  };
}

class MortPlusBenefitComparison extends StatelessWidget {
  const MortPlusBenefitComparison({super.key});

  @override
  Widget build(BuildContext context) => MortCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Free and Plus', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: MortSpacing.sm),
        const _BenefitLine(
          label: 'Browse, apply, post jobs, and message',
          free: true,
          plus: true,
        ),
        const _BenefitLine(
          label: 'Reports, blocking, Safety Ping, and appeals',
          free: true,
          plus: true,
        ),
        const _BenefitLine(
          label: 'Basic Guardian Mode and FAQ help',
          free: true,
          plus: true,
        ),
        const _BenefitLine(
          label: 'Premium themes, frames, and profile accents',
          free: false,
          plus: true,
        ),
        const _BenefitLine(
          label: 'Extra saved searches, alerts, and private charts',
          free: false,
          plus: true,
        ),
        const SizedBox(height: MortSpacing.sm),
        const Text(
          'MORT Plus gives no applicant ranking, job access, verification, moderation, dispute, or safety advantage.',
        ),
      ],
    ),
  );
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({
    required this.label,
    required this.free,
    required this.plus,
  });

  final String label;
  final bool free;
  final bool plus;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MortSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        SizedBox(
          width: 54,
          child: Icon(
            free ? Icons.check : Icons.remove,
            color: free ? MortColors.neon : MortColors.textMuted,
          ),
        ),
        SizedBox(
          width: 54,
          child: Icon(
            plus ? Icons.check : Icons.remove,
            color: plus ? MortColors.neon : MortColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class MortPlusPurchaseSheet extends StatelessWidget {
  const MortPlusPurchaseSheet({
    super.key,
    required this.product,
    required this.onPurchase,
    required this.enabled,
  });

  final ProductDetails product;
  final VoidCallback onPurchase;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final basePlan = _basePlan(product);
    final period = _billingPeriod(product);
    return MortPlanCard(
      title: basePlan == null
          ? product.title
          : '${product.title} - ${_basePlanLabel(basePlan)}',
      price: period == null
          ? product.price
          : '${product.price} / ${_periodLabel(period)}',
      features: const [
        'Automatic renewal until canceled in Google Play',
        'Optional recurring cosmetic and convenience benefits',
        'Core app, jobs, and safety remain free',
        'No free trial is promised',
      ],
      onPressed: enabled ? onPurchase : null,
    );
  }

  static String? _basePlan(ProductDetails product) {
    if (product is! GooglePlayProductDetails ||
        product.subscriptionIndex == null)
      return null;
    return product
        .productDetails
        .subscriptionOfferDetails![product.subscriptionIndex!]
        .basePlanId;
  }

  static String? _billingPeriod(ProductDetails product) {
    if (product is! GooglePlayProductDetails ||
        product.subscriptionIndex == null)
      return null;
    return product
        .productDetails
        .subscriptionOfferDetails![product.subscriptionIndex!]
        .pricingPhases
        .first
        .billingPeriod;
  }

  static String _basePlanLabel(String value) => switch (value) {
    'monthly-auto' => 'Monthly',
    'annual-auto' => 'Annual',
    _ => value.replaceAll('-', ' '),
  };

  static String _periodLabel(String value) => switch (value) {
    'P1M' => 'month',
    'P1Y' => 'year',
    _ => 'billing period',
  };
}

class MortPlusPendingView extends StatelessWidget {
  const MortPlusPendingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => MortCard(
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: MortSpacing.sm),
        Expanded(child: Text(message ?? 'Waiting for Google Play...')),
      ],
    ),
  );
}

class MortPlusSuccessView extends StatelessWidget {
  const MortPlusSuccessView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => MortCard(
    color: MortColors.neon.withValues(alpha: 0.1),
    child: Row(
      children: [
        const Icon(Icons.verified_outlined, color: MortColors.neon),
        const SizedBox(width: MortSpacing.sm),
        Expanded(child: Text(message ?? 'Purchase verified.')),
      ],
    ),
  );
}

class MortPlusErrorView extends StatelessWidget {
  const MortPlusErrorView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => MortErrorState(
    title: 'Purchase not completed',
    message: message ?? 'No perk was unlocked. Core MORT remains available.',
  );
}

class RestorePurchasesView extends StatefulWidget {
  const RestorePurchasesView({super.key});

  @override
  State<RestorePurchasesView> createState() => _RestorePurchasesViewState();
}

class _RestorePurchasesViewState extends State<RestorePurchasesView> {
  final controller = PurchaseController.instance;

  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Google Play',
        title: 'Restore purchases',
        subtitle:
            'MORT asks Google Play for purchases on this account and verifies each one on the server before restoring a perk.',
      ),
      MortButton(
        label: 'Restore from Google Play',
        icon: Icons.restore,
        busy:
            controller.state == PurchaseFlowState.pending ||
            controller.state == PurchaseFlowState.verifying,
        onPressed: AppConfig.supportsNativePurchases
            ? controller.restore
            : null,
      ),
      if (controller.message != null) ...[
        const SizedBox(height: MortSpacing.md),
        Text(controller.message!),
      ],
    ],
  );
}

class SubscriptionStatusView extends StatelessWidget {
  const SubscriptionStatusView({super.key, required this.entitlements});

  final Map<String, dynamic> entitlements;

  @override
  Widget build(BuildContext context) {
    final active = entitlements['entitlements'] as List<dynamic>? ?? const [];
    final review =
        entitlements['review_entitlements'] as List<dynamic>? ?? const [];
    return MortCard(
      child: Text(
        active.isNotEmpty
            ? 'Verified Google Play entitlements: ${active.length}'
            : review.isNotEmpty
            ? 'Synthetic Play review entitlement active. No financial record exists.'
            : 'No active MORT Plus entitlement.',
      ),
    );
  }
}

class ManageSubscriptionView extends StatelessWidget {
  const ManageSubscriptionView({super.key});

  @override
  Widget build(BuildContext context) => MortScreen(
    children: [
      const MortHeader(
        eyebrow: 'Google Play',
        title: 'Manage MORT Plus',
        subtitle:
            'Google Play controls renewal, cancellation, payment method, grace period, account hold, and subscription history.',
      ),
      SubscriptionStatusView(
        entitlements: PurchaseController.instance.entitlements,
      ),
      const SizedBox(height: MortSpacing.md),
      MortButton(
        label: 'Open Google Play subscriptions',
        icon: Icons.open_in_new,
        onPressed: () => ManageSubscriptionService().openGooglePlay(),
      ),
    ],
  );
}

class CosmeticStoreView extends StatelessWidget {
  const CosmeticStoreView({
    super.key,
    required this.products,
    required this.onPurchase,
    required this.enabled,
  });

  final List<ProductDetails> products;
  final ValueChanged<ProductDetails> onPurchase;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final product in products) ...[
        MortPlanCard(
          title: product.title,
          price: '${product.price} one-time',
          features: const [
            'Localized Google Play price',
            'Cosmetic only',
            'No job, safety, ranking, or verification advantage',
          ],
          onPressed: enabled ? () => onPurchase(product) : null,
        ),
        const SizedBox(height: MortSpacing.sm),
      ],
    ],
  );
}
