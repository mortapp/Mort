import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/mort_colors.dart';
import '../theme/mort_spacing.dart';
import '../theme/mort_tokens.dart';
import 'mort_back_navigation.dart';

enum MortGlassVariant { regular, clear, soft }

class LiquidGlassContainer extends StatelessWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MortSpacing.md),
    this.borderRadius,
    this.variant = MortGlassVariant.regular,
    this.tint,
    this.liveBlur = false,
    this.allowAndroidBlur = false,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final MortGlassVariant variant;
  final Color? tint;
  final bool liveBlur;
  final bool allowAndroidBlur;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(MortRadii.card);
    final scheme = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = colorForSurface(scheme);
    final border = highContrast ? scheme.outline : scheme.outlineVariant;

    final card = Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: border, width: highContrast ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: MortSpacing.minTouchTarget,
                  minHeight: MortSpacing.minTouchTarget,
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: card,
    );
  }

  Color colorForSurface(ColorScheme scheme) {
    if (tint != null) return tint!;
    return switch (variant) {
      MortGlassVariant.regular => scheme.surface,
      MortGlassVariant.clear => scheme.surfaceContainerLowest,
      MortGlassVariant.soft => scheme.surfaceContainerHigh,
    };
  }
}

class MortGlassSoftSurface extends StatelessWidget {
  const MortGlassSoftSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MortSpacing.md),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LiquidGlassContainer(
    variant: MortGlassVariant.soft,
    padding: padding,
    onTap: onTap,
    child: child,
  );
}

class MortNavigationDestination {
  const MortNavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.accessibilityLabel,
    this.prominentAction = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? accessibilityLabel;
  final bool prominentAction;
}

class MortGlassNavigationBar extends StatelessWidget {
  const MortGlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final List<MortNavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    assert(currentIndex >= 0 && currentIndex < destinations.length);
    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      height: 76,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.onSurface.withValues(alpha: 0.10),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            tooltip: destination.accessibilityLabel ?? destination.label,
            label: destination.label,
            icon: _navigationIcon(destination, scheme, selected: false),
            selectedIcon: _navigationIcon(destination, scheme, selected: true),
          ),
      ],
    );
  }

  Widget _navigationIcon(
    MortNavigationDestination destination,
    ColorScheme scheme, {
    required bool selected,
  }) {
    if (destination.prominentAction) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: scheme.onSurface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(destination.icon, size: 22, color: scheme.surface),
      );
    }
    return Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 22,
    );
  }
}

