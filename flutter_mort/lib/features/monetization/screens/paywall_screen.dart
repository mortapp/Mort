import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/providers.dart';
import '../providers/revenuecat_providers.dart';
import '../widgets/monetization_disclaimer.dart';
import '../widgets/teen_purchase_notice.dart';

class RevenueCatPaywallScreen extends ConsumerWidget {
  const RevenueCatPaywallScreen({
    super.key,
    this.placement = 'main',
    this.title = 'Optional MORT perks',
    this.subtitle = 'The free experience remains available. Optional purchases are not available right now.',
  });

  final String placement;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final isTeen = profile?.role == UserRole.teen;

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
          message: 'Purchases and paid subscriptions are disabled for this release. No safety, applying, messaging, reporting, blocking, or basic Guardian Mode feature requires payment.',
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

class _PaywallValueCard extends StatelessWidget {
  const _PaywallValueCard({required this.placement});

  final String placement;

  @override
  Widget build(BuildContext context) {
    final items = switch (placement) {
      'ad-free' => const [
        'No ads are bundled or displayed in this release.',
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
        'Optional paid perks may return in a later, separately reviewed release.',
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
                    color: MortColors.neon,
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
