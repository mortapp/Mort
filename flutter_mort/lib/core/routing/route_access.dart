import '../../data/models/profile.dart';

enum RouteAccessDecision {
  allow,
  authenticationRequired,
  onboardingRequired,
  accountRestricted,
  wrongRole,
}

RouteAccessDecision evaluateRouteAccess({
  required bool hasSession,
  required Profile? profile,
  UserRole? requiredRole,
  bool allowIncompleteOnboarding = false,
}) {
  if (!hasSession) return RouteAccessDecision.authenticationRequired;
  if (profile != null && !profile.isActive) {
    return RouteAccessDecision.accountRestricted;
  }
  if (profile == null || !profile.onboardingCompleted) {
    return allowIncompleteOnboarding
        ? RouteAccessDecision.allow
        : RouteAccessDecision.onboardingRequired;
  }
  if (requiredRole != null && profile.role != requiredRole) {
    return RouteAccessDecision.wrongRole;
  }
  return RouteAccessDecision.allow;
}
