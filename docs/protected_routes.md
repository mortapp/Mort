# Protected Routes Audit

This file lists routes wrapped with `SensitiveScreenProtection` in the router and notes whether they are narrowly sensitive or should remain screenshotable.

Protected routes found in `lib/core/routing/app_router.dart`:

- /teen/proof/:applicationId -> ProofUploadScreen (sensitive) - KEEP
- /adult/proof-review/:applicationId -> ProofReviewScreen (sensitive) - KEEP
- /admin/payment-operations -> AdminPaymentOperationsScreen (admin sensitive) - KEEP (admin)
- /admin/operational-alerts -> AdminOperationalAlertsScreen (admin sensitive) - KEEP (admin)
- /messages -> MessagesScreen (may contain private messages) - REVIEW (sensitive)
- /messages/:conversationId -> MessageThreadScreen (private messages) - REVIEW (sensitive)
- /notifications -> NotificationCenterScreen (may contain PII) - REVIEW
- /settings/safety-cases -> SafetyCasesScreen (sensitive) - KEEP
- /settings/security-sessions -> SecuritySessionsScreen (sensitive) - KEEP
- /settings/active-sessions -> AccountSessionsScreen (sensitive) - KEEP
- /settings/account-deletion -> AccountDeletionRequestScreen (sensitive) - KEEP
- /applications/:applicationId/safety -> JobSafetyWorkspaceScreen (sensitive) - KEEP
- /report/* (job/message/user/review) -> ReportScreen (sensitive) - KEEP
- /disputes/:disputeId/export -> EvidenceExportScreen (sensitive) - KEEP
- /admin/payment-operations (duplicate) - KEEP

Ordinary routes that must remain screenshotable (verified present and NOT wrapped):

- /onboarding and subroutes
- /teen/jobs, /teen/applications, /teen/saved
- /support/chat and support ticket routes
- Job feed, Job details (non-sensitive views)
- Profile and settings screens (except explicitly sensitive sub-screens above)

Notes:
- Support chat and tickets are intentionally NOT wrapped and remain screenshotable.
- Admin and evidence-related routes remain protected.
- `Messages` and `NotificationCenter` are currently protected; review policy required — they may contain private message contents and notification previews and are reasonable to protect in a closed pilot.

If you want any protected route removed or added, list them and I'll apply the change.
