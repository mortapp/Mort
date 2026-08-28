# MORT Support Chatbot Implementation Report

Date: 2026-07-29  
Repository: `C:\Users\micha\Mort`  
Flutter app: `C:\Users\micha\Mort\flutter_mort`  
Supabase project: `rakjydmgwwgtdislanbt`  
Candidate version: `0.9.11+101`

## Result

Part A secure session persistence remains implemented and is documented in
`docs/MORT_SECURE_SESSION_PERSISTENCE_0_9_10_REPORT.md`. Part B is implemented
as a real Flutter, Supabase Postgres, Storage, and Edge Function support system.
The hosted backend, RLS boundaries, private attachment flow, human handoff,
rate limits, and deterministic safety evaluation were exercised against the
linked Supabase project.

This is not a production-ready declaration. The optional external AI provider
is deliberately disabled, Google Play version code `101` could not be checked
against Play Console history, physical-phone testing is incomplete, iOS was not
tested, and public marketplace launch remains closed.

## Backend

Nine additive migrations implement the assistant foundation and hardening:

1. `20260729195632_mort_support_chatbot_foundation.sql`
2. `20260729201015_mort_support_chatbot_rpc_hardening.sql`
3. `20260729211932_mort_support_provider_rate_limit.sql`
4. `20260729212144_mort_support_internal_auth_probe.sql`
5. `20260729212722_mort_support_safety_priority_hardening.sql`
6. `20260729214636_mort_support_adversarial_triage.sql`
7. `20260729215533_mort_support_evaluation_classifier_fixes.sql`
8. `20260729215937_mort_support_postgres_word_boundaries.sql`
9. `20260729224551_mort_support_global_provider_budget.sql`

The remote inventory found all 16 expected support tables, all with RLS and
forced RLS, 22 support policies, and 29 support database functions. Existing
`support_tickets`, ticket messages, support evidence, reports, blocks, and admin
queues were reused instead of replaced.

The private `support-attachments` bucket is non-public, limited to 5 MiB, and
allows JPEG, PNG, WebP, and PDF. Authorization records use opaque object paths,
short upload windows, checksums, MIME/extension/size checks, and expiring signed
downloads. Executables, archives, key material, payment-card images, and raw ID
documents are rejected.

Nine approved knowledge documents and nine indexed chunks are published in the
hosted database. Postgres full-text search supplies source titles, routes, and
URLs for citations.

## Edge Functions

The following 13 functions are deployed and active with JWT verification:

- `support-chat`
- `support-intent-classify`
- `support-kb-search`
- `support-create-ticket`
- `support-escalate`
- `support-tool-execute`
- `support-upload-authorize`
- `support-feedback`
- `support-report-ai-response`
- `support-admin-copilot`
- `support-safety-triage`
- `support-retention-cleanup`
- `support-evaluation-runner`

Shared runtime controls verify the Supabase user, cap request bodies at 24 KiB,
use correlation IDs, return no-store responses, bound database and provider
timeouts, keep raw content out of logs, and restrict tools to an allowlist.
Provider output is treated as untrusted text and cannot execute tools or make
moderation, hiring, identity, payment, legal, medical, or emergency decisions.

Provider modes exist for Anthropic, deterministic, disabled, and mock testing.
Server configuration is currently `SUPPORT_AI_ENABLED=false` and
`SUPPORT_AI_PROVIDER=disabled`. No provider key or model is configured. Those
settings and all privileged credentials remain server-side only.

## Safety And Handoff

Database and Edge fallback classifiers assign levels 0 through 3 before any
provider use. Level 2 and 3 content is provider-ineligible. Covered high-risk
language includes self-harm, threats, weapons, inability to leave, sexual
assault, CSAM indicators, grooming secrecy, job PIN/code requests, credentials,
fraud, exact-address requests, prompt injection, and cross-user exfiltration.

Any user can request a person. High-risk flows create one idempotent real
support ticket and event record. The answer never claims that police or an
ambulance was dispatched. Guardians receive no automatic access to a teen's
private support conversation or case. Staff reads use audited security-definer
RPCs; direct staff table reads remain blocked.

Ordinary chat, safety chat, handoff, attachment, download, tool, feedback, and
provider calls have separate database rate limits. Safety remains available
after ordinary chat throttles. External provider use has both a per-user cap of
5 per day and a service-only global cap of 500 per day.

## Flutter

