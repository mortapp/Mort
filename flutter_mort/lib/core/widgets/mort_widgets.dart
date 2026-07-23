import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../theme/mort_colors.dart';
import '../theme/mort_spacing.dart';

class MortScreen extends StatelessWidget {
  const MortScreen({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(MortSpacing.md),
    this.bottom,
    this.scroll = true,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final Widget? bottom;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: MortSpacing.maxContentWidth,
          ),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (AppConfig.showReleaseStageLabel) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: MortBadge(
                      label: AppConfig.stageName,
                      color: MortColors.warning,
                    ),
                  ),
                  const SizedBox(height: MortSpacing.sm),
                ],
                ...children,
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: MortColors.bg,
      bottomNavigationBar: bottom,
      body: scroll ? SingleChildScrollView(child: content) : content,
    );
  }
}

class MortHeader extends StatelessWidget {
  const MortHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MortSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  MortBadge(label: eyebrow!, color: MortColors.neon),
                if (eyebrow != null) const SizedBox(height: MortSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                if (subtitle != null) ...[
                  const SizedBox(height: MortSpacing.sm),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: MortSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class MortCard extends StatelessWidget {
  const MortCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MortSpacing.md),
    this.color = MortColors.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MortColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: card,
    );
  }
}

enum MortButtonStyle { primary, secondary, danger, ghost, disabled }

class MortButton extends StatelessWidget {
  const MortButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = MortButtonStyle.primary,
    this.fullWidth = true,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final MortButtonStyle style;
  final bool fullWidth;
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final enabled =
        onPressed != null && style != MortButtonStyle.disabled && !busy;
    final bg = switch (style) {
      MortButtonStyle.primary => MortColors.neon,
      MortButtonStyle.secondary => MortColors.cardAlt,
      MortButtonStyle.danger => MortColors.danger,
      MortButtonStyle.ghost => Colors.transparent,
      MortButtonStyle.disabled => MortColors.line,
    };
    final fg = switch (style) {
      MortButtonStyle.primary => Colors.black,
      MortButtonStyle.secondary => MortColors.text,
      MortButtonStyle.danger => Colors.white,
      MortButtonStyle.ghost => MortColors.neon,
      MortButtonStyle.disabled => MortColors.textMuted,
    };

    final child = ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
      label: Text(busy ? busyLabel ?? label : label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: MortColors.line,
        disabledForegroundColor: MortColors.textMuted,
        minimumSize: const Size(48, 52),
        elevation: style == MortButtonStyle.primary ? 8 : 0,
        shadowColor: MortColors.neon.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class MortIconButton extends StatelessWidget {
  const MortIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: MortColors.cardAlt,
        foregroundColor: MortColors.text,
      ),
    );
  }
}

