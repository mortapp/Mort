import 'package:flutter/material.dart';

import '../../l10n/mort_l10n.dart';
import '../preferences/mort_experience_preferences.dart';
import '../theme/mort_colors.dart';
import '../theme/mort_spacing.dart';
import '../theme/mort_tokens.dart';
import 'mort_widgets.dart';

class MortSearchField extends StatelessWidget {
  const MortSearchField({
    super.key,
    this.controller,
    this.hint = 'Search MORT',
    this.onChanged,
    this.onSubmitted,
    this.onFilter,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: onFilter == null
          ? null
          : IconButton(
              tooltip: 'Filters',
              onPressed: onFilter,
              icon: const Icon(Icons.tune_rounded),
            ),
    ),
  );
}

class MortFilterChip extends StatelessWidget {
  const MortFilterChip({
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
  Widget build(BuildContext context) => FilterChip(
    avatar: icon == null
        ? null
        : Icon(
            icon,
            size: MortIconSizes.small,
            color: selected ? MortColors.roseGoldLight : MortColors.textMuted,
          ),
    label: Text(label),
    selected: selected,
    onSelected: onSelected,
    showCheckmark: false,
  );
}

class MortStatusChip extends StatelessWidget {
  const MortStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.color = MortColors.lightBlue,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      MortBadge(label: label, icon: icon, color: color);
}

class MortTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MortTopBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    leading: leading,
    title: Text(title),
    actions: actions,
    flexibleSpace: DecoratedBox(
      decoration: BoxDecoration(
        color: MortColors.bg.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: MortColors.line)),
      ),
    ),
  );
}

class MortBottomNavigation extends StatelessWidget {
  const MortBottomNavigation({
    super.key,
    required this.index,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int index;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: BoxDecoration(
        border: const Border(top: BorderSide(color: MortColors.lineStrong)),
        boxShadow: [
          const BoxShadow(color: Color(0xB8000000), blurRadius: 24),
          BoxShadow(
            color: MortColors.babyBlueDeep.withValues(alpha: 0.12),
            blurRadius: 28,
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: index,
        destinations: destinations,
        onDestinationSelected: onDestinationSelected,
      ),
    ),
  );
}

class MortPriceDisplay extends StatelessWidget {
  const MortPriceDisplay({
    super.key,
    required this.label,
    required this.formattedAmount,
    this.emphasized = false,
  });

  final String label;
  final String formattedAmount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    final amountWidget = Text(
      formattedAmount,
      textAlign: TextAlign.end,
      style:
          (emphasized
                  ? Theme.of(context).textTheme.headlineSmall
                  : Theme.of(context).textTheme.titleMedium)
              ?.copyWith(
                color: emphasized ? MortColors.roseGoldLight : MortColors.text,
              ),
    );

    return Semantics(
      label: '$label, $formattedAmount',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(16) > 21;
          if (largeText || constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labelWidget,
                const SizedBox(height: MortSpacing.xxs),
                amountWidget,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: MortSpacing.sm),
              Flexible(child: amountWidget),
            ],
          );
        },
      ),
    );
  }
}

class MortJobCard extends StatelessWidget {
  const MortJobCard({
    super.key,
    required this.title,
    required this.category,
    required this.area,
    required this.payout,
    required this.onTap,
    this.subtitle,
    this.verified = false,
    this.saved = false,
    this.onSaved,
  });

  final String title;
  final String category;
  final String area;
  final String payout;
  final String? subtitle;
  final bool verified;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context) => MortGlassCard(
    onTap: onTap,
    semanticLabel: '$title, earn $payout, $area',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) > 21;
            final titleWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: MortSpacing.xxs),
                Text(category, style: Theme.of(context).textTheme.bodyMedium),
              ],
            );
            final payoutWidget = Text(
              payout,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: MortColors.roseGoldLight,
              ),
            );
            final saveWidget = onSaved == null
                ? null
                : IconButton(
                    tooltip: saved ? 'Remove saved job' : 'Save job',
                    onPressed: onSaved,
                    icon: Icon(
                      saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: saved ? MortColors.roseGold : MortColors.textMuted,
                    ),
                  );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleWidget,
                  const SizedBox(height: MortSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: payoutWidget),
                      ?saveWidget,
                    ],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleWidget),
                const SizedBox(width: MortSpacing.sm),
                Flexible(child: payoutWidget),
                if (saveWidget != null) ...[
                  const SizedBox(width: MortSpacing.xs),
                  saveWidget,
                ],
              ],
            );
          },
        ),
        if (subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: MortSpacing.sm),
          Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: MortSpacing.sm),
        Wrap(
          spacing: MortSpacing.xs,
          runSpacing: MortSpacing.xs,
          children: [
            MortStatusChip(
              label: area,
              icon: Icons.location_on_outlined,
              color: MortColors.lightBlue,
            ),
            if (verified)
              const MortStatusChip(
                label: 'Verified adult',
                icon: Icons.verified_user_outlined,
                color: MortColors.success,
              ),
          ],
        ),
      ],
    ),
  );
}