The app now includes real support chat, private history, conversation restore,
loading/empty/error/typing states, retries, quick replies, citations, feedback,
AI-response reporting, human handoff, Safety Center access, and safe image
attachment upload. Images are selected without full metadata and re-encoded
before upload. The app contains no AI key or Supabase service-role credential.

Routes are `/support/chat`, `/support/chat/history`, and
`/support/chat/:conversationId`. Existing support tickets and human case screens
remain available. Admin queue filters include new, waiting parties, urgent
safety, verification, dispute, evidence, account access, technical, AI-reported,
escalated, and resolved states.

## Verification

Real final results:

- `npx -y deno check supabase/functions/support-chat/index.ts`: passed.
- Transaction dry-runs for each final classifier and global-budget migration:
  passed and rolled back.
- `npx supabase db push --linked ... --yes`: all nine support migrations are
  applied remotely.
- 13-function deployment loop: 13 deployed successfully.
- `node scripts/qa-support-chatbot.mjs`: passed all hosted journeys with four
  isolated users and cleanup.
- `node scripts/qa-support-global-budget.mjs`: passed; service-only use worked
  inside a rollback transaction and ordinary users were denied.
- `node scripts/audit-support-chatbot-remote.mjs`: 16/16 tables found, zero RLS
  failures, 22 policies, 29 functions, private bucket confirmed.
- `support-evaluation-runner`: 150/150 passed, final run
  `c2b3645c-3e9a-4975-ae17-80b89272fa5c`.
- `.\scripts\run-final-supabase-regression.ps1`: 31/31 scripts passed.
- `dart format lib test integration_test`: 178 files, zero final changes.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 223 passed, 2 expected skips, 0 failed.
- Android native integration: 1/1 passed on API 36.
- `flutter build web --release`: passed, including Wasm dry run.
- Source secret scan: passed.
- Sensitive-file scan: passed; 1,667 files, 52 reviewed media files, and 10
  available protected values checked.
- APK/AAB secret scan: passed; 915 extracted entries, 5 available protected
  values, and Google client-secret markers checked.

## Signed Candidates

APK: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.11.apk`

- Size: 62,650,216 bytes
- SHA-256: `032A7BA42DE833DB603FCAE24A9DDB59BD3C448490076A605366446DC19F51C2`

AAB: `C:\Users\micha\Mort\build\play\mort-closed-test-0.9.11.aab`

- Size: 48,379,182 bytes
- SHA-256: `C13B65CB74F58C664AFBB6589EDD3F330B5CE687E60015CDA34CBA4EE14212B5`

Both use package `com.mortapp.mobile`, min SDK 24, target SDK 36, version
`0.9.11+101`, R8/resource shrinking, and the existing MORT upload certificate.
The API 36 release launch was reproduced successfully with a live process and
no fatal Android/Flutter logs after one initial emulator timing failure.

## Bugs Fixed During This Pass

1. The Edge fallback classifier did not match all database intents.
2. The shared Supabase client type inferred a `never` schema and hid 35 Deno
   type errors.
3. Common wording for "kill me", "my guardian", verification, and account
   deletion was misclassified.
4. PostgreSQL `\b` was incorrectly used as a word boundary for PIN, CSAM, SSN,
   CVC, and CVV.
5. Prompt injection and cross-user transcript requests were not explicit
   deterministic level-2 rules.
6. The Flutter support widget fake had an analyzer warning.
7. The API 36 harness discarded fatal logs when the app process disappeared.
8. Emulator snapshot state made native QA intermittent; cold/read-only support
   and a dedicated integration runner were added.
9. Versioned emulator screenshots were not exact-hash reviewed by the privacy
   scanner.
10. Provider use lacked a server-only global daily budget.

## Remaining Blockers

- Verify version code `101` is unused in authenticated Play Console before any
  upload. Browser access redirected to the public Console page.
- Run physical Android session persistence, upgrade, Google OAuth, notification,
  camera/photo, offline, and accessibility checks.
- Configure and review an external provider only if MORT chooses to enable it;
  then run model-specific quality and red-team evaluation.
- Complete iPhone, TestFlight, Keychain, notification, camera/photo, and StoreKit
  testing later. None is claimed here.
- Complete App Store and Play legal, privacy, age-assurance, moderation,
  incident-response, teen-safety, and child-safety review.
- Connect a production identity-verification provider before opening the public
  marketplace. Real ID collection remains disabled.
- Staff the human support and safety queues with documented SLAs before real
  users.

