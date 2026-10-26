import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/mort_colors.dart';
import '../../core/theme/mort_spacing.dart';
import '../../data/repositories/providers.dart';
import 'mort_widgets.dart';

/// Keeps authenticated users inside Legal Center until required material
/// document revisions have been accepted. Lookup failures stay blocking and
/// offer an explicit retry because they cannot prove that access is allowed.
class LegalReacceptanceGate extends ConsumerStatefulWidget {
  const LegalReacceptanceGate({
    super.key,
    required this.userId,
    required this.child,
  });

  final String? userId;
  final Widget child;

  @override
  ConsumerState<LegalReacceptanceGate> createState() =>
      _LegalReacceptanceGateState();
}

class _LegalReacceptanceGateState extends ConsumerState<LegalReacceptanceGate> {
  late final GoRouter _router = ref.read(appRouterProvider);
  String? _redirectScheduledForLocation;
  bool _routeRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _router.routerDelegate.addListener(_handleRouteChanged);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_handleRouteChanged);
    super.dispose();
  }

  void _handleRouteChanged() {
    if (!mounted || _routeRefreshScheduled) return;
    _routeRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeRefreshScheduled = false;
      if (!mounted) return;
      setState(() => _redirectScheduledForLocation = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    if (userId == null) return widget.child;

    final router = _router;
    final pending = ref.watch(pendingRequiredLegalReacceptanceProvider(userId));

    return pending.when(
      loading: () => _blocked(const _LegalRequirementLoading()),
      error: (_, _) => _blocked(
        _LegalRequirementUnavailable(
          onRetry: () =>
              ref.invalidate(pendingRequiredLegalReacceptanceProvider(userId)),
        ),
      ),
      data: (required) {
        if (!required) {
          _redirectScheduledForLocation = null;
          return widget.child;
        }

        final location = router.routerDelegate.currentConfiguration.uri.path;
        if (location == '/legal-center' || location.startsWith('/legal-center/')) {
          _redirectScheduledForLocation = null;
          return widget.child;
        }

        if (_redirectScheduledForLocation != location) {
          _redirectScheduledForLocation = location;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final currentLocation =
                router.routerDelegate.currentConfiguration.uri.path;
            if (currentLocation == location) {
              router.go('/legal-center');
            } else {
              _redirectScheduledForLocation = null;
            }
          });
        }
        return _blocked(const _LegalRequirementLoading());
      },
    );
  }

  Widget _blocked(Widget message) => Stack(
    fit: StackFit.expand,
    children: [
      Offstage(offstage: true, child: widget.child),
      message,
    ],
  );
}

class _LegalRequirementLoading extends StatelessWidget {
  const _LegalRequirementLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MortColors.void_,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(MortSpacing.md),
        children: const [
          SizedBox(height: MortSpacing.xl),
          MortHeader(
            eyebrow: 'Required legal review',
            title: 'Review the latest documents',
            subtitle:
                'Checking your required legal document versions before opening MORT.',
          ),
          SizedBox(height: MortSpacing.md),
          MortLoading(
            label: 'Checking required legal documents',
            fullScreen: false,
          ),
        ],
      ),
    ),
  );
}

class _LegalRequirementUnavailable extends StatelessWidget {
  const _LegalRequirementUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MortColors.void_,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(MortSpacing.md),
        children: [
          const SizedBox(height: MortSpacing.xl),
          const MortHeader(
            eyebrow: 'Required legal review',
            title: 'MORT could not verify your documents',
            subtitle:
                'Reconnect and retry. MORT cannot confirm that required document versions are current yet.',
          ),
          const SizedBox(height: MortSpacing.md),
          MortErrorState(
            title: 'Required legal documents unavailable',
            message:
                'Your account stays protected until MORT can verify the current requirements.',
            action: MortButton(
              label: 'Retry legal check',
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    ),
  );
}
