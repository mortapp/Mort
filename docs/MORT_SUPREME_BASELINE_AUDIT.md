# MORT Supreme Baseline Audit

Recorded: 2026-07-29 (America/Indianapolis)  
Repository: `C:\Users\micha\Mort`  
Authoritative client: `C:\Users\micha\Mort\flutter_mort`  
Branch: `mort-supreme-production-readiness`  
Starting commit: `f566885453786f1fbdea08291b1b646a5cabe1bc`  
Version: `0.9.11+101`  
Android package / iOS bundle: `com.mortapp.mobile`  
Supabase project: `rakjydmgwwgtdislanbt`

## Audit Boundary

This report records the repository before Supreme runtime changes. The starting
tree contained 236 preserved changes relative to the last commit: 102 modified,
2 deleted, and 132 untracked paths. They are the accumulated MORT 0.9.6 through
0.9.11 implementation, generated design assets, QA automation, backend
migrations, support functions, and evidence reports. Nothing was reset or
discarded. Every path is classified in `MORT_SUPREME_DIRTY_INVENTORY.md`.

The prior branch name was `production-readiness-0.9.7`. A new branch was
created without changing the working tree. Historical reports that identify
0.9.7 through 0.9.10 remain valid evidence for those versions but are not the
current release identity.

## Verified Foundations

The secure authentication/session system and MORT Support are regression
locked. Fresh verification produced:

- Flutter: 223 passed, 2 expected skips, 0 failed.
- Supabase regression: 31 scripts passed.
- Support safety evaluation: 150/150 passed; run
  `690624cb-8441-4d52-acba-1c90602c27f4`.
- Support remote QA: all exercised journeys passed with synthetic users and
  cleanup.
- Support database: 16/16 tables, zero RLS/forced-RLS failures, 22 policies,
  29 support functions, 9 published knowledge documents/chunks, and a private
  5 MiB support attachment bucket.
- Support Edge Functions: 13/13 active and `verify_jwt=true`.
- Migration parity: 126 local and remote migrations aligned; dry-run reported
  the remote database up to date.
- Existing source ZIP, signed APK, and signed AAB hashes exactly match the
  0.9.11 reports.

These systems may be extended only with equal or stronger isolation and with
no reduction in the 223, 31, or 150 regression baselines.

## Artifact Recalculation

| Artifact | Bytes | Files | SHA-256 |
|---|---:|---:|---|
| `artifacts/mort-support-chatbot-0.9.11-source-clean.zip` | 5,971,070 | 1,610 | `3619371FB46DEEF271372AD1F8509769C72A31BF1DBC6B5913FEF4D27B3A870C` |
| `build/play/mort-closed-test-0.9.11.apk` | 62,650,216 | n/a | `032A7BA42DE833DB603FCAE24A9DDB59BD3C448490076A605366446DC19F51C2` |
| `build/play/mort-closed-test-0.9.11.aab` | 48,379,182 | n/a | `C13B65CB74F58C664AFBB6589EDD3F330B5CE687E60015CDA34CBA4EE14212B5` |

## Backup And Inventory

The ignored local Phase 0 backup directory is:

`C:\Users\micha\Mort\backups\mort-supreme-phase0-20260729-194057`

It contains the complete 126-file local migration archive, Supabase
configuration, full dirty-tree inventory, diff statistics, a privacy-safe
storage inventory, and a PostgreSQL metadata snapshot with relation, column,
constraint, index, function definition, trigger, policy, grant, migration,
bucket, object-count, and selected row-count metadata. The metadata snapshot
contains no user rows.

`supabase db dump` was attempted but did not complete because the CLI requires
Docker for `pg_dump` on this machine and Docker Desktop was not running. The
failed output file is zero bytes and is not counted as a backup. The existing
non-Docker backup script completed instead:

- 274 relations
- 297 policies
- 443 functions
- 126 migrations
- metadata snapshot SHA-256
  `07558EA69363B5D0E6D91214DFCEF1839CE37DCA4595D022852433FCF37594A2`
- local migration archive SHA-256
  `CE556834F3F86BC849EE5538724234243607F323B84ED5A40E3329A990A3DCB1`
- storage inventory SHA-256
  `2C907A6906688562D9817B468AC4FFD3E5C1C14AEF93B63C7363CD6E68F37E20`

