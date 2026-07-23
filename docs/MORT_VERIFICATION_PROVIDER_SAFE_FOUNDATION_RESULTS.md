# MORT Verification Provider-Safe Foundation Results

Verification date: 2026-07-18

Supabase project: `rakjydmgwwgtdislanbt`

## Honest Status

- Trust/safety architecture: implemented
- Actual production provider verification: not connected
- Real identity collection: disabled
- Sandbox verification: QA-only, document-free simulation
- Guardian Mode: optional
- Public marketplace: closed wherever production verification is mandatory
- Production-ready: no
- Physical iPhone testing: not performed
- TestFlight/App Store validation: not performed

## Backup And Migration

Before the schema change, `node scripts/backup-feature-schema.mjs` created:

`backups/remote-feature-schema-rakjydmgwwgtdislanbt-2026-07-18T05-06-59-417Z.json`

The snapshot is 1,575,031 bytes and contains 109 relations, 180 policies, 125 functions, and 48 migration records. It contains schema/storage metadata, not user rows.

The additional CLI `supabase db dump` attempt was blocked because the CLI required Docker and Docker was not running. Its zero-byte output is not counted as a backup. The catalog snapshot above is the valid pre-change backup.

Migration `20260718051719_identity_verification_provider_safe_foundation.sql` was created through the Supabase CLI. The first transaction dry run found a PostgreSQL function parameter-name incompatibility in `private.can_upload_identity_evidence`; the parameter name was corrected and the obsolete delete helper grant was revoked. The second transaction dry run passed, `supabase db push --linked --dry-run` passed, and the linked push applied. `supabase migration list --linked` now shows local and remote alignment through `20260718051719`.

No project reset, table drop, or real-data deletion was used. Existing legacy/manual verification rows were classified as sandbox and made production-ineligible.

## Hosted State

Final hosted readback:

- mode: `disabled`
- production readiness: false
- provider: not configured
- signed webhook configured flag: false
- workflow, retention, legal, operations, and trained-reviewer flags: false
- sandbox verification rows: 2 existing isolated QA records
- production verification rows: 0
- current production-verified rows: 0
- authenticated identity Storage INSERT policies: 0
- authenticated identity Storage UPDATE policies: 0
- anonymous executable public SECURITY DEFINER functions: 0

The deployed `identity-verification-webhook` is ACTIVE with custom signature authentication (`verify_jwt=false`). A live unsigned POST returned HTTP 503 with `identity_verification_disabled`. No provider secret was created or installed.

## New QA

All seven new suites passed against the hosted project:

| Suite | Result | Verified behavior |
| --- | --- | --- |
| `qa-verification-mode-disabled.mjs` | PASS | starts, Storage upload, direct rows, status forgery, and mode changes denied |
| `qa-verification-mode-sandbox.mjs` | PASS | QA-only, TEST-labeled, document-free, never production-eligible |
| `qa-verification-environment-isolation.mjs` | PASS | sandbox users/jobs hidden from ordinary feeds; Guardian Mode optional |
| `qa-verification-storage-lockdown.mjs` | PASS | upload, copy, delete, list, guardian, and ordinary-admin access denied |
| `qa-verification-client-forgery.mjs` | PASS | environment, provider, status, level, and approval forgery denied |
| `qa-verification-webhook-replay.mjs` | PASS | HMAC/timestamp accepted in contract QA; unsigned/sandbox/replay rejected |
| `qa-verification-production-fail-closed.mjs` | PASS | missing readiness/provider blocks production and provider decisions |

No real identity document or real personal identifier was used by these suites. Each database-writing suite removed only users created by its own run and restored mode to disabled.

## Regression QA

Passed:

- mutual verification
- teen school-ID isolation with intake disabled
- adult ID/selfie/address isolation with intake disabled
- address privacy
- verification forgery
- optional Guardian Mode
- Safety Circle permissions
- incident case isolation
- evidence preservation
- complete multi-user isolation, 30/30 checks including private Storage

Failed: none in the requested new or regression suites.

Blocked: `qa-old-project-rls.mjs`. Neither `MORT_REBUILD_TEST_PASSWORD` nor `MORT_QA_PASSWORD` exists in the authorized environment. The retired-password suite was not run, was not reported as passed, and no credential was invented.

Not applicable: real provider verification, real ID capture, native iPhone camera/photo behavior, native push, native purchases, native ads, TestFlight, and App Store review.

