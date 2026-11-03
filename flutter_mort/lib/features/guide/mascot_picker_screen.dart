import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import 'mascot_preference.dart';
import 'mort_mascots.dart';

/// "Choose your Guide UI" screen.
///
/// Shows live Pip, Mochi, and Scout previews and persists the choice.
/// Choosing a mascot only changes the Guide companion UI — it never touches
/// authentication, account state, or conversation ownership.
class MortMascotPickerScreen extends ConsumerStatefulWidget {
  const MortMascotPickerScreen({super.key});

  @override
  ConsumerState<MortMascotPickerScreen> createState() =>
      _MortMascotPickerScreenState();
}

class _MortMascotPickerScreenState
    extends ConsumerState<MortMascotPickerScreen> {
  String? _error;
  MortMascotId? _busyWith;

  Future<void> _choose(MortMascotId mascot) async {
    if (_busyWith != null) return;
    setState(() {
      _busyWith = mascot;
      _error = null;
    });
    try {
      await ref.read(mascotPreferenceProvider.notifier).choose(mascot);
      if (!mounted) return;
      MortToast.show(context, '${mascot.displayName} is now your MORT Guide.');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/guide');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyWith = null;
        _error = 'MORT could not save your Guide choice. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(mascotPreferenceProvider).value;
    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'MORT Guide',
          title: 'Choose your Guide UI',
          subtitle:
              'Pick the companion that joins your MORT Guide. You can change '
              'this anytime — it never changes your account or permissions.',
        ),
        for (final mascot in MortMascotId.values) ...[
          _MascotPreviewCard(
            mascot: mascot,
            selected: selected == mascot,
            busy: _busyWith == mascot,
            onSelect: () => _choose(mascot),
          ),
          const SizedBox(height: MortSpacing.sm),
        ],
        if (_error != null) ...[
          MortErrorState(title: 'Not saved', message: _error!),
          const SizedBox(height: MortSpacing.sm),
        ],
      ],
    );
  }
}

class _MascotPreviewCard extends StatelessWidget {
  const _MascotPreviewCard({
    required this.mascot,
    required this.selected,
    required this.busy,
    required this.onSelect,
  });

  final MortMascotId mascot;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MortCard(
      color: selected ? MortColors.surfaceRaised : MortColors.card,
      onTap: busy ? null : onSelect,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MortMascotView(mascot: mascot, state: MortMascotState.idle, size: 84),
          const SizedBox(width: MortSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mascot.displayName} the ${mascot.animal}',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: MortSpacing.xs),
                Text(mascot.tagline),
                if (selected) ...[
                  const SizedBox(height: MortSpacing.xs),
                  Text(
                    'Your current Guide',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: MortColors.silverBright,
                    ),
                  ),
                ],
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
