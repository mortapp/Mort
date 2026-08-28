# MORT Legal/Liveness/Payment/Trust Validation Report

Date: 2026-07-19

## Passed checks

- `node scripts/validate-legal-research-corpus.mjs`: 300 records, 300 unique official URLs, 113 organizations.
- Legal draft audit: 25 files and 25 exact draft banners.
- `node scripts/validate-1891-feature-registry.mjs`: exactly 1,891 accepted capabilities, exact quotas, no accepted duplicates, 99 evidence-backed implementation claims.
- `node scripts/audit-feature-implementation.mjs`: 99 claims retained, 0 downgraded.
- Legal/trust remote QA: 21/21.
- Closed-pilot remote QA: 17/17.
- Verification safe-mode remote QA: 7/7.
- Mutual-trust remote QA: 19/19.
- Multi-user isolation: 30/30 assertions.
- `node scripts/audit-remote-storage.mjs`: passed; all seven buckets private and identity buckets empty.
- `node scripts/audit-supabase-advisors.mjs`: 0 security/performance ERROR and 0 performance WARN; new slice has 0 unindexed foreign keys.
- Migration transaction dry-run and Supabase CLI dry-run for `20260719070500`: passed.
- Local/remote migration alignment through `20260719070500`: passed.
- `flutter pub get`: passed.
- `dart format lib test`: 110 files, 0 changes on final build pass.
- `flutter analyze`: no issues.
- `flutter test`: 73 tests passed.
- Flutter release web build with web preview mode and IAP/ads disabled: passed; `build/web` created.
- Swift Xcode project generation: 105 app sources, 11 unit-test sources, 1 UI-test source.
- Swift repository static audit: passed.
- `pnpm install`: lockfile current, dependencies already installed.
- `pnpm check`: passed.
- `pnpm lint`: passed.
- `pnpm build`: passed; Expo exported 48 static web routes.
- `npx expo-doctor`: 20/20 checks passed.
- Guarded stale-QA cleanup: 3 strict-pattern `qa-feature-* @mort.test` users removed; immediate rerun found 0. No non-QA account matched the cleanup expression.

## Executed validation command ledger

Secrets were supplied only from environment variables and are omitted below. These are the executable project/build/QA commands used for the final pass; file-inspection commands are not included.

```powershell
node scripts/backup-feature-schema.mjs
.\scripts\build-web-preview.ps1 -SkipTests
node scripts/update-legal-trust-feature-registry.mjs
node scripts/validate-legal-research-corpus.mjs
node scripts/validate-1891-feature-registry.mjs
node scripts/audit-feature-implementation.mjs
node scripts/qa-payment-obligation.mjs
node scripts/qa-payment-evidence-preservation.mjs
node --input-type=module -e "import { legalTrustSuiteNames, runLegalTrustSuite } from './scripts/legal-trust-qa-suites.mjs'; for (const name of legalTrustSuiteNames) await runLegalTrustSuite(name); console.log('FINAL_POST_MIGRATION_LEGAL_TRUST_QA passed=' + legalTrustSuiteNames.length + ' failed=0');"
node --input-type=module -e "import { runMissionPilotQaSuite } from './scripts/mission-pilot-qa-suites.mjs'; const names=['closed-pilot-access','partner-attestation','partner-code-security','housing-status-privacy','no-permanent-address','guardian-stays-optional','support-circle-permissions','discreet-mode-privacy','document-review-claims','two-person-review','document-vault-access','document-retention','founder-document-access-restriction','pilot-job-restrictions','vulnerable-teen-data-isolation','resource-directory-privacy','future-independence-safety']; for (const name of names) await runMissionPilotQaSuite(name); console.log('MISSION_PILOT_QA_SUMMARY passed=' + names.length + ' failed=0');"
node --input-type=module -e "import { runVerificationModeSuite } from './scripts/verification-mode-qa-suites.mjs'; const names=['qa-verification-mode-disabled','qa-verification-mode-sandbox','qa-verification-environment-isolation','qa-verification-storage-lockdown','qa-verification-client-forgery','qa-verification-webhook-replay','qa-verification-production-fail-closed']; for (const name of names) await runVerificationModeSuite(name); console.log('VERIFICATION_SAFE_MODE_QA_SUMMARY passed=' + names.length + ' failed=0');"
node --input-type=module -e "import { runMutualTrustSuite } from './scripts/mutual-trust-qa-suites.mjs'; const names=['qa-mutual-verification','qa-teen-school-id-isolation','qa-teen-verification-alternatives','qa-adult-id-isolation','qa-address-privacy','qa-verification-forgery','qa-guardian-remains-optional','qa-safety-circle-permissions','qa-location-release-stages','qa-arrival-handshake','qa-person-mismatch-report','qa-mutual-reporting','qa-harassment-controls','qa-sexual-safety-controls','qa-incident-case-isolation','qa-evidence-preservation','qa-verification-expiration','qa-account-sharing','qa-safety-cancellation']; for (const name of names) await runMutualTrustSuite(name); console.log('MUTUAL_TRUST_QA_SUMMARY passed=' + names.length + ' failed=0');"
node scripts/qa-complete-multi-user-isolation.mjs
node scripts/audit-remote-storage.mjs
$env:SUPABASE_ACCESS_TOKEN = [Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN','User'); node scripts/audit-supabase-advisors.mjs
$env:SUPABASE_DB_PASSWORD = [Environment]::GetEnvironmentVariable('SUPABASE_DB_PASSWORD','User'); node scripts/transaction-dry-run.mjs supabase/migrations/20260719070500_poster_payment_restriction_fk_indexes.sql
$env:SUPABASE_ACCESS_TOKEN = [Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN','User'); $env:SUPABASE_DB_PASSWORD = [Environment]::GetEnvironmentVariable('SUPABASE_DB_PASSWORD','User'); npx supabase db push --linked --dry-run --password $env:SUPABASE_DB_PASSWORD
$env:SUPABASE_ACCESS_TOKEN = [Environment]::GetEnvironmentVariable('SUPABASE_ACCESS_TOKEN','User'); $env:SUPABASE_DB_PASSWORD = [Environment]::GetEnvironmentVariable('SUPABASE_DB_PASSWORD','User'); npx supabase db push --linked --password $env:SUPABASE_DB_PASSWORD
node .\scripts\generate-xcode-project.mjs
.\scripts\static-audit.ps1
pnpm install
.\scripts\windows-check.ps1
.\scripts\secret-scan.ps1
.\scripts\sensitive-file-scan.ps1 -RootPath .\docs
.\scripts\package-legal-liveness-payment-trust.ps1
$env:MORT_QA_CLEANUP='REMOVE_STALE_FEATURE_QA_ONLY'; node scripts/cleanup-stale-feature-qa-users.mjs; Remove-Item Env:MORT_QA_CLEANUP
```

The first unguarded cleanup invocation failed closed with the required `MORT_QA_CLEANUP` instruction. It was rerun with the exact guard shown above, removed 3 stale QA-only accounts, and a second guarded run returned 0.

## Toolchain boundary

`xcodebuild` and the Apple iOS SDK are unavailable on Windows. Swift source was not compiled and no simulator or physical iPhone run occurred. Native LocalAuthentication, notifications, camera/photo handling, RevenueCat, AdMob/ATT/UMP, accessibility, background interruption, and TestFlight behavior still require a Mac, Xcode, Apple signing, and real-device testing.

## Release boundary

No attorney approval, child-safety approval, labor review, biometric privacy approval, insurance approval, trained real-evidence reviewer operation, TestFlight validation, or App Store review is claimed. This is not production-ready.
