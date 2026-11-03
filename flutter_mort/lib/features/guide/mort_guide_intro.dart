import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import 'mascot_preference.dart';
import 'mort_mascots.dart';

/// First-open MORT Guide introduction.
///
/// Shown the first time the Guide opens, before any conversation exists, and
/// stays available until the teen picks a companion. Choosing a mascot here
/// changes only the Guide UI — never authentication, roles, or permissions.
class MortGuideWelcomeView extends ConsumerStatefulWidget {
  const MortGuideWelcomeView({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  ConsumerState<MortGuideWelcomeView> createState() =>
      _MortGuideWelcomeViewState();
}

class _MortGuideWelcomeViewState extends ConsumerState<MortGuideWelcomeView> {
  MortMascotId? _chosen;
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    final mascot = _chosen;
    if (mascot == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(mascotPreferenceProvider.notifier).choose(mascot);
      if (!mounted) return;
      widget.onStart();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'MORT could not save your Guide choice. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(mascotPreferenceProvider).value;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Welcome to the MORT Guide',
          title: 'Meet your MORT Guide companion',
          subtitle:
              'The MORT Guide answers questions about jobs, applications, '
              'contracts, payments, reports, and account controls. Choose the '
              'companion that joins you — Pip, Mochi, or Scout.',
        ),
        const MortSafetyBanner(
          message:
              'AI may make mistakes. Do not share IDs, passwords, exact '
              'addresses, or emergency evidence. MORT Guide is not emergency, '
              'legal, or medical assistance.',
        ),
        const SizedBox(height: MortSpacing.md),
        for (final mascot in MortMascotId.values) ...[
          _WelcomeMascotTile(
            mascot: mascot,
            selected: (_chosen ?? saved) == mascot,
            onSelect: () => setState(() => _chosen = mascot),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        if (_error != null) ...[
          MortErrorState(title: 'Not saved', message: _error!),
          const SizedBox(height: MortSpacing.sm),
        ],
        MortButton(
          label: _chosen == null
              ? 'Pick a companion to continue'
              : 'Start with ${_chosen!.displayName}',
          icon: Icons.arrow_forward_outlined,
          busy: _busy,
          onPressed: _chosen == null || _busy ? null : _confirm,
        ),
        const SizedBox(height: MortSpacing.sm),
        TextButton(
          onPressed: () => context.go('/guide/mascot'),
          child: const Text('Choose your Guide UI later'),
        ),
      ],
    );
  }
}

class _WelcomeMascotTile extends StatelessWidget {
  const _WelcomeMascotTile({
    required this.mascot,
    required this.selected,
    required this.onSelect,
  });

  final MortMascotId mascot;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MortCard(
      color: selected ? MortColors.surfaceRaised : MortColors.card,
      onTap: onSelect,
      child: Row(
        children: [
          MortMascotView(
            mascot: mascot,
            state: selected ? MortMascotState.success : MortMascotState.idle,
            size: 72,
          ),
          const SizedBox(width: MortSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mascot.displayName} the ${mascot.animal}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: MortColors.white,
                  ),
                ),
                const SizedBox(height: MortSpacing.xs),
                Text(mascot.tagline),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? MortColors.silverBright : MortColors.silverDark,
          ),
        ],
      ),
    );
  }
}
