import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mort_theme.dart';
import '../../core/theme/mort_spacing.dart';
import '../../core/widgets/mort_widgets.dart';
import '../financial/financial_safety_center.dart';
import '../legal/legal_screens.dart';
import '../mort_screens.dart';
import '../onboarding/compact_onboarding.dart';
import '../settings/native_permissions_screen.dart';
import 'browserstack_qa_fixtures.dart';

/// An internal-only deterministic shell around MORT's real product widgets.
class BrowserStackQaApp extends StatelessWidget {
  const BrowserStackQaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/qa',
      routes: [
        GoRoute(path: '/qa', builder: (_, _) => const _BrowserStackQaHome()),
        GoRoute(
          path: '/qa/onboarding',
          builder: (_, _) => const CompactOnboardingScreen(
            permissionsService: BrowserStackQaNativePermissionsService(),
            nativeLocationLookupEnabled: false,
            nativeLocationDisabledMessage:
                'Current-location lookup is disabled in BrowserStack QA. Enter a ZIP or city manually.',
          ),
        ),
        GoRoute(
          path: '/qa/safety',
          builder: (_, _) =>
              const SafetyCenterScreen(emergencyDialerEnabled: false),
        ),
        GoRoute(
          path: '/qa/financial',
          builder: (_, _) => const FinancialSafetyCenterScreen(),
        ),
        GoRoute(
          path: '/qa/settings',
          builder: (_, _) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/qa/permissions',
          builder: (_, _) => const NativePermissionsScreen(
            permissionsService: BrowserStackQaNativePermissionsService(),
            nativeActionsEnabled: false,
            nativeActionsDisabledMessage:
                'Permission requests are disabled in BrowserStack QA. No device permission or setting can be changed.',
          ),
        ),
        GoRoute(
          path: '/qa/legal',
          builder: (_, _) => const TeenTermsSummaryScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: browserStackQaFixtureOverrides(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: MortTheme.dark(),
        routerConfig: router,
      ),
    );
  }
}

class _BrowserStackQaHome extends StatelessWidget {
  const _BrowserStackQaHome();

  @override
  Widget build(BuildContext context) {
    return MortScreen(
      children: [
        Semantics(
          identifier: 'qa-home-landmark',
          label: 'qa-home-landmark',
          container: true,
          explicitChildNodes: true,
          child: const MortHeader(
            eyebrow: 'Internal automated test',
            title: 'BrowserStack functional QA',
            subtitle:
                'Local synthetic data. No account or provider is contacted.',
          ),
        ),
        const SizedBox(height: MortSpacing.md),
        _QaRouteButton(
          identifier: 'qa-open-onboarding',
          label: 'Onboarding',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () => context.push('/qa/onboarding'),
        ),
        const SizedBox(height: MortSpacing.sm),
        _QaRouteButton(
          identifier: 'qa-open-safety',
          label: 'Safety',
          icon: Icons.health_and_safety_outlined,
          onPressed: () => context.push('/qa/safety'),
        ),
        const SizedBox(height: MortSpacing.sm),
        _QaRouteButton(
          identifier: 'qa-open-financial',
          label: 'Financial',
          icon: Icons.receipt_long_outlined,
          onPressed: () => context.push('/qa/financial'),
        ),
        const SizedBox(height: MortSpacing.sm),
        _QaRouteButton(
          identifier: 'qa-open-settings',
          label: 'Settings',
          icon: Icons.settings_outlined,
          onPressed: () => context.push('/qa/settings'),
        ),
        const SizedBox(height: MortSpacing.sm),
        _QaRouteButton(
          identifier: 'qa-open-permissions',
          label: 'Permissions',
          icon: Icons.admin_panel_settings_outlined,
          onPressed: () => context.push('/qa/permissions'),
        ),
        const SizedBox(height: MortSpacing.sm),
        _QaRouteButton(
          identifier: 'qa-open-legal',
          label: 'Legal',
          icon: Icons.gavel_outlined,
          onPressed: () => context.push('/qa/legal'),
        ),
      ],
    );
  }
}

class _QaRouteButton extends StatelessWidget {
  const _QaRouteButton({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String identifier;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: identifier,
    label: identifier,
    container: true,
    explicitChildNodes: true,
    child: MortButton(label: label, icon: icon, onPressed: onPressed),
  );
}