class MortPinPad extends StatelessWidget {
  const MortPinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.digits = 6,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int digits;
  final bool enabled;

  void _append(BuildContext context, String digit) {
    if (!enabled || value.length >= digits) return;
    MortHaptics.selectionClick(context);
    onChanged('$value$digit');
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.mortL10n;
    return Semantics(
      label: strings.secureJobPinEntry(digits),
      value: strings.pinDigitsEntered(value.length, digits),
      textField: true,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = MortSpacing.xs;
              final available = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : (digits * 42) + ((digits - 1) * spacing);
              final width = ((available - ((digits - 1) * spacing)) / digits)
                  .clamp(30.0, 42.0);
              final duration = MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : MortMotion.quick;
              return ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    digits,
                    (index) => Padding(
                      padding: EdgeInsets.only(
                        right: index == digits - 1 ? 0 : spacing,
                      ),
                      child: AnimatedContainer(
                        duration: duration,
                        width: width,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MortColors.glass,
                          borderRadius: BorderRadius.circular(MortRadii.small),
                          border: Border.all(
                            color: index < value.length
                                ? MortColors.roseGold
                                : MortColors.line,
                          ),
                        ),
                        child: Text(
                          index < value.length ? '\u2022' : '',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: MortSpacing.md),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', 'back'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: MortSpacing.xs),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MortSpacing.xxs,
                        ),
                        child: key.isEmpty
                            ? const SizedBox(height: 54)
                            : Semantics(
                                button: true,
                                label: key == 'back'
                                    ? strings.deleteLastPinDigit
                                    : strings.pinDigit(key),
                                excludeSemantics: true,
                                child: OutlinedButton(
                                  onPressed: !enabled
                                      ? null
                                      : key == 'back'
                                      ? () => onChanged(
                                          value.isEmpty
                                              ? value
                                              : value.substring(
                                                  0,
                                                  value.length - 1,
                                                ),
                                        )
                                      : () => _append(context, key),
                                  child: key == 'back'
                                      ? const Icon(Icons.backspace_outlined)
                                      : Text(
                                          key,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MortTimelineStep {
  const MortTimelineStep({
    required this.title,
    this.detail,
    this.complete = false,
  });

  final String title;
  final String? detail;
  final bool complete;
}

class MortTimeline extends StatelessWidget {
  const MortTimeline({super.key, required this.steps});

  final List<MortTimelineStep> steps;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < steps.length; index++)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  steps[index].complete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: steps[index].complete
                      ? MortColors.success
                      : MortColors.lightBlue,
                ),
                if (index < steps.length - 1)
                  Container(width: 1, height: 44, color: MortColors.lineStrong),
              ],
            ),
            const SizedBox(width: MortSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: MortSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[index].title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (steps[index].detail != null)
                      Text(
                        steps[index].detail!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
    ],
  );
}

class MortNotificationTile extends StatelessWidget {
  const MortNotificationTile({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
    this.icon = Icons.notifications_none_rounded,
    this.unread = false,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final IconData icon;
  final bool unread;

  @override
  Widget build(BuildContext context) => MortGlassCard(
    onTap: onTap,
    infoAccent: unread,
    child: Row(
      children: [
        Icon(icon, color: unread ? MortColors.lightBlue : MortColors.textMuted),
        const SizedBox(width: MortSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}

class MortConfirmationDialog {
  const MortConfirmationDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }
}