Statically inspected: Swift source/project, because Xcode and iOS compilation are unavailable on Windows.

## Client And Build Validation

- `flutter pub get`: PASS; 29 newer packages are outside current dependency constraints (informational).
- `dart format lib test`: PASS; 93 files checked and 2 formatted.
- `flutter analyze`: PASS; no issues.
- First `flutter test`: FAIL because the new disabled-provider test invoked a synchronous failure before the matcher could observe it.
- Corrected `expect(provider.createSession, throwsA(...))` test: PASS; 63 tests passed.
- Flutter web release build with web-preview mode and IAP/ads disabled: PASS; `build/web` generated and Wasm dry run succeeded.
- Swift project generation: PASS; 86 app sources, 9 unit-test sources, and 1 UI-test source included.
- Swift static audit: PASS; plist/privacy/entitlements parse, source inclusion, package references, and secret/generated-file rules passed.
- Swift compilation/Xcode tests: NOT RUN on Windows.
- Windows check: PASS; TypeScript, Expo lint, 48-route Expo web export, and Expo Doctor 20/20.
- Source secret scan: PASS. The final rerun initially timed out while traversing excluded generated/dependency trees; the script was corrected to prune those directories before recursion, and the same scan then passed.

## Defects Found And Fixed

1. PostgreSQL rejected a `CREATE OR REPLACE FUNCTION` parameter rename for `private.can_upload_identity_evidence`. The retained parameter name was restored; transaction and CLI dry runs then passed.
2. The disabled Flutter provider throws synchronously, but its new test invoked it before the matcher was installed. The assertion now passes the method callback to `throwsA`; all 63 tests pass.
3. Environment-isolation QA expected `is_test` in an RPC projection that does not return it. The suite now verifies the persisted server-controlled profile row.
4. Hardened RLS returns permission errors for some empty-list attempts. Storage and teen/adult isolation assertions now accept either an authorization error or an empty result while still failing if any row/object is exposed.
5. Legacy QA setup needed an approved status only for isolated test-marketplace RPC compatibility. Production badges now additionally require a non-test job and a current production-environment result, so test status cannot leak as production trust.
6. The final secret scan recursed into excluded generated trees before filtering and timed out. Directory pruning moved into traversal; the rerun passed in under a second.
7. Windows PowerShell did not support `Invoke-WebRequest -SkipHttpErrorCheck`. The read-only Edge endpoint verification used `curl.exe` instead and confirmed HTTP 503 with `identity_verification_disabled`.

## Delivery Audit

`scripts/package-verification-provider-safe.ps1` created the requested master source, Flutter web-build, and Swift source archives. The identity-focused sensitive-file scan passed for the staged source, staged Swift project, Flutter web output, and all three archive contents. It checked currently available secret values without printing them, allowed only known app icons/launch assets as media, and rejected environment files, credentials, database dumps, backups, build junk, old archives, and identity-document-like media.

Artifacts:

- `mort-verification-provider-safe-foundation-clean.zip`
- `mort-web-verification-disabled-safe.zip`
- `mort-swiftui-verification-provider-safe-clean.zip`

Final byte counts, file counts, and SHA-256 hashes are reported from the archives themselves after packaging.

## Security Advisors

Current hosted security advisor: 83 WARN, 3 INFO, 0 ERROR.

- 82 WARN: authenticated callable SECURITY DEFINER functions, reconciled one-by-one in `docs/MORT_84_SECURITY_WARNING_RECONCILIATION.md`.
- 1 WARN: leaked-password protection disabled. This is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**, not an unresolved code bug.
- 3 INFO: RLS enabled with no policy on deny-by-default private location/arrival state tables.

The former anonymous trust-badge warning was fixed by revoking `anon` execution. No public SECURITY DEFINER function is now anonymously executable.

When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.

## Remaining Requirements

Before real users or public marketplace launch:

1. Approve and contract a production identity/age provider.
2. Complete youth, privacy/biometric, employment, retention/deletion, and jurisdiction legal review.
3. Approve provider workflow, server secrets, monitoring, reconciliation, and outage procedures.
4. Train and authorize reviewers; implement access recertification and deletion operations.
5. Compile in Xcode and test camera/photo permissions, accessibility, recovery, and provider flow on physical iPhones.
6. Complete TestFlight, App Store privacy disclosures, consent/deletion copy, safety review, and incident-response exercises.
