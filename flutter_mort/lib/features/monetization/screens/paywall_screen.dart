import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/providers.dart';
import '../providers/revenuecat_providers.dart';
import '../widgets/monetization_disclaimer.dart';
import '../widgets/mort_pro_paywall_content.dart';
import '../widgets/teen_purchase_notice.dart';

class RevenueCatPaywallScreen extends ConsumerWidget {
  const RevenueCatPaywallScreen({
    super.key,
    this.placement = 'main',
    this.title = 'Optional MORT perks',
    this.subtitle =
        'The free experience remains available. MORT Pro adds optional style and convenience.',
  });

  final String placement;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final isTeen = profile?.role == UserRole.teen;

    if (placement == 'main' || placement == 'ad-free') {
      return _MortProPaywall(isTeen: isTeen);
    }

    return MortScreen(
      children: [
        MortHeader(eyebrow: 'Optional perks', title: title, subtitle: subtitle),
        const MonetizationDisclaimer(),
        const SizedBox(height: MortSpacing.md),
        TeenPurchaseNotice(show: isTeen),
        if (isTeen) const SizedBox(height: MortSpacing.md),
        _PaywallValueCard(placement: placement),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'No safety, applying, messaging, reporting, blocking, or basic Guardian Mode feature requires payment.',
        ),
        if (placement == 'username-change') ...[
          const SizedBox(height: MortSpacing.md),
          const _UsernameBackendStatusCard(),
        ],
        if (placement == 'job-boost') ...[
          const SizedBox(height: MortSpacing.md),
          const _JobBoostBackendStatusCard(),
        ],
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Keep using MORT',
          icon: Icons.arrow_back,
          onPressed: () => context.go('/account-status'),
          style: MortButtonStyle.secondary,
        ),
      ],
    );
  }
}

class _MortProPaywall extends ConsumerStatefulWidget {
  const _MortProPaywall({required this.isTeen});

  final bool isTeen;

  @override
  ConsumerState<_MortProPaywall> createState() => _MortProPaywallState();
}

class _MortProPaywallState extends ConsumerState<_MortProPaywall> {
  bool _busy = false;
  String? _message;

  Future<void> _purchasePackage(rc.Package package) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(purchaseControllerProvider)
        .purchasePackage(package);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result.message;
    });
  }

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

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/monetization');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(revenueCatStatusProvider).asData?.value;
    final offeringState = ref.watch(currentOfferingProvider);
    final offering = offeringState.asData?.value;
    final proState = ref.watch(isMortProProvider);
    final isPro = proState.asData?.value == true;
    const labels = <String, String>{
      r'$rc_weekly': 'Weekly',
      r'$rc_monthly': 'Monthly',
      r'$rc_annual': 'Annual',
      r'$rc_lifetime': 'Lifetime',
    };
    final packages = <String, rc.Package>{};
    for (final id in labels.keys) {
      final package = offering?.getPackage(id);
      if (package != null) packages[id] = package;
    }
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: MortColors.ink2,
        body: MortProPaywallContent(
          plans: [
            for (final entry in packages.entries)
              MortProPlan(
                id: entry.key,
                name: labels[entry.key]!,
                price: entry.value.storeProduct.priceString,
              ),
          ],
          loading: offeringState.isLoading || proState.isLoading,
          busy: _busy,
          isPro: isPro,
          isTeen: widget.isTeen,
          message:
              _message ??
              (offeringState.isLoading ||
                      proState.isLoading ||
                      isPro ||
                      packages.isNotEmpty ||
                      status?.available == true
                  ? null
                  : status?.message),
          onPurchase: (id) {
            final package = packages[id];
            if (package != null) _purchasePackage(package);
          },
          onRestore: _restore,
          onRetry: () {
            ref.invalidate(offeringsProvider);
            ref.invalidate(currentOfferingProvider);
            ref.invalidate(revenueCatStatusProvider);
          },
          onClose: _close,
          onTerms: () => context.push('/legal/terms'),
          onPrivacy: () => context.push('/legal/privacy'),
        ),
      ),
    );
  }
}

class _PaywallValueCard extends StatelessWidget {
  const _PaywallValueCard({required this.placement});

  final String placement;

  @override
  Widget build(BuildContext context) {
    final items = switch (placement) {
      'ad-free' => const [
        'MORT Pro hides eligible browse ads.',
        'Safety messages, report, block, and Safety Ping always remain free.',
      ],
      'username-change' => const [
        'Three username changes are available before a credit is needed.',
        'Paid username credits cannot be purchased in this release.',
      ],
      'job-boost' => const [
        'Job boosts never bypass account eligibility, moderation, or safety review.',
        'Paid job boosts cannot be purchased in this release.',
      ],
      _ => const [
        'Core MORT features remain available without a subscription.',
        'No safety feature is locked behind a paid plan.',
        'MORT Pro is optional and does not change XP, rank, or job priority.',
      ],
    };

    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: MortSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: MortColors.accent,
                  ),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UsernameBackendStatusCard extends ConsumerWidget {
  const _UsernameBackendStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(usernameChangeStatusProvider);
    return status.when(
      loading: () => const MortSkeletonCard(),
      error: (error, _) => const MortErrorState(
        title: 'Username status unavailable',
        message: 'Check your connection and try again from username settings.',
      ),
      data: (data) {
        final freeRemaining = data['free_changes_remaining'] ?? 0;
        final tokenCredits = data['token_credits'] ?? 0;
        final adminCredits = data['admin_credits'] ?? 0;
        return MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Username changes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(
                'Free remaining: $freeRemaining. Existing credits: ${tokenCredits + adminCredits}.',
              ),
              const SizedBox(height: MortSpacing.xs),
              const Text('New paid credits cannot be added in this release.'),
            ],
          ),
        );
      },
    );
  }
}

class _JobBoostBackendStatusCard extends ConsumerWidget {
  const _JobBoostBackendStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(jobBoostCreditStatusProvider);
    return status.when(
      loading: () => const MortSkeletonCard(),
      error: (error, _) => const MortErrorState(
        title: 'Job boost status unavailable',
        message: 'Check your connection and try again from job management.',
      ),
      data: (data) {
        final available = data['available_credits'] ?? 0;
        final used = data['used_credits'] ?? 0;
        return MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job boost credits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.xs),
              Text('Existing credits: $available. Used: $used.'),
              const SizedBox(height: MortSpacing.xs),
              const Text('New paid boosts cannot be added in this release.'),
            ],
          ),
        );
      },
    );
  }
}
