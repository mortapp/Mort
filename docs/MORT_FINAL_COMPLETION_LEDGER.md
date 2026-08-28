# MORT Final Completion Ledger

Updated: 2026-08-09 (America/Indianapolis)

Repository source, hosted Supabase state, signed artifacts, and private physical
QA evidence are the sources of truth. MORT is not production-ready.

## Current State

- Branch: `feature/compact-onboarding-and-screen-polish`
- Runtime artifact commit:
  `79630b195098a2c5428a30104b55cfec27ea764f`
- Flutter version: `0.9.15+105`
- Android package: `com.mortapp.mobile`
- Hosted Supabase project: `rakjydmgwwgtdislanbt`
- Public marketplace: fail-closed
- Real verification provider: not connected
- Real ID collection: disabled
- Payments/escrow: disabled

## Verification Ledger

| Area | Status | Evidence |
|---|---|---|
| Real Google callback | PASS on final APK | Authorized chooser selection, PKCE return, MORT foreground, no loop/challenge; private evidence under ignored `artifacts/` |
| Invalid matrix remediation | PHYSICALLY CLEARED | Final callback plus five cold starts: zero `TransformLayer`/invalid-matrix entries |
| Predictive Back | PASS | Active callback, no not-enabled warning; safe onboarding and legal-link Back checks pass |
| Legacy onboarding repair | PASS locally/remotely | Migration `20260809040544`; caller-bound QA; no legal acknowledgement synthesis |
| Post-OAuth onboarding route | PASS after repair | Account Status and role guards use persisted server `resume_path`; focused 44-test suite and final APK physical retest |
| Flutter | PASS | Analyzer zero issues; full suite 352 passed, two intentional provider-gated skips |
| Hosted Supabase | PASS | Expanded 46-script regression, migration parity, lint, advisors, RLS, and storage checks |
| Samsung session restoration | PASS | Final APK 5/5 cold starts restored Safety; no OAuth auto-launch, blanks, route errors, or crashes |
| Samsung Home/resume | PASS | 3/3 on the `0.9.15` candidate; runtime route repair did not touch lifecycle code |
| Large text | PASS | Safety top/bottom reachable at 1.3; font scale restored to 1.0 |
| Screen off/on | PARTIAL - HUMAN UNLOCK | Process persisted; secure Samsung keyguard appeared and was not bypassed |
| Offline physical cold start | BLOCKED - WIRELESS ADB | Disabling network would sever the only device-control channel; focused offline/session tests pass |
| Authorized role | Teen, incomplete | QA-safe onboarding through Safety; owner legal acknowledgements not selected |
| Teen role matrix | BLOCKED - HUMAN LEGAL ACTION | Dashboard, Messages, Notifications, and Settings remain behind Safety completion |
| Adult Back matrix | NOT APPLICABLE | The authorized account is Teen; automated Adult route/Back coverage passes |
| Final APK/AAB | PASS | Signed, package/version/SDK/permissions verified, binary secret scan clean, 18/18 16 KB alignment |

## Defects Closed In 0.9.15

1. Legacy validated profiles missing `onboarding_progress` could not advance.
   The private trigger/backfill restores only validated age/role prerequisites.
2. Android predictive Back did not consistently invoke route fallbacks. Shared
   screens now use `PopScope` and the server onboarding order.
3. Safety legal references used replacement navigation and lost their caller.
   They now use pushed routes and return to Safety.
4. Post-OAuth Account Status used the obsolete compact onboarding route while
   cold starts used server progress. Both now use the persisted resume path.

## Final Artifacts

| Artifact | Size | SHA-256 |
|---|---:|---|
| `artifacts/release-0.9.15+105/mort-closed-test-0.9.15.apk` | 69,287,402 | `A4578C163638A952B8C1B9F6BE8CC190B3F38D1C7B927A5F4AEA200C6E918E10` |
| `artifacts/release-0.9.15+105/mort-closed-test-0.9.15.aab` | 52,164,950 | `84758C39817B42129282CBD74BD9FAC2B37854CCEA04EC4CA81946793DFFA144` |

Both manifests record the clean runtime commit. The protected closed-test
profile keeps public marketplace, verification, payments, ads/IAP, remote push,
crash reporting, and public activation disabled.

## Deferred And External Gates

- `DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT`: Supabase leaked-password
  protection requires Pro. On upgrade, enable it immediately and rerun Auth
  security advisors.
- Owner/counsel approval is still required for Terms, Privacy, community and
  teen-safety rules, retention, insurance, tax/payment, and jurisdiction.
- Real verification provider approval, moderation/support/on-call staffing,
  provider credentials, and incident response ownership remain external.
- Play Console declarations, processed-AAB SDK review, tester cohort, review,
  and production access remain external.
- iPhone manual testing, Xcode signing, TestFlight, App Store privacy manifests,
  and App Store/legal review were not done.

## Warning Before Real Users

Do not open the public marketplace, collect real identity documents, accept
payments, represent adults as provider-verified, or invite teen users beyond a
controlled closed test until the human and external gates above are complete.
