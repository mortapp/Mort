# MORT Back Navigation Report

## Summary

This report documents the current navigation behavior for visible and Android Back across MORT, the implemented shared back navigation helpers, and the route audit status for the Flutter app.

## Route Audit

The following routes are configured in `lib/core/routing/app_router.dart`.

### Top-level full-screen routes

- `/`
- `/splash`
- `/welcome`
- `/auth/sign-in`
- `/auth/sign-up`
- `/auth-callback`
- `/auth/confirm`
- `/auth/recovery`
- `/auth/forgot-password`
- `/onboarding`
- `/onboarding/age`
- `/onboarding/role`
- `/onboarding/profile`
- `/onboarding/skills`
- `/onboarding/availability`
- `/onboarding/transportation`
- `/onboarding/payment`
- `/onboarding/guardian`
- `/onboarding/safety`
- `/onboarding/preferences`
- `/onboarding/review`
- `/account-status`
- `/teen/home`
- `/teen/jobs`
- `/teen/jobs/:id`
- `/teen/saved`
- `/teen/applications`
- `/teen/applications/:id`
- `/teen/proof/:applicationId`
- `/teen/profile`
- `/teen/portfolio`
- `/teen/skills`
- `/teen/availability`
- `/teen/goals`
- `/teen/hustle-academy`
- `/teen/safety`
- `/adult/home`
- `/adult/post-job`
- `/adult/jobs`
- `/adult/jobs/:id`
- `/adult/jobs/:id/edit`
- `/adult/applicants`
- `/adult/applicants/:applicationId`
- `/adult/proof-review/:applicationId`
- `/adult/verification`
- `/adult/business-verification`
- `/adult/profile`
- `/adult/business`
- `/adult/analytics`
- `/guardian/home`
- `/guardian/linked-teens`
- `/guardian/approvals`
- `/guardian/approvals/:applicationId`
- `/guardian/permissions`
- `/guardian/safety-pings`
- `/guardian/activity`
- `/guardian/emergency-contacts`
- `/admin/home`
- `/admin/restricted-queues`
- `/admin/reports`
- `/admin/reports/:id`
- `/admin/verifications`
- `/admin/verifications/:id`
- `/admin/adult-id`
- `/admin/teen-school-id`
- `/admin/teen-alternatives`
- `/admin/business-verifications`
- `/admin/verification-appeals`
- `/admin/ban-appeals`
- `/admin/incidents`
- `/admin/person-mismatch`
- `/admin/sexual-safety`
- `/admin/grooming-signals`
- `/admin/abduction-concerns`
- `/admin/threats-violence`
- `/admin/property-theft`
- `/admin/account-sharing`
- `/admin/evidence-preservation`
- `/admin/lawful-requests`
- `/admin/jobs`
- `/admin/messages`
- `/admin/safety-pings`
- `/admin/users`
- `/admin/monetization`
- `/admin/payment-operations`
- `/admin/operational-alerts`
- `/admin/support`
- `/admin/support/ticket/:ticketId`
- `/admin/reviews`
- `/admin/action-logs`
- `/messages`
- `/messages/:conversationId`
- `/notifications`
- `/reviews/:applicationId`
- `/settings/reviews`
- `/settings/activity`
- `/settings/identity-verification`
- `/settings/account-trust`
- `/mission/pilot-eligibility`
- `/mission/partner-invitation`
- `/mission/partner-affiliation`
- `/mission/discreet-mode`
- `/mission/support-circle`
- `/mission/earnings-goals`
- `/mission/future-independence`
- `/mission/resources`
- `/mission/pilot-job-safety`
- `/mission/verification-wording`
- `/mission/document-review`
- `/partner/home`
- `/partner/participants/:organizationId`
- `/partner/invites/:organizationId`
- `/settings/device-security`
- `/settings/native-permissions`
- `/settings/release-diagnostics`
- `/settings/passkeys`
- `/settings/school-affiliation`
- `/settings/partner-code`
- `/settings/business-registry`
- `/settings/digital-id`
- `/settings/trust-appeal`
- `/admin/account-trust`
- `/settings/safety-circle`
- `/settings/safety-cases`
- `/settings/security-sessions`
- `/settings/active-sessions`
- `/settings/account-deletion`
- `/settings`
- `/settings/blocked-users`
- `/settings/profile`
- `/settings/connected-accounts`
- `/settings/guardian-mode`
- `/settings/username`
- `/settings/subscription`
- `/settings/ad-preferences`
- `/settings/privacy`
- `/settings/legal`
- `/legal-center`
- `/legal-center/teen-summary`
- `/legal-center/version/:versionId`
- `/contracts`
- `/contracts/:contractId`
- `/contracts/:contractId/change`
- `/contracts/:contractId/payment`
- `/contracts/:contractId/fund`
- `/payments/:obligationId/nonpayment`
- `/disputes/:disputeId`
- `/disputes/:disputeId/export`
- `/trust/foundations`
- `/trust/document-capture`
- `/trust/liveness`
- `/trust/teen-verification`
- `/trust/teen-verification/capture`
- `/trust/device-auth`
- `/support`
- `/support/chat`
- `/support/chat/history`
- `/support/chat/:conversationId`
- `/support/new`
- `/support/ticket/:ticketId`
- `/jobs/progress/:applicationId`
- `/guide`
- `/guide/history`
- `/guide/delete-history`
- `/guide/conversation/:conversationId`
- `/monetization`
- `/monetization/paywall`
- `/monetization/ad-free`
- `/monetization/username-change`
- `/monetization/job-boost`
- `/monetization/restore`
- `/monetization/manage`
- `/legal/terms`
- `/legal/privacy`
- `/legal/community-rules`
- `/legal/payment-disclaimer`
- `/legal/verification-disclaimer`
- `/legal/ad-disclosure`
- `/legal/subscription-disclosure`
- `/legal/teen-safety`
- `/legal/guardian-guide`

## Implementation Notes

- `MortScreen` now uses `GoRouter.maybeOf(context)` safely and will not throw when the shared shell renders outside a GoRouter context.
- `MortHeader` also uses `GoRouter.maybeOf(context)` to determine root destination and fallback route safely.
- `MortBackButton` now checks for GoRouter presence before calling `context.canPop()` or `context.pop()`, with a `Navigator` fallback.
- The fallback route mapping is centralized in `MortBackNavigation.fallbackRoute`.
- The existing audit script is retained because it works and writes the route list accurately.

## Verification

- `flutter test test/mort_back_navigation_test.dart -r expanded` passes.

## Next Work

1. Update `docs/MORT_CODEX_OVERNIGHT_STATE.md` with current checkpoint state.
2. Run `dart format`, `flutter analyze`, and full `flutter test` after any further source edits.
3. Build the signed QA APK and install on the Samsung device.