class MortTextField extends StatelessWidget {
  const MortTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLength,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int? maxLength;
  final bool autocorrect;
  final bool enableSuggestions;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      enabled: enabled,
      maxLength: maxLength,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class MortTextArea extends StatelessWidget {
  const MortTextArea({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.maxLines = 4,
    this.maxLength,
    this.validator,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class MortDropdown<T> extends StatelessWidget {
  const MortDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      dropdownColor: MortColors.cardAlt,
      items: items.entries
          .map(
            (entry) =>
                DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class MortBadge extends StatelessWidget {
  const MortBadge({
    super.key,
    required this.label,
    this.color = MortColors.safetyBlue,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class MortAvatar extends StatelessWidget {
  const MortAvatar({super.key, this.label, this.radius = 24});

  final String? label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = (label == null || label!.trim().isEmpty)
        ? 'M'
        : label!
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

    return CircleAvatar(
      radius: radius,
      backgroundColor: MortColors.neonDeep,
      child: Text(
        initials,
        style: TextStyle(
          color: MortColors.neon,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

class MortToast {
  const MortToast._();

  static void show(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class MortLoading extends StatelessWidget {
  const MortLoading({
    super.key,
    this.label = 'Loading MORT',
    this.fullScreen = true,
  });

  final String label;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    if (!fullScreen) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: MortSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                color: MortColors.neon,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(width: MortSpacing.sm),
            Flexible(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
    }
    return MortScreen(
      scroll: false,
      children: [
        const Spacer(),
        const Center(child: CircularProgressIndicator(color: MortColors.neon)),
        const SizedBox(height: MortSpacing.md),
        Center(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const Spacer(),
      ],
    );
  }
}

class MortEmptyState extends StatelessWidget {
  const MortEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inbox_outlined, color: MortColors.textMuted),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: MortSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class MortErrorState extends StatelessWidget {
  const MortErrorState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: MortColors.danger.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: MortColors.danger),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) ...[
            const SizedBox(height: MortSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

class MortSkeletonCard extends StatelessWidget {
  const MortSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          3,
          (index) => Container(
            height: index == 0 ? 18 : 12,
            width: index == 0 ? 180 : 260,
            margin: const EdgeInsets.only(bottom: MortSpacing.sm),
            decoration: BoxDecoration(
              color: MortColors.line.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class MortSafetyBanner extends StatelessWidget {
  const MortSafetyBanner({
    super.key,
    this.message = AppConstants.teenSafetyDisclaimer,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: MortColors.safetyBlue.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: MortColors.safetyBlue),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class MortPaymentDisclaimer extends StatelessWidget {
  const MortPaymentDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortSafetyBanner(message: AppConstants.paymentDisclaimer);
  }
}

class MortVerificationDisclaimer extends StatelessWidget {
  const MortVerificationDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortSafetyBanner(message: AppConstants.verificationDisclaimer);
  }
}

class MortGuardianBanner extends StatelessWidget {
  const MortGuardianBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortSafetyBanner(
      message:
          'Guardian Mode can supervise approvals, messages, pings, and teen activity. Teens can still use free safety tools.',
    );
  }
}

class MortAdBannerSlot extends StatelessWidget {
  const MortAdBannerSlot({
    super.key,
    required this.placement,
    this.sensitive = false,
  });

  final String placement;
  final bool sensitive;

  @override
  Widget build(BuildContext context) {
    if (sensitive || !AppConfig.nativeAdsCompiledIn || !AppConfig.adsEnabled) {
      return const SizedBox.shrink();
    }
    return MortCard(
      color: MortColors.cardAlt,
      child: Row(
        children: [
          const Icon(Icons.ads_click_outlined, color: MortColors.textMuted),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Text(
              'Sponsored content',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class MortRewardedAdButton extends StatelessWidget {
  const MortRewardedAdButton({
    super.key,
    required this.label,
    this.onRewardReady,
    this.enabled = false,
  });

  final String label;
  final VoidCallback? onRewardReady;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MortButton(
      label: enabled ? label : '$label - Unavailable',
      icon: Icons.play_circle_outline,
      style: enabled ? MortButtonStyle.secondary : MortButtonStyle.disabled,
      onPressed: enabled ? onRewardReady : null,
    );
  }
}

class MortPaywallCard extends StatelessWidget {
  const MortPaywallCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onUpgrade,
  });

  final String title;
  final String subtitle;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: MortColors.premium.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MortPremiumBadge(),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: MortSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Upgrade if you want',
            icon: Icons.auto_awesome,
            onPressed: onUpgrade,
          ),
        ],
      ),
    );
  }
}

class MortPlanCard extends StatelessWidget {
  const MortPlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.features,
    this.onPressed,
  });

  final String title;
  final String price;
  final List<String> features;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(price, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: MortSpacing.sm),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: MortSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: MortColors.neon,
                    size: 17,
                  ),
                  const SizedBox(width: MortSpacing.xs),
                  Expanded(
                    child: Text(
                      feature,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: onPressed == null ? 'Dashboard setup needed' : 'Choose plan',
            onPressed: onPressed,
            style: onPressed == null
                ? MortButtonStyle.disabled
                : MortButtonStyle.primary,
          ),
        ],
      ),
    );
  }
}

class MortFeatureLockCard extends StatelessWidget {
  const MortFeatureLockCard({
    super.key,
    required this.feature,
    required this.reason,
  });

  final String feature;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      color: MortColors.premium.withValues(alpha: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: MortColors.premium),
          const SizedBox(width: MortSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: MortSpacing.xs),
                Text(reason, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MortPremiumBadge extends StatelessWidget {
  const MortPremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortBadge(
      label: 'Premium optional',
      color: MortColors.premium,
      icon: Icons.auto_awesome,
    );
  }
}

class MortAdFreeBadge extends StatelessWidget {
  const MortAdFreeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const MortBadge(
      label: 'Ad-free eligible',
      color: MortColors.neon,
      icon: Icons.visibility_off_outlined,
    );
  }
}

class MortJobStatusBadge extends StatelessWidget {
  const MortJobStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'open' => MortColors.neon,
      'closed' || 'removed' => MortColors.danger,
      'paused' => MortColors.warning,
      _ => MortColors.safetyBlue,
    };
    return MortBadge(label: status.replaceAll('_', ' '), color: color);
  }
}

class MortTrustBadge extends StatelessWidget {
  const MortTrustBadge({super.key, required this.label, this.verified = false});

  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return MortBadge(
      label: label,
      color: verified ? MortColors.neon : MortColors.textMuted,
      icon: verified ? Icons.verified : Icons.info_outline,
    );
  }
}

class MortCategoryPill extends StatelessWidget {
  const MortCategoryPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      selectedColor: MortColors.neonDeep,
      backgroundColor: MortColors.cardAlt,
      labelStyle: TextStyle(
        color: selected ? MortColors.neon : MortColors.textSoft,
      ),
      side: BorderSide(color: selected ? MortColors.neon : MortColors.line),
    );
  }
}

class MortProfileCompletionMeter extends StatelessWidget {
  const MortProfileCompletionMeter({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = (value.clamp(0, 1) * 100).round();
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile strength',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortProgressBar(value: value),
          const SizedBox(height: MortSpacing.xs),
          Text(
            '$percent% complete',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class MortStatCard extends StatelessWidget {
  const MortStatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.trending_up,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MortColors.neon),
          const SizedBox(height: MortSpacing.sm),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class MortAction {
  const MortAction({
    required this.label,
    this.icon = Icons.arrow_forward,
    this.route,
    this.onPressed,
    this.enabled = true,
    this.style = MortButtonStyle.secondary,
    this.busy = false,
    this.busyLabel,
  });

  final String label;
  final IconData icon;
  final String? route;
  final VoidCallback? onPressed;
  final bool enabled;
  final MortButtonStyle style;
  final bool busy;
  final String? busyLabel;
}

class MortActionRow extends StatelessWidget {
  const MortActionRow({super.key, required this.actions});

  final List<MortAction> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MortSpacing.sm,
      runSpacing: MortSpacing.sm,
      children: actions.map((action) {
        return MortButton(
          label: action.enabled
              ? action.label
              : '${action.label} - Unavailable',
          icon: action.icon,
          fullWidth: false,
          busy: action.busy,
          busyLabel: action.busyLabel,
          style: action.enabled ? action.style : MortButtonStyle.disabled,
          onPressed: action.enabled
              ? action.onPressed ??
                    (action.route == null
                        ? null
                        : () => context.go(action.route!))
              : null,
        );
      }).toList(),
    );
  }
}

class MortNotificationBell extends StatelessWidget {
  const MortNotificationBell({super.key, this.count = 0, this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MortIconButton(
          icon: Icons.notifications_outlined,
          tooltip: 'Notifications',
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: MortColors.danger,
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class MortProgressBar extends StatelessWidget {
  const MortProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        minHeight: 9,
        value: value.clamp(0, 1),
        backgroundColor: MortColors.line,
        valueColor: const AlwaysStoppedAnimation<Color>(MortColors.neon),
      ),
    );
  }
}

class MortStepper extends StatelessWidget {
  const MortStepper({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index <= current;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(
              right: index == total - 1 ? 0 : MortSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: active ? MortColors.neon : MortColors.line,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}

class MortConfirmSheet {
  const MortConfirmSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(MortSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: MortSpacing.sm),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: MortSpacing.lg),
            MortButton(
              label: confirmLabel,
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: MortSpacing.sm),
            MortButton(
              label: 'Cancel',
              style: MortButtonStyle.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}

class MortBottomSheet {
  const MortBottomSheet._();

  static Future<T?> show<T>(BuildContext context, Widget child) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MortSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}

class MortSectionTitle extends StatelessWidget {
  const MortSectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: MortSpacing.lg,
        bottom: MortSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: MortSpacing.xs),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
