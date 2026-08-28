import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../../services/precise_location_service.dart';

/// Gates [builder] behind a fresh, on-demand precise-location fix.
///
/// Requests a location exactly once when it mounts (not on a timer, not
/// continuously) -- callers that need a fresh fix again later (e.g. "change
/// search area") should recreate this widget or call [PreciseLocationGateState.retry]
/// via a [GlobalKey]/callback, not rely on this widget polling by itself.
///
/// If Android/iOS reports approximate-only, permission is denied, services
/// are off, the request times out, or the fix is stale, shows a clear
/// "Precise location required" explanation with Retry / Open Settings
/// instead of silently falling back to approximate location for
/// location-dependent marketplace functionality.
class PreciseLocationGate extends StatefulWidget {
  const PreciseLocationGate({
    super.key,
    required this.builder,
    this.service = const PreciseLocationService(),
  });

  final Widget Function(BuildContext context, Position position) builder;
  final PreciseLocationService service;

  @override
  State<PreciseLocationGate> createState() => PreciseLocationGateState();
}

class PreciseLocationGateState extends State<PreciseLocationGate> {
  PreciseLocationResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(retry());
  }

  Future<void> retry() async {
    setState(() => _loading = true);
    final result = await widget.service.requestFreshPreciseLocation();
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _openSettings() async {
    await widget.service.openSettings();
  }

  Future<void> _openLocationSettings() async {
    await widget.service.openLocationSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MortLoading(label: 'Finding your area', fullScreen: false);
    }
    final result = _result;
    if (result != null && result.isUsable) {
      return widget.builder(context, result.position!);
    }
    return PreciseLocationRequiredCard(
      status: result?.status ?? PreciseLocationStatus.error,
      onRetry: retry,
      onOpenSettings: _openSettings,
      onOpenLocationSettings: _openLocationSettings,
    );
  }
}

class PreciseLocationRequiredCard extends StatelessWidget {
  const PreciseLocationRequiredCard({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onOpenLocationSettings,
  });

  final PreciseLocationStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLocationSettings;

  static const _explanation =
      'MORT needs your precise location to accurately show how far nearby '
      'jobs are and whether you can realistically get there. This location '
      'is used only to calculate distance and eligibility -- it is never '
      'shared publicly or shown to other users.';

  (String title, String detail) get _copy => switch (status) {
    PreciseLocationStatus.approximateOnly => (
      'Precise location required',
      'Your device is sharing only an approximate area. $_explanation',
    ),
    PreciseLocationStatus.denied => (
      'Precise location required',
      'Location access was not granted. $_explanation',
    ),
    PreciseLocationStatus.permanentlyDenied => (
      'Precise location required',
      'Location access is turned off for MORT in system settings. '
          '$_explanation',
    ),
    PreciseLocationStatus.servicesDisabled => (
      'Turn on location services',
      'Your device\'s location services are off. Turn them on to see '
          'accurate nearby jobs.',
    ),
    PreciseLocationStatus.timeout => (
      'Couldn\'t get your location',
      'Finding your precise location took too long. Try again, ideally '
          'somewhere with a clearer view of the sky.',
    ),
    PreciseLocationStatus.stale => (
      'Location needs a refresh',
      'Your last known location is too old to use. Try again for an '
          'up-to-date result.',
    ),
    PreciseLocationStatus.error => (
      'Couldn\'t get your location',
      'Something went wrong getting your location. Try again.',
    ),
    PreciseLocationStatus.granted => ('', ''),
  };

  @override
  Widget build(BuildContext context) {
    final (title, detail) = _copy;
    final needsAppSettings =
        status == PreciseLocationStatus.permanentlyDenied ||
        status == PreciseLocationStatus.approximateOnly;
    final needsLocationSettings =
        status == PreciseLocationStatus.servicesDisabled;
    return MortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_disabled_rounded,
            color: MortColors.lightBlue,
            size: 32,
          ),
          const SizedBox(height: MortSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MortSpacing.xs),
          Text(detail, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: MortSpacing.md),
          Wrap(
            spacing: MortSpacing.sm,
            runSpacing: MortSpacing.sm,
            children: [
              MortPrimaryButton(label: 'Retry', onPressed: onRetry),
              if (needsAppSettings)
                MortSecondaryButton(
                  label: 'Open settings',
                  onPressed: onOpenSettings,
                ),
              if (needsLocationSettings)
                MortSecondaryButton(
                  label: 'Open location settings',
                  onPressed: onOpenLocationSettings,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
