import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/preferences/mort_experience_preferences.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/repositories/providers.dart';
import '../monetization/providers/revenuecat_providers.dart';
import 'companion_avatar.dart';
import 'companion_catalog.dart';
import 'companion_store.dart';

class CompanionStudioScreen extends ConsumerWidget {
  const CompanionStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider);
    final userId = ref.watch(authRepositoryProvider).currentUser?.id;
    final proState = ref.watch(isMortProProvider);
    if (userId == null) {
      return const MortScreen(
        children: [
          MortHeader(title: 'Companion Studio'),
          Text('Sign in to save your companion looks.'),
        ],
      );
    }
    // A loading or failed entitlement check never unlocks a Pro companion.
    final hasPro = proState.asData?.value ?? false;
    return CompanionStudioBody(
      key: ValueKey('$userId:$hasPro'),
      userId: userId,
      hasPro: hasPro,
      store: CompanionStore(),
      onOpenPro: () => context.push('/settings/subscription'),
    );
  }
}

class CompanionStudioBody extends StatefulWidget {
  const CompanionStudioBody({
    super.key,
    required this.userId,
    required this.hasPro,
    required this.store,
    required this.onOpenPro,
  });

  final String userId;
  final bool hasPro;
  final CompanionStore store;
  final VoidCallback onOpenPro;

  @override
  State<CompanionStudioBody> createState() => _CompanionStudioBodyState();
}

