import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../preferences/mort_experience_preferences.dart';
import '../theme/mort_colors.dart';
import '../theme/mort_spacing.dart';
import '../theme/mort_tokens.dart';

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

  bool _useLiveBlur(BuildContext context) {
    final preferences = MortExperiencePreferencesScope.of(context);
    if (!liveBlur ||
        kIsWeb ||
        MediaQuery.highContrastOf(context) ||
        preferences.reducedTransparency) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.android && !allowAndroidBlur) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(MortRadii.card);
    final highContrast = MediaQuery.highContrastOf(context);
    final blur = _useLiveBlur(context);
    final base = switch (variant) {
      MortGlassVariant.regular => MortColors.bgElevated,
      MortGlassVariant.clear => Colors.white,
      MortGlassVariant.soft => MortColors.cardAlt,
    };
    final baseAlpha = highContrast
        ? 1.0
        : blur
        ? switch (variant) {
            MortGlassVariant.regular => 0.2,
            MortGlassVariant.clear => 0.08,
            MortGlassVariant.soft => 0.16,
          }
        : switch (variant) {
            MortGlassVariant.regular => 0.92,
            MortGlassVariant.clear => 0.82,
            MortGlassVariant.soft => 0.84,
          };
    final effectiveTint = tint ?? base;
    final borderColor = highContrast
        ? MortColors.silver
        : Color.lerp(
            Colors.white.withValues(alpha: 0.14),
            effectiveTint.withValues(alpha: 0.44),
            tint == null ? 0.0 : 0.58,
          )!;

    Widget surface = Stack(
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  base,
                  effectiveTint,
                  tint == null ? 0 : 0.34,
                )!.withValues(alpha: baseAlpha),
                base.withValues(alpha: (baseAlpha - 0.08).clamp(0.0, 1.0)),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: const Alignment(0.25, 0.25),
                  colors: [
                    Colors.white.withValues(alpha: highContrast ? 0.02 : 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (blur) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: MortGlassTokens.blurSigma,
          sigmaY: MortGlassTokens.blurSigma,
        ),
        child: surface,
      );
    }

    surface = ClipRRect(borderRadius: radius, child: surface);
    surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: borderColor,
          width: highContrast ? 1.5 : MortGlassTokens.borderWidth,
        ),
        boxShadow: MortShadows.card,
      ),
      child: surface,
    );

    if (onTap != null) {
      surface = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          splashColor: MortColors.roseGold.withValues(alpha: 0.12),
          highlightColor: MortColors.roseGoldLight.withValues(alpha: 0.06),
          child: surface,
        ),
      );
    }

    return RepaintBoundary(
      child: Semantics(
        label: semanticLabel,
        button: onTap != null,
        container: true,
        child: surface,
      ),
    );
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
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        MortSpacing.md,
        MortSpacing.xs,
        MortSpacing.md,
        MortSpacing.xs,
      ),
      child: LiquidGlassContainer(
        liveBlur: true,
        allowAndroidBlur: true,
        borderRadius: BorderRadius.circular(MortRadii.sheet),
        padding: const EdgeInsets.all(MortSpacing.xxs),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: Semantics(
                  selected: currentIndex == index,
                  button: true,
                  label: destinations[index].label,
                  child: Tooltip(
                    message: destinations[index].label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(MortRadii.card),
                      onTap: () => onDestinationSelected(index),
                      child: AnimatedContainer(
                        duration: disableAnimations
                            ? Duration.zero
                            : MortMotion.standard,
                        curve: Curves.easeOutCubic,
                        constraints: const BoxConstraints(
                          minHeight: MortSpacing.minTouchTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: MortSpacing.xxs,
                          vertical: MortSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: currentIndex == index
                              ? MortColors.roseGold.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(MortRadii.card),
                          border: currentIndex == index
                              ? Border.all(
                                  color: MortColors.roseGold.withValues(
                                    alpha: 0.36,
                                  ),
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              currentIndex == index
                                  ? destinations[index].selectedIcon
                                  : destinations[index].icon,
                              size: 22,
                              color: currentIndex == index
                                  ? MortColors.roseGoldLight
                                  : MortColors.silver,
                            ),
                            const SizedBox(height: MortSpacing.xxs),
                            Text(
                              destinations[index].label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: currentIndex == index
                                        ? MortColors.roseGoldLight
                                        : MortColors.textMuted,
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      liveBlur: true,
      allowAndroidBlur: true,
      borderRadius: BorderRadius.circular(MortRadii.card),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              constraints: const BoxConstraints.tightFor(
                width: MortSpacing.minTouchTarget,
                height: MortSpacing.minTouchTarget,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
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
                      color: MortColors.lightBlue,
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
    final tint = danger
        ? MortColors.danger
        : primary
        ? MortColors.roseGold
        : null;
    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: LiquidGlassContainer(
        tint: tint,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(MortRadii.pill),
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
                Icon(icon, size: 20, color: MortColors.text),
                const SizedBox(width: MortSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
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
      constraints: const BoxConstraints(maxWidth: 224),
      child: AspectRatio(
        aspectRatio: 1,
        child: LiquidGlassContainer(
          tint: color,
          borderRadius: BorderRadius.circular(MortRadii.pill),
          onTap: onPressed,
          semanticLabel: '$title. $status',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