class MortGlassHeader extends StatelessWidget {
  const MortGlassHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.showBack,
    this.onBack,
    this.backFallbackRoute,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  // Null auto-detects (matching MortHeader): shown whenever there is
  // something to pop, or this location isn't a known shell root. A screen
  // that forgets to wire up an explicit back button no longer strands the
  // user with no way out -- pass true/false to override when needed.
  final bool? showBack;
  final VoidCallback? onBack;
  final String? backFallbackRoute;

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.maybeOf(context)?.state.uri.path ?? '/';
    final resolvedShowBack =
        showBack ??
        ((Navigator.maybeOf(context)?.canPop() ?? false) ||
            !MortBackNavigation.isRootLocation(location));
    return LiquidGlassContainer(
      liveBlur: true,
      allowAndroidBlur: true,
      borderRadius: BorderRadius.circular(MortRadii.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resolvedShowBack) ...[
            if (onBack != null)
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                constraints: const BoxConstraints.tightFor(
                  width: MortSpacing.minTouchTarget,
                  height: MortSpacing.minTouchTarget,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              MortBackButton(
                fallbackRoute:
                    backFallbackRoute ??
                    MortBackNavigation.fallbackRoute(location),
              ),
            const SizedBox(width: MortSpacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow?.isNotEmpty == true) ...[
                  Text(
                    eyebrow!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: MortSpacing.xxs),
                ],
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: MortSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MortSpacing.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class MortGlassButton extends StatelessWidget {
  const MortGlassButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.primary = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final scheme = Theme.of(context).colorScheme;
    final background = danger
        ? scheme.error
        : primary
        ? scheme.primary
        : scheme.surfaceContainerHigh;
    final foreground = danger
        ? scheme.onError
        : primary
        ? scheme.onPrimary
        : scheme.onSurface;
    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: LiquidGlassContainer(
        tint: background,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(MortRadii.medium),
        onTap: onPressed,
        semanticLabel: label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MortSpacing.fieldHeight,
            minWidth: MortSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MortSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: MortSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MortSegmentOption<T> {
  const MortSegmentOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

class MortSegmentedControl<T> extends StatelessWidget {
  const MortSegmentedControl({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<MortSegmentOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    assert(options.isNotEmpty);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return LiquidGlassContainer(
      variant: MortGlassVariant.soft,
      padding: const EdgeInsets.all(MortSpacing.xxs),
      borderRadius: BorderRadius.circular(MortRadii.pill),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: option.value == value,
                label: option.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(MortRadii.pill),
                  onTap: () => onChanged(option.value),
                  child: AnimatedContainer(
                    duration: disableAnimations
                        ? Duration.zero
                        : MortMotion.standard,
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(
                      minHeight: MortSpacing.fieldHeight,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: MortSpacing.sm,
                      vertical: MortSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: option.value == value
                          ? MortColors.roseGold.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(MortRadii.pill),
                      border: option.value == value
                          ? Border.all(
                              color: MortColors.roseGold.withValues(alpha: 0.5),
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option.icon,
                          size: 18,
                          color: option.value == value
                              ? MortColors.roseGoldLight
                              : MortColors.silver,
                        ),
                        const SizedBox(width: MortSpacing.xs),
                        Flexible(
                          child: Text(
                            option.label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: option.value == value
                                      ? MortColors.roseGoldLight
                                      : MortColors.silver,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MortChip extends StatelessWidget {
  const MortChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    avatar: icon == null ? null : Icon(icon, size: 16),
    selected: selected,
    onSelected: onSelected,
    showCheckmark: false,
    selectedColor: MortColors.roseGold.withValues(alpha: 0.22),
    backgroundColor: MortColors.glass,
    side: BorderSide(
      color: selected
          ? MortColors.roseGold.withValues(alpha: 0.5)
          : MortColors.lineStrong,
    ),
    labelStyle: TextStyle(
      color: selected ? MortColors.roseGoldLight : MortColors.silver,
      fontWeight: FontWeight.w600,
    ),
  );
}

class MortStatusPill extends StatelessWidget {
  const MortStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MortSpacing.sm,
        vertical: MortSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(MortRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.circle, size: icon == null ? 8 : 15, color: color),
          const SizedBox(width: MortSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

class MortSectionLabel extends StatelessWidget {
  const MortSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: MortSpacing.lg, bottom: MortSpacing.sm),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: MortColors.textDisabled,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class MortDashboardActionTile extends StatelessWidget {
  const MortDashboardActionTile({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? 0.62 : 1,
    child: MortGlassSoftSurface(
      onTap: onPressed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: MortSpacing.minTouchTarget,
            height: MortSpacing.minTouchTarget,
            decoration: BoxDecoration(
              color: MortColors.lightBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(MortRadii.medium),
            ),
            child: Icon(icon, color: MortColors.lightBlue),
          ),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MortSpacing.xxs),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: MortSpacing.xs),
          if (onPressed != null)
            const Icon(Icons.chevron_right_rounded, color: MortColors.silver),
        ],
      ),
    ),
  );
}

class MortSafetyPulse extends StatelessWidget {
  const MortSafetyPulse({
    super.key,
    required this.title,
    required this.status,
    this.icon = Icons.shield_rounded,
    this.color = MortColors.lightBlue,
    this.onPressed,
  });

  final String title;
  final String status;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 224, minWidth: 220),
      child: LiquidGlassContainer(
        tint: color,
        borderRadius: BorderRadius.circular(MortRadii.pill),
        onTap: onPressed,
        semanticLabel: '$title. $status',
        child: Padding(
          padding: const EdgeInsets.all(MortSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: color),
              const SizedBox(height: MortSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MortSpacing.xs),
              Text(
                status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MortConfirmationState extends StatelessWidget {
  const MortConfirmationState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => MortGlassSoftSurface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, color: MortColors.success),
        const SizedBox(width: MortSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: MortSpacing.xxs),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}
