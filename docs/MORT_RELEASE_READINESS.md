# MORT Release Readiness

## Current distribution and backend state — 2026-10-26

The owner confirms MORT is in public production. Google Play production access
was granted, as shown in the supplied Play Console evidence. The build and
device evidence below records an earlier 0.9.3+93 closed-test verification
pass; it is historical evidence, not the current distribution status.

The hosted backend currently reports `release_mode=closed_test`,
`marketplace_mode=closed_pilot`, public marketplace disabled, remote push
disabled, live billing disabled, and real document collection disabled. These
are backend capability settings and are tracked separately from the app's
public production distribution.

### Live owner and security gates (read-only snapshot — 2026-10-26)

`get_public_release_readiness()` reports public activation and legal readiness
false. Owner, counsel, Play declarations, privacy and support contacts,
moderation staffing, child-safety contact, incident on-call, and identity
provider readiness are not approved. The required published legal document
keys are missing: `ai_support_disclosure_0_9_3_draft`,
`mort_community_guidelines`, `mort_data_retention_and_deletion`,
`mort_guardian_terms`, `mort_identity_review_disclosure`,
`mort_location_and_meeting_policy`, `mort_moderation_and_appeals_policy`,
`mort_payment_dispute_policy`, `mort_privacy_policy`,
`mort_prohibited_work_policy`, `mort_safety_rules`,
`mort_terms_of_service`, and `mort_terms_of_use`.

The same readiness check reports one active `super_admin` role assignment
without an expiry. The owner must resolve it through a reviewed procedure
that preserves the last active administrator and records an audit event.

Supabase's security advisor currently reports five anonymous and 344
authenticated `SECURITY DEFINER` RPC grants. These broad advisor findings need
reconciliation against the existing function-by-function security review;
they are not, by themselves, evidence of exploitable vulnerabilities. The
advisor also reports leaked-password protection disabled. The existing
Supabase audit confirms this is unavailable on the project's Free plan and is
deferred until a separately authorized plan upgrade; current password
mitigations and the follow-up procedure are recorded in
[Enable Leaked-Password Protection](ENABLE_LEAKED_PASSWORD_PROTECTION.md).

No live role, Auth, legal, or activation setting was changed during this
review. Reconcile hosted migration-history drift before applying schema
changes.

## Historical verification evidence (0.9.3+93)

## Verified Here

- Flutter 0.9.3+93 formatting, analyzer, 115 tests, web release build.
- Signed Android APK and obfuscated AAB for `com.mortapp.mobile`, minSdk 24, targetSdk 36; MORT app-module `lintRelease` passes.
- Upload certificate verification and no debug signing.
- API 36 emulator install, foreground launch, home/sign-in rendering, accessible semantics, empty-form validation, and no fatal log entries.
- Remote Supabase migration parity, schema error lint, 26-script regression, 30 isolation checks, 25 Stripe boundary scripts, and 8 focused support/PIN scripts.
- Source, dependency, sensitive-file, and binary artifact scans.

The final emulator run used the exact named APK. A transient emulator System UI ANR occurred after the native build; window focus and accessibility hierarchy proved it belonged to `com.android.systemui`. After dismissal, MORT was foregrounded and the launch/sign-in/validation/no-fatal checks passed. This does not substitute for a physical Android test.

## Not verified during that historical pass

- Physical Android authenticated critical-flow matrix or Play pre-launch report.
- Any iPhone, macOS/Xcode, archive, signing, TestFlight, push, deep-link, camera, avatar, PIN, support, or Stripe device flow.
- Stripe provider end-to-end operations or live mode.
- External AI generation and provider dashboards.
- Qualified legal/tax/privacy/teen-safety review.
- Production monitoring, alert receipt, staffing, incident exercise, or restore drill.

The backend capability snapshot above records the current disabled services.
The verification bullets in this historical report do not certify current
builds, production operations, or device coverage.
