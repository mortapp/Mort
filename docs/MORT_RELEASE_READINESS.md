# MORT Release Readiness

Status: Android closed-test candidate built; public production launch blocked.

## Operations checkpoint (2026-11-01)

Read-only Supabase checks identify `jxbnrkasktbhtiujkhay` as the current
`mort p` project (`ACTIVE_HEALTHY`); its organization is on the Free plan. The
current runtime status has maintenance off while payments, AI, job publishing,
the public marketplace, and real document collection remain disabled. The
project listing showed three active Edge Functions, all Stripe-related; it did
not show `send-push` or identity-verification functions. The Supabase
organization and project health do not prove backup recoverability.

The sandbox Stripe account still has enabled webhook URLs pointed at the prior
project. Those external provider settings were not changed. The current
project's deployed functions did not include `stripe-webhook`, so hosted Stripe
provider readiness remains unverified. No live Stripe account operations were
performed.

CI now references the current project for hosted QA. Protected GitHub secrets
were not read or changed; the owner must ensure the configured public-key,
database, service-role, and access-token secrets match the intended current
project before enabling those hosted jobs.

Backups, restore, RPO/RTO, alert receipt, on-call staffing, incident exercise,
Google OAuth against the current project, real push delivery, physical Android
critical flows, and iOS release validation remain unverified or blocked. See
the linked ops runbooks before any owner/provider activation.

The Vercel `mort-web` project currently reports a READY production deployment.
The team API reports Observability Plus is not enabled. Vercel rejected a
24-hour runtime-log query due to Hobby retention; a grouped error/fatal query
for the last 30 minutes returned no rows. This does not establish alert routing
or staffed monitoring. Repository email support remains a user-composed draft
to `mortapp.help@gmail.com`; Auth email transport and deliverability were not
verified through the available read-only tools.

## Owner actions for the Nov 5 readiness review

| Area | Required owner evidence |
|---|---|
| Backup and restore | Confirm protected `backend-operations` secrets without printing values; the metadata-only workflow needs the active database password and a 32+ character archive passphrase. Provision an isolated restore destination, add database/Auth/Storage-byte coverage and checksums, run the workflow, then complete a restore drill. Do not treat the metadata artifact as a data backup. |
| Google OAuth | In Google Cloud, verify the authorized callback `https://jxbnrkasktbhtiujkhay.supabase.co/auth/v1/callback`; in current Supabase Auth, verify the matching Web client and secret plus exact app redirects. Test approved-account web and installed APK sign-in. Keep the secret out of source, logs, and reports. |
| Identity verification | Provider selection and approval remain outstanding. Obtain provider/legal approval, deploy and verify the signed webhook/session handlers, then test only with synthetic identities. The current project listing did not include identity-verification functions. Do not enable real document collection. |
| Push | Deploy `send-push` only after Firebase/APNs setup and server-secret review; then pass Android and iPhone delivery, logout, token-rotation, and deep-link tests. The current project listing did not include `send-push`. |
| Email and support | Verify current Supabase Auth email transport and support-mailbox access with synthetic accounts; prove delivery and a staffed response path. Inbound case-email synchronization remains disabled. |
| Monitoring and incidents | Choose a supported log-retention and alerting plan, route alerts to named on-call owners, verify receipt, and exercise incident escalation. Vercel Observability Plus is not enabled and named incident coverage remains unverified. |
| Mobile release | Complete authenticated physical Android critical flows and iOS archive/device/APNs/TestFlight validation. Keep public marketplace, payments, AI, and real document collection disabled. |

## Verified Here

- Flutter 0.9.3+93 formatting, analyzer, 115 tests, web release build.
- Signed Android APK and obfuscated AAB for `com.mortapp.mobile`, minSdk 24, targetSdk 36; MORT app-module `lintRelease` passes.
- Upload certificate verification and no debug signing.
- API 36 emulator install, foreground launch, home/sign-in rendering, accessible semantics, empty-form validation, and no fatal log entries.
- Remote Supabase migration parity, schema error lint, 26-script regression, 30 isolation checks, 25 Stripe boundary scripts, and 8 focused support/PIN scripts.
- Source, dependency, sensitive-file, and binary artifact scans.

These hosted verification entries were recorded before the backend target
changed. They are historical evidence and were not rerun against current ref
`jxbnrkasktbhtiujkhay` during this operations review.

The final emulator run used the exact named APK. A transient emulator System UI ANR occurred after the native build; window focus and accessibility hierarchy proved it belonged to `com.android.systemui`. After dismissal, MORT was foregrounded and the launch/sign-in/validation/no-fatal checks passed. This does not substitute for a physical Android test.

## Not Verified

- Physical Android authenticated critical-flow matrix or Play pre-launch report.
- Any iPhone, macOS/Xcode, archive, signing, TestFlight, push, deep-link, camera, avatar, PIN, support, or Stripe device flow.
- Stripe provider end-to-end operations or live mode.
- External AI generation and provider dashboards.
- Qualified legal/tax/privacy/teen-safety review.
- Production monitoring, alert receipt, staffing, incident exercise, or restore drill.

Public marketplace, real identity collection, live payments, external AI, ads, and IAP must remain off. This is not production ready.

