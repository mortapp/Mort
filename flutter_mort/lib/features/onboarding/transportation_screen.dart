import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/providers.dart';

class TransportationScreen extends ConsumerStatefulWidget {
  const TransportationScreen({super.key});

  @override
  ConsumerState<TransportationScreen> createState() =>
      _TransportationScreenState();
}

class _TransportationScreenState extends ConsumerState<TransportationScreen> {
  static const _options = <String, ({String label, IconData icon})>{
    'walking': (label: 'Walking', icon: Icons.directions_walk_rounded),
    'bicycle': (label: 'Bicycle', icon: Icons.pedal_bike_rounded),
    'car': (label: 'Car', icon: Icons.directions_car_outlined),
    'public_transit': (
      label: 'Public transit',
      icon: Icons.directions_bus_outlined,
    ),
    'rideshare': (label: 'Rideshare', icon: Icons.local_taxi_outlined),
    'other': (label: 'Other', icon: Icons.more_horiz_rounded),
  };

  final _formKey = GlobalKey<FormState>();
  final _distance = TextEditingController();
  final _minutes = TextEditingController();
  final Set<String> _selected = {};
  bool _walkingDistanceOnly = false;
  bool _guardianTransportationPossible = false;
  bool _loading = true;
  bool _busy = false;
  UserRole? _role;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _distance.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _role = profile?.role;
        _selected
          ..clear()
          ..addAll(profile?.transportationMethods ?? const []);
        _distance.text = profile?.maxTravelDistanceMiles?.toString() ?? '';
        _minutes.text = profile?.maxTravelMinutes?.toString() ?? '';
        _walkingDistanceOnly = profile?.walkingDistanceOnly ?? false;
        _guardianTransportationPossible =
            profile?.guardianTransportationPossible ?? false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      MortToast.show(context, userFacingError(error));
    }
  }

  String? _optionalInteger(
    String? value, {
    required int minimum,
    required int maximum,
    required String unit,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < minimum || parsed > maximum) {
      return 'Enter $minimum-$maximum $unit.';
    }
    return null;
  }

  int? _optionalValue(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : int.tryParse(value);
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(completedStep: 'transportation');
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/payment');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_role != UserRole.teen) {
      await _skip();
      return;
    }
    if (_selected.isEmpty) {
      MortToast.show(
        context,
        'Choose at least one way you usually get around.',
      );
      return;
    }
    if (_walkingDistanceOnly && !_selected.contains('walking')) {
      MortToast.show(
        context,
        'Select Walking before choosing walking-distance-only jobs.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveTransportationPreferences(
            methods: _selected.toList(growable: false),
            maxDistanceMiles: _optionalValue(_distance),
            maxTravelMinutes: _optionalValue(_minutes),
            walkingDistanceOnly: _walkingDistanceOnly,
            guardianTransportationPossible: _guardianTransportationPossible,
          );
      await ref
          .read(profileRepositoryProvider)
          .saveOnboardingProgress(completedStep: 'transportation');
      ref.invalidate(currentProfileProvider);
      ref.invalidate(onboardingProgressProvider);
      if (mounted) context.go('/onboarding/payment');
    } catch (error) {
      if (mounted) MortToast.show(context, userFacingError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MortLoading(label: 'Loading travel preferences');
    }

    if (_role != UserRole.teen) {
      return MortScreen(
        children: [
          const MortHeader(
            eyebrow: 'Transportation',
            title: 'Teen matching preference',
            subtitle:
                'Transportation matching is only stored for teen profiles. No exact address is collected.',
          ),
          const MortStepper(current: 6, total: 12),
          const SizedBox(height: MortSpacing.md),
          const MortSafetyBanner(
            message:
                'Your role does not need this step. Continue without sharing transportation details.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            busy: _busy,
            onPressed: _skip,
          ),
        ],
      );
    }

    return MortScreen(
      children: [
        const MortHeader(
          eyebrow: 'Getting there',
          title: 'How do you usually get around?',
          subtitle:
              'Choose every option that may work. These preferences help rank jobs; they never guarantee a ride or reveal your home address.',
        ),
        const MortStepper(current: 6, total: 12),
        const SizedBox(height: MortSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - MortSpacing.sm) / 2;
            return Wrap(
              spacing: MortSpacing.sm,
              runSpacing: MortSpacing.sm,
              children: _options.entries
                  .map((entry) {
                    final selected = _selected.contains(entry.key);
                    return SizedBox(
                      width: itemWidth,
                      child: MortGlassCard(
                        infoAccent: selected,
                        semanticLabel:
                            '${entry.value.label}, ${selected ? 'selected' : 'not selected'}',
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(entry.key);
                            if (entry.key == 'walking') {
                              _walkingDistanceOnly = false;
                            }
                          } else {
                            _selected.add(entry.key);
                          }
                        }),
                        child: Column(
                          children: [
                            Icon(
                              entry.value.icon,
                              color: selected
                                  ? MortColors.lightBlue
                                  : MortColors.roseGoldLight,
                              size: 30,
                            ),
                            const SizedBox(height: MortSpacing.xs),
                            Text(
                              entry.value.label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: MortSpacing.xxs),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 18,
                              color: selected
                                  ? MortColors.lightBlue
                                  : MortColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: MortSpacing.md),
        Form(
          key: _formKey,
          child: Column(
            children: [
              MortTextField(
                label: 'Maximum comfortable distance (miles, optional)',
                controller: _distance,
                keyboardType: TextInputType.number,
                validator: (value) => _optionalInteger(
                  value,
                  minimum: 1,
                  maximum: 50,
                  unit: 'miles',
                ),
              ),
              const SizedBox(height: MortSpacing.sm),
              MortTextField(
                label: 'Maximum comfortable travel time (optional)',
                controller: _minutes,
                keyboardType: TextInputType.number,
                validator: (value) => _optionalInteger(
                  value,
                  minimum: 5,
                  maximum: 180,
                  unit: 'minutes',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.sm),
        MortGlassCard(
          infoAccent: true,
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show me walking-distance jobs only'),
                subtitle: const Text(
                  'Walking must be selected above. You can change this later.',
                ),
                value: _walkingDistanceOnly,
                onChanged: (value) =>
                    setState(() => _walkingDistanceOnly = value ?? false),
              ),
              const Divider(),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Guardian transportation may be available'),
                subtitle: const Text(
                  'This is a preference, not a promise that a ride is available.',
                ),
                value: _guardianTransportationPossible,
                onChanged: (value) => setState(
                  () => _guardianTransportationPossible = value ?? false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        MortButton(
          label: 'Save and continue',
          busyLabel: 'Saving preferences...',
          busy: _busy,
          icon: Icons.arrow_forward_rounded,
          onPressed: _save,
        ),
        const SizedBox(height: MortSpacing.sm),
        MortButton(
          label: 'Skip transportation preferences',
          icon: Icons.skip_next_rounded,
          style: MortButtonStyle.ghost,
          busy: _busy,
          onPressed: _skip,
        ),
      ],
    );
  }
}