class _CompanionStudioBodyState extends State<CompanionStudioBody> {
  CompanionLook _look = const CompanionLook();
  bool _loading = true;
  String _tab = 'Color';
  CompanionAction _action = CompanionAction.idle;
  Timer? _actionReset;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _actionReset?.cancel();
    super.dispose();
  }

  void _interact() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MortColors.graphite2,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MortSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Interact',
                style: TextStyle(
                  color: MortColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final action in CompanionAction.values.where(
                (action) => action != CompanionAction.idle,
              ))
                ListTile(
                  title: Text(switch (action) {
                    CompanionAction.pet => 'Pet',
                    CompanionAction.wave => 'Wave',
                    CompanionAction.play => 'Play',
                    CompanionAction.rest => 'Rest',
                    CompanionAction.idle => '',
                  }),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _actionReset?.cancel();
                    setState(() => _action = action);
                    _actionReset = Timer(
                      Duration(seconds: action == CompanionAction.rest ? 4 : 2),
                      () {
                        if (mounted)
                          setState(() => _action = CompanionAction.idle);
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final look = await widget.store.load(
        widget.userId,
        hasPro: widget.hasPro,
      );
      if (mounted)
        setState(() {
          _look = look;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _notice('Your saved look could not be loaded.');
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(CompanionLook next) async {
    if (!canSelectCompanion(next.companionId, hasPro: widget.hasPro)) {
      widget.onOpenPro();
      return;
    }
    try {
      await widget.store.save(widget.userId, next, hasPro: widget.hasPro);
      if (mounted) setState(() => _look = next);
    } catch (_) {
      _notice('Your look could not be saved. Try again.');
    }
  }

  Future<void> _saveNamedLook() async {
    try {
      await widget.store.addSavedLook(
        widget.userId,
        _look,
        hasPro: widget.hasPro,
      );
      _notice('Look saved on this device.');
    } catch (_) {
      _notice('Could not save another look.');
    }
  }

  Future<void> _showSavedLooks() async {
    final looks = await widget.store.savedLooks(
      widget.userId,
      // Include locked looks so their original storage indexes stay stable
      // for deletion. Applying one still checks the live entitlement.
      hasPro: true,
    );
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MortColors.graphite2,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MortSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Saved looks',
                  style: TextStyle(
                    color: MortColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: MortSpacing.md),
                if (looks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(MortSpacing.lg),
                    child: Text('No saved looks yet.'),
                  ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: looks.length,
                    itemBuilder: (_, index) {
                      final look = looks[index];
                      final companion = companionById(look.companionId)!;
                      return ListTile(
                        leading: CompanionAvatar(
                          companion: companion,
                          look: look,
                          size: 48,
                          reducedMotion: true,
                        ),
                        title: Text('Look ${index + 1}: ${companion.name}'),
                        subtitle: Text(
                          '${look.colorId} • ${look.environmentId}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove look ${index + 1}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            try {
                              await widget.store.removeSavedLook(
                                widget.userId,
                                index,
                              );
                              if (!sheetContext.mounted) return;
                              setSheetState(() => looks.removeAt(index));
                            } catch (_) {
                              _notice('Could not remove this look.');
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(_save(look));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companion = companionById(_look.companionId)!;
    final reduced =
        MortExperiencePreferencesScope.of(context).reducedMotion ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    return MortScreen(
      atmosphereIntensity: MortAtmosphereIntensity.settings,
      children: [
        const MortHeader(
          eyebrow: 'COMPANION STUDIO',
          title: 'A little space of your own',
          subtitle: 'Cosmetic companions for comfort and focus.',
          backFallbackRoute: '/settings',
        ),
        if (_loading)
          const MortSkeletonCard()
        else ...[
          Container(
            width: double.infinity,
            height: 270,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: MortColors.borderStrong),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _environmentColors(_look.environmentId),
              ),
            ),
            child: Center(
              child: CompanionAvatar(
                companion: companion,
                look: _look,
                size: 220,
                reducedMotion: reduced,
                action: _action,
              ),
            ),
          ),
          const SizedBox(height: MortSpacing.lg),
          Text(
            companion.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: MortSpacing.xs),
          Text(
            '${companion.personality} • ${companion.tagline}',
            style: const TextStyle(color: MortColors.textSecondary),
          ),
          const SizedBox(height: MortSpacing.lg),
          const MortSectionLabel(label: 'Discover companions'),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: companions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final pet = companions[index];
                final locked = !canSelectCompanion(
                  pet.id,
                  hasPro: widget.hasPro,
                );
                final selected = pet.id == _look.companionId;
                return Semantics(
                  button: true,
                  label: '${pet.name}${locked ? ', MORT Pro' : ''}',
                  child: InkWell(
                    key: Key('companion-${pet.id}'),
                    onTap: () => locked
                        ? widget.onOpenPro()
                        : unawaited(_save(_look.copyWith(companionId: pet.id))),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 85,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MortColors.graphite2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? MortColors.silverBright
                              : MortColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          CompanionAvatar(
                            companion: pet,
                            look: _look,
                            size: 53,
                            reducedMotion: true,
                          ),
                          Text(pet.name, style: const TextStyle(fontSize: 12)),
                          if (locked)
                            const Icon(
                              Icons.lock_outline,
                              size: 12,
                              color: MortColors.textSecondary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: MortSpacing.lg),
          const MortSectionLabel(label: 'Make it yours'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in const [
                  'Color',
                  'Accessories',
                  'Items',
                  'Aura',
                  'Environment',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: _tab == tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MortSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in _optionsFor(_tab))
                ChoiceChip(
                  label: Text(option.name),
                  avatar: option.color == null
                      ? null
                      : CircleAvatar(backgroundColor: option.color, radius: 10),
                  selected: _selectedOption(_look, _tab) == option.id,
                  onSelected: (_) =>
                      unawaited(_save(_withOption(_look, _tab, option.id))),
                ),
            ],
          ),
          const SizedBox(height: MortSpacing.lg),
          MortButton(
            label: 'Save this look',
            icon: Icons.bookmark_outline,
            onPressed: () => unawaited(_saveNamedLook()),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Interact',
            icon: Icons.touch_app_outlined,
            style: MortButtonStyle.secondary,
            onPressed: _interact,
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Saved looks',
            icon: Icons.collections_bookmark_outlined,
            style: MortButtonStyle.secondary,
            onPressed: () => unawaited(_showSavedLooks()),
          ),
          const SizedBox(height: MortSpacing.sm),
          MortButton(
            label: 'Focus with ${companion.name}',
            icon: Icons.timer_outlined,
            style: MortButtonStyle.secondary,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _CompanionFocusScreen(
                  companion: companion,
                  look: _look,
                  reducedMotion: reduced,
                ),
              ),
            ),
          ),
          const SizedBox(height: MortSpacing.lg),
          const MortSafetyBanner(
            message:
                'Companions are cosmetic. Safety, verification and account trust never depend on them.',
          ),
        ],
      ],
    );
  }
}

List<Color> _environmentColors(String id) => switch (id) {
  'moon_base' => const [MortColors.night3, MortColors.ink2],
  'cozy_room' => const [MortColors.graphite4, MortColors.ink2],
  'rain_window' => const [MortColors.night2, MortColors.ink2],
  'garden' => const [Color(0xFF101A18), MortColors.ink2],
  'desk' => const [MortColors.graphite3, MortColors.ink2],
  'cloud_world' => const [MortColors.night4, MortColors.ink2],
  'night_forest' => const [Color(0xFF0A1111), MortColors.ink2],
  'minimal_studio' => const [MortColors.graphite4, MortColors.ink2],
  _ => const [MortColors.night2, MortColors.ink2],
};

List<CosmeticOption> _optionsFor(String tab) => switch (tab) {
  'Accessories' => companionAccessories,
  'Items' => companionItems,
  'Aura' => companionAuras,
  'Environment' => companionEnvironments,
  _ => companionColors,
};

String _selectedOption(CompanionLook look, String tab) => switch (tab) {
  'Accessories' => look.accessoryId,
  'Items' => look.itemId,
  'Aura' => look.auraId,
  'Environment' => look.environmentId,
  _ => look.colorId,
};

CompanionLook _withOption(CompanionLook look, String tab, String id) =>
    switch (tab) {
      'Accessories' => look.copyWith(accessoryId: id),
      'Items' => look.copyWith(itemId: id),
      'Aura' => look.copyWith(auraId: id),
      'Environment' => look.copyWith(environmentId: id),
      _ => look.copyWith(colorId: id),
    };

class _CompanionFocusScreen extends StatefulWidget {
  const _CompanionFocusScreen({
    required this.companion,
    required this.look,
    required this.reducedMotion,
  });

  final CompanionDefinition companion;
  final CompanionLook look;
  final bool reducedMotion;

  @override
  State<_CompanionFocusScreen> createState() => _CompanionFocusScreenState();
}

class _CompanionFocusScreenState extends State<_CompanionFocusScreen> {
  int _minutes = 25;
  Duration _remaining = const Duration(minutes: 25);
  DateTime? _deadline;
  Timer? _timer;

  void _startOrPause() {
    if (_timer != null) {
      _tick();
      _timer?.cancel();
      _timer = null;
      _deadline = null;
      setState(() {});
      return;
    }
    _deadline = DateTime.now().add(_remaining);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() {});
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null || !mounted) return;
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      _deadline = null;
      setState(() => _remaining = Duration.zero);
    } else {
      setState(() => _remaining = left);
    }
  }

  void _reset(int minutes) {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    setState(() {
      _minutes = minutes;
      _remaining = Duration(minutes: minutes);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _remaining.inSeconds.clamp(0, _minutes * 60);
    final display =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return MortScreen(
      children: [
        MortHeader(
          eyebrow: 'FOCUS',
          title: 'Focus with ${widget.companion.name}',
          subtitle: 'A quiet timer. No streaks, tokens or rewards.',
        ),
        Center(
          child: CompanionAvatar(
            companion: widget.companion,
            look: widget.look,
            reducedMotion: widget.reducedMotion,
          ),
        ),
        const SizedBox(height: MortSpacing.lg),
        Center(
          child: Text(
            display,
            style: Theme.of(context).textTheme.displayLarge,
            semanticsLabel: '$display remaining',
          ),
        ),
        const SizedBox(height: MortSpacing.lg),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in focusMinutes)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: _minutes == minutes,
                onSelected: (_) => _reset(minutes),
              ),
          ],
        ),
        const SizedBox(height: MortSpacing.lg),
        MortButton(
          label: _remaining == Duration.zero
              ? 'Start again'
              : (_timer == null ? 'Start focus' : 'Pause focus'),
          icon: _timer == null ? Icons.play_arrow_rounded : Icons.pause_rounded,
          onPressed: _remaining == Duration.zero
              ? () => _reset(_minutes)
              : _startOrPause,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Reset timer',
          icon: Icons.restart_alt,
          style: MortButtonStyle.secondary,
          onPressed: () => _reset(_minutes),
        ),
        const SizedBox(height: MortSpacing.md),
        const Text(
          'Closing this screen ends the session. No activity is saved.',
          style: TextStyle(color: MortColors.textSecondary),
        ),
      ],
    );
  }
}
