import 'package:flutter_mort/core/routing/route_access.dart';
import 'package:flutter_mort/data/models/profile.dart';
import 'package:flutter_test/flutter_test.dart';

Profile profile({
  UserRole role = UserRole.teen,
  bool onboardingCompleted = true,
  String accountStatus = 'active',
}) {
  return Profile(
    id: 'user-id',
    role: role,
    displayName: 'MORT User',
    username: null,
    dob: DateTime(2010, 1, 1),
    city: 'Indianapolis',
    state: 'IN',
    onboardingCompleted: onboardingCompleted,
    accountStatus: accountStatus,
    verificationStatus: 'not_started',
    paymentPreference: 'none',
  );
}

void main() {
  group('evaluateRouteAccess', () {
    test('requires authentication before private routes', () {
      expect(
        evaluateRouteAccess(hasSession: false, profile: null),
        RouteAccessDecision.authenticationRequired,
      );
    });

    test('allows only onboarding routes for an incomplete profile', () {
      final incomplete = profile(onboardingCompleted: false);
      expect(
        evaluateRouteAccess(hasSession: true, profile: incomplete),
        RouteAccessDecision.onboardingRequired,
      );
      expect(
        evaluateRouteAccess(
          hasSession: true,
          profile: incomplete,
          allowIncompleteOnboarding: true,
        ),
        RouteAccessDecision.allow,
      );
    });

    test(
      'restricted accounts are blocked even before onboarding completes',
      () {
        expect(
          evaluateRouteAccess(
            hasSession: true,
            profile: profile(
              onboardingCompleted: false,
              accountStatus: 'suspended',
            ),
            allowIncompleteOnboarding: true,
          ),
          RouteAccessDecision.accountRestricted,
        );
      },
    );

    for (final status in [
      'suspended',
      'deletion_pending',
      'deleted',
      'banned',
    ]) {
      test('$status account remains blocked after Google session restore', () {
        expect(
          evaluateRouteAccess(
            hasSession: true,
            profile: profile(accountStatus: status),
          ),
          RouteAccessDecision.accountRestricted,
        );
      });
    }

    test('role guard rejects a different active role', () {
      expect(
        evaluateRouteAccess(
          hasSession: true,
          profile: profile(role: UserRole.teen),
          requiredRole: UserRole.adult,
        ),
        RouteAccessDecision.wrongRole,
      );
    });

    test('active matching role is allowed', () {
      expect(
        evaluateRouteAccess(
          hasSession: true,
          profile: profile(role: UserRole.guardian),
          requiredRole: UserRole.guardian,
        ),
        RouteAccessDecision.allow,
      );
    });
  });
}