All nine inventoried storage buckets are private. The inventory read counts
only, not object names, paths, or contents.

## Toolchain

| Tool | Measured state |
|---|---|
| Flutter | 3.41.2 stable, framework `90673a4eef` |
| Dart | 3.11.0 |
| Flutter Android SDK | SDK 36.1.0, platform 36, build-tools 36.1.0 |
| Android Studio JDK | 21.0.8 |
| Gradle launcher | 8.14 on JDK 17.0.17 |
| Shell `java` | Oracle Java 8u481; not used by the Gradle wrapper |
| Node | 24.12.0 |
| npm | 11.6.2 |
| pnpm | 10.28.0 |
| Supabase CLI | 2.109.0; 2.110.0 is available |
| Android emulator | `Medium_Phone_API_36.1` installed; not booted at audit time |
| ADB devices | none connected at audit time |

`flutter doctor -v` passed Flutter, Windows, Android, Chrome, connected web and
desktop targets, and network checks. The unrelated Windows desktop Visual
Studio workload is incomplete; it does not block Android or web work.

## Real And Working

- Hosted Supabase Auth with PKCE, email flows, secure native session storage,
  restoration gate, explicit local/global logout, account-state routing, and
  user-scoped cache invalidation.
- Server-backed profiles, role routing, jobs, applications, saved jobs,
  messaging, guardian linking, reports, blocks, notifications, evidence,
  contract/PIN lifecycle, disputes, account deletion, admin queues, and private
  storage boundaries exercised by the remote suite.
- MORT Support deterministic assistant, knowledge citations, human handoff,
  private uploads, audited staff access, retention controls, rate limits, and
  safety escalation.
- Flutter navigation includes public, auth, onboarding, teen, adult, guardian,
  reviewer, support, moderation/admin, safety, legal, payments-disabled, and
  mission-pilot routes.
- Android release configuration uses package `com.mortapp.mobile`, min SDK 24,
  target/compile SDK 36, R8/resource shrinking, no debug-signing fallback,
  cleartext disabled, backup disabled, and an explicit deep-link allowlist.
- Existing 0.9.11 APK/AAB are signed with the previously verified upload
  certificate. New signing credentials are not presently exported to this
  process and must not be inferred from old artifacts.

## Mocked Or Synthetic-Only

- Reviewer/demo mode is local, compile-gated test UX and is forbidden from
  production profiles.
- Identity sandbox paths use synthetic QA only. No real adult ID provider is
  connected and raw identity collection is disabled.
- Support contains a mock provider implementation for tests, while deployed
  provider mode is disabled and deterministic support remains available.
- Backend QA creates isolated synthetic accounts/jobs and removes only the data
  it creates. Eleven older QA accounts predate this run and were preserved for
  owner review.

## Deliberately Disabled

- Public marketplace and public activation.
- Live marketplace payments, transfers, refunds, payouts, ads, and IAP in the
  distributed closed-test profile.
- Real identity verification and real document collection.
- External support AI.
- Remote push in the Flutter release profile.
- Crash-reporting provider in the Flutter release profile.
- Production reviewer mode.

These are fail-closed states, not completed external integrations.

## Incomplete Or Externally Gated

- Production push credentials, provider delivery, token lifecycle, and physical
  foreground/background/terminated testing.
- Crash-provider credentials, privacy approval, release event verification,
  alerts, and operational dashboards.
- Adult identity provider selection/contract, sandbox credentials, webhook
  approval, retention review, and production verification.
- Compliant marketplace payment/payout provider activation and minor payout
  policy.
- Moderation/support staffing, on-call coverage, training acceptance, and
  incident exercises.
- Attorney approval for Indiana youth labor, minors, UGC, location, identity,
  privacy, payments, and guardian terms.
- Full Android API/device matrix, physical Android lifecycle/Google OAuth,
  Play pre-launch report, and confirmation that version code 101 is unused.
- macOS/Xcode build, physical iPhone, TestFlight, and App Store review.
- Complete Spanish localization and measured TalkBack/manual accessibility
  verification.

## Security And Data Risks

1. `supabase db lint --level warning` reports
   `private.support_classify_message` as `IMMUTABLE` while it contains a stable
   expression. This is a correctness/optimizer declaration defect, not a known
   data exposure. Repair must retain the 150/150 and chatbot regression lock.
