import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/mort_colors.dart';

/// Root-location and fallback-route knowledge shared by every back
/// affordance in the app (floating back button, MortHeader,
/// MortGlassHeader) so "where does back go" stays consistent no matter
/// which header widget a screen uses.
class MortBackNavigation {
  static const _rootLocations = {
    '/',
    '/splash',
    '/welcome',
    '/account-status',
    '/teen/home',
    '/teen/jobs',
    '/teen/saved',
    '/teen/applications',
    '/teen/safety',
    '/teen/messages',
    '/teen/profile',
    '/teen/portfolio',
    '/teen/skills',
    '/teen/availability',
    '/adult/home',
    '/adult/jobs',
    '/adult/applicants',
    '/adult/profile',
    '/guardian/home',
    '/guardian/linked-teens',
    '/guardian/approvals',
    '/guardian/permissions',
    '/guardian/safety-pings',
    '/guardian/activity',
    '/admin/home',
    '/support',
    '/messages',
    '/notifications',
    '/guide',
    '/monetization',
    '/legal-center',
    '/settings',
    '/partner/home',
    '/review',
    '/review/teen',
    '/review/adult',
    '/review/guardian',
    '/review/support',
    '/review/admin',
  };

  static String _normalizeLocation(String location) {
    try {
      return Uri.parse(location).replace(query: '').path;
    } catch (_) {
      return location;
    }
  }

  static bool isRootLocation(String location) {
    return _rootLocations.contains(_normalizeLocation(location));
  }

  static String fallbackRoute(String location) {
    final normalized = _normalizeLocation(location);
    if (normalized == '/auth/sign-in' || normalized == '/auth/sign-up') {
      return '/splash';
    }
    if (normalized == '/auth/forgot-password' ||
        normalized == '/auth-callback' ||
        normalized == '/auth-confirm' ||
        normalized == '/auth-recovery' ||
        normalized == '/auth/confirm' ||
        normalized == '/auth/recovery') {
      return '/auth/sign-in';
    }
    if (normalized == '/onboarding/age') return '/onboarding';
    if (normalized == '/onboarding/role') return '/onboarding/age';
    if (normalized == '/onboarding/profile') return '/onboarding/role';
    if (normalized == '/onboarding/skills') return '/onboarding/profile';
    if (normalized == '/onboarding/availability') return '/onboarding/skills';
    if (normalized == '/onboarding/transportation')
      return '/onboarding/availability';
    if (normalized == '/onboarding/payment')
      return '/onboarding/transportation';
    if (normalized == '/onboarding/guardian') return '/onboarding/payment';
    if (normalized == '/onboarding/preferences') return '/onboarding/guardian';
    if (normalized == '/onboarding/safety') return '/onboarding/preferences';
    if (normalized == '/onboarding/review') return '/onboarding/preferences';
    if (normalized.startsWith('/teen/jobs/')) return '/teen/home';
    if (normalized == '/teen/profile/edit') return '/teen/profile';
    if (normalized.startsWith('/teen/safety/applications/')) {
      return '/teen/safety';
    }
    if (normalized.startsWith('/teen/messages/')) return '/teen/messages';
    if (normalized.startsWith('/teen/applications/'))
      return '/teen/applications';
    if (normalized.startsWith('/teen/proof/')) return '/teen/applications';
    if (normalized.startsWith('/adult/post-job')) return '/adult/home';
    if (normalized.startsWith('/adult/jobs/') && normalized.endsWith('/edit')) {
      final segments = normalized.split('/');
      if (segments.length >= 4) {
        return '/adult/jobs/${segments[3]}';
      }
      return '/adult/jobs';
    }
    if (normalized.startsWith('/adult/jobs/')) return '/adult/home';
    if (normalized.startsWith('/adult/applicants/')) return '/adult/home';
    if (normalized.startsWith('/adult/proof-review/')) return '/adult/home';
    if (normalized.startsWith('/guardian/approvals/')) return '/guardian/home';
    if (normalized.startsWith('/guardian/')) return '/guardian/home';
    if (normalized.startsWith('/admin/reports/')) return '/admin/home';
    if (normalized.startsWith('/admin/verifications/')) return '/admin/home';
    if (normalized.startsWith('/admin/support/ticket/')) return '/admin/home';
    if (normalized.startsWith('/admin/')) return '/admin/home';
    if (normalized.startsWith('/messages/')) return '/messages';
    if (normalized.startsWith('/support/chat/')) return '/support/chat';
    if (normalized == '/support/chat/history') return '/support/chat';
    if (normalized == '/support/new' ||
        normalized.startsWith('/support/ticket/')) {
      return '/support';
    }
    if (normalized.startsWith('/guide/conversation/')) return '/guide';
    if (normalized == '/guide/delete-history') return '/guide/history';
    if (normalized == '/legal/terms' ||
        normalized == '/legal/privacy' ||
        normalized == '/legal/community-rules' ||
        normalized == '/legal/payment-disclaimer' ||
        normalized == '/legal/verification-disclaimer' ||
        normalized == '/legal/ad-disclosure' ||
        normalized == '/legal/subscription-disclosure' ||
        normalized == '/legal/teen-safety' ||
        normalized == '/legal/guardian-guide') {
      return '/legal-center';
    }
    if (normalized.startsWith('/contracts/')) return '/contracts';
    if (normalized.startsWith('/payments/')) return '/account-status';
    if (normalized.startsWith('/disputes/')) return '/account-status';
    if (normalized.startsWith('/trust/')) return '/trust/foundations';
    if (normalized.startsWith('/settings/')) return '/settings';
    if (normalized.startsWith('/mission/')) return '/account-status';
    if (normalized.startsWith('/partner/')) return '/partner/home';
    if (normalized.startsWith('/monetization/')) return '/monetization';
    if (normalized.startsWith('/review/')) return '/review';
    return '/account-status';
  }
}

class MortBackButton extends StatelessWidget {
  const MortBackButton({
    super.key,
    this.fallbackRoute,
    this.onPressed,
    this.confirmExit,
  });

  final String? fallbackRoute;
  final VoidCallback? onPressed;
  final Future<bool> Function(BuildContext context)? confirmExit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async {
          if (onPressed != null) {
            onPressed!();
            return;
          }

          final goRouter = GoRouter.maybeOf(context);
          final isGoRouterPresent = goRouter != null;
          final navigator = Navigator.maybeOf(context);
          final canPop = isGoRouterPresent
              ? context.canPop()
              : (navigator?.canPop() ?? false);
          final fallback = fallbackRoute;

          if (confirmExit != null) {
            final shouldExit = await confirmExit!(context);
            if (!shouldExit) return;
          }

          if (canPop) {
            if (goRouter != null) {
              goRouter.pop();
            } else if (navigator != null) {
              navigator.pop();
            }
            return;
          }

          if (fallback != null) {
            if (goRouter != null) {
              goRouter.go(fallback);
            } else if (navigator != null) {
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
              );
            }
          }
        },
        style: IconButton.styleFrom(
          backgroundColor: MortColors.glass,
          foregroundColor: MortColors.text,
          minimumSize: const Size.square(48),
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
