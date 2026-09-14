import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/mort_colors.dart';
import '../../../core/theme/mort_spacing.dart';
import '../../../core/widgets/mort_widgets.dart';

/// Truthful availability screen for optional monetization products that have
/// no live store offering configured in this release.
///
/// Law: missing provider configuration is an EXTERNAL gate, but the honest
/// production UI is an INTERNAL requirement. These screens never fake prices,
/// purchase flows, entitlements, or availability dates, and never imply that
/// safety or core features require payment.
class ProductAvailabilityScreen extends StatelessWidget {
  const ProductAvailabilityScreen({
    super.key,
    required this.product,
    required this.title,
    required this.description,
    this.statusLabel = 'NOT CURRENTLY AVAILABLE',
    this.secondaryRoute,
    this.secondaryLabel,
  });

  final String product;
  final String title;
  final String description;
  final String statusLabel;
  final String? secondaryRoute;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'Optional perk',
          title: title,
          subtitle: 'The free MORT experience is not affected.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: MortColors.lightBlue,
                  ),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: MortColors.lightBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(description),
              const SizedBox(height: MortSpacing.xs),
              const Text(
                'No prices are shown because none are available from the store '
                'right now. Nothing on this page is purchasable yet.',
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        const MortSafetyBanner(
          message:
              'Safety, applying, messaging, reporting, blocking, and basic '
              'Guardian Mode never require payment.',
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Back to perks',
          icon: Icons.arrow_back,
          onPressed: () => context.go('/monetization'),
          style: MortButtonStyle.secondary,
        ),
        if (secondaryRoute != null) ...[
          const SizedBox(height: MortSpacing.xs),
          MortButton(
            label: secondaryLabel ?? 'Learn more',
            icon: Icons.arrow_outward_rounded,
            onPressed: () => context.go(secondaryRoute!),
            style: MortButtonStyle.secondary,
          ),
        ],
      ],
    );
  }
}