2. RevenueCat event processing has two explicit `text` to `text[]` initializer
   warnings. IAP is absent from this launch build, but the server function
   should be corrected and regression tested.
3. Identity functions intentionally expose unused-parameter warnings because
   production verification is disabled. They remain fail-closed stubs and must
   not be presented as a live provider.
4. `pilot_job_reviews` has no policy in the mission audit. It also has no
   anonymous privilege; its intended service-only boundary must be confirmed
   before any client use.
5. The backend is large: 274 relations and 443 functions. Migration-only
   changes, parity checks, database lint, RLS tests, and cross-user tests are
   mandatory to control drift.
6. Physical OAuth, KeyStore/Keychain lifecycle, notification privacy, camera,
   location, and accessibility behavior remain unverified.

Supabase leaked-password protection remains **DEFERRED - PLAN-LIMITED SECURITY
ENHANCEMENT**. It is not classified as an unresolved code security bug. Current
mitigations are password length/complexity, Auth rate limits, email
verification, RLS, account restrictions, and secure reset. When the project is
upgraded to Pro, enable leaked-password protection immediately and rerun Auth
security advisors.

## Starting Readiness Matrix

| Area | Starting status | Evidence boundary |
|---|---|---|
| Android closed-test app | `100% VERIFIED` for 0.9.11 artifacts | Signed/hash-verified; physical device not included |
| Core Flutter UI/navigation | `INCOMPLETE` | Broad route/component coverage; full responsive/accessibility audit pending |
| Authentication/session | `100% VERIFIED` automated baseline | Physical lifecycle and real Google account selection pending |
| Onboarding | `INCOMPLETE` | Role/profile/transportation paths exist; complete resumability matrix pending |
| Jobs/applications/messaging/PIN | `INCOMPLETE` | Remote lifecycle/isolation passes; full emulator journey matrix pending |
| Backend/migrations/RLS/storage | `100% VERIFIED` for current automated scope | 126 aligned migrations, 31 scripts pass; lint warnings remain |
| Account deletion/security/privacy | `CODE-COMPLETE / MANUAL VERIFICATION REQUIRED` | Remote processor QA passes; policy/legal/device verification open |
| Support chatbot/human support | `100% VERIFIED` automated baseline | Real staffing and external AI remain external gates |
| Push notifications | `INCOMPLETE` | Backend pieces exist; Flutter provider and credentials disabled |
| Crash reporting/monitoring | `INCOMPLETE` | Abstraction exists; real provider disabled |
| Identity verification | `CODE-COMPLETE / PROVIDER APPROVAL REQUIRED` architecture only | Sandbox synthetic; production provider absent |
| Payments/payouts/disputes | `CODE-COMPLETE / PROVIDER APPROVAL REQUIRED` architecture only | Live processing disabled; policy/legal gates open |
| Moderation/safety operations | `CODE-COMPLETE / STAFFING REQUIRED` in current backend scope | Staffing and exercises absent |
| Legal/teen-safety compliance | `CODE-COMPLETE / LEGAL APPROVAL REQUIRED` for existing drafts | Attorney and owner approval absent |
| Android emulator/device QA | `INCOMPLETE` | API 36 launch/native smoke previously passed; 50-journey matrix not complete |
| Google Play readiness | `INCOMPLETE` | Console access/version-code check/pre-launch report absent |
| iOS/TestFlight/App Store | `BLOCKED` for native verification | Windows host; code audit and Mac handoff still required |
| Web/admin portals | `INCOMPLETE` | Multiple web/reference surfaces exist; current production audit pending |
| Accessibility/localization | `INCOMPLETE` | Components/tests exist; manual and localization coverage incomplete |
| Performance/offline/reliability | `INCOMPLETE` | Some bounded retries/caching exist; measured baselines pending |
| CI/CD/backups/disaster recovery | `INCOMPLETE` | Extensive scripts/docs exist; consolidated CI and restore evidence pending |

## Phase 0 Definition Of Done

- Real repository, version, commit, dirty state, toolchain, emulator, and
  Supabase project were measured.
- All starting changes were preserved and classified.
- A non-Docker remote metadata/storage snapshot and local migration archive were
  created before runtime changes.
- Migration parity and dry-run passed; database lint completed with warnings.
- Authentication and Support regression foundations were reconfirmed.
- No production feature code was changed before this audit.

