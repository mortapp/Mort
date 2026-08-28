# MORT Verification Provider-Safe Changed Files

This pass changed or generated the following source-controlled project files. Build output, temporary CLI state, backups, and final zip artifacts are excluded from this list.

## Supabase

- `supabase/config.toml`
- `supabase/migrations/20260718051719_identity_verification_provider_safe_foundation.sql`
- `supabase/functions/identity-verification-webhook/contract.mjs`
- `supabase/functions/identity-verification-webhook/index.ts`

## Flutter

- `flutter_mort/lib/data/models/job.dart`
- `flutter_mort/lib/data/models/trust_safety.dart`
- `flutter_mort/lib/data/repositories/trust_safety_repository.dart`
- `flutter_mort/lib/features/safety/trust_safety_screens.dart`
- `flutter_mort/lib/services/identity_verification_provider.dart`
- `flutter_mort/test/identity_verification_provider_test.dart`

## Swift

- `swift_mort/MORT.xcodeproj/project.pbxproj`
- `swift_mort/MORT/Features/Verification/VerificationView.swift`
- `swift_mort/MORT/Models/Job.swift`
- `swift_mort/MORT/Models/TrustSafety.swift`
- `swift_mort/MORT/Repositories/VerificationRepository.swift`
- `swift_mort/MORT/Services/IdentityVerificationProvider.swift`

## QA And Delivery Scripts

- `scripts/feature-qa-helpers.mjs`
- `scripts/generate-security-warning-reconciliation.mjs`
- `scripts/mutual-trust-qa-suites.mjs`
- `scripts/verification-mode-qa-suites.mjs`
- `scripts/qa-verification-mode-disabled.mjs`
- `scripts/qa-verification-mode-sandbox.mjs`
- `scripts/qa-verification-environment-isolation.mjs`
- `scripts/qa-verification-storage-lockdown.mjs`
- `scripts/qa-verification-client-forgery.mjs`
- `scripts/qa-verification-webhook-replay.mjs`
- `scripts/qa-verification-production-fail-closed.mjs`
- `scripts/secret-scan.ps1`
- `scripts/sensitive-file-scan.ps1`
- `scripts/package-verification-provider-safe.ps1`

## Documentation

- `docs/IDENTITY_VERIFICATION_MODE_RUNBOOK.md`
- `docs/IDENTITY_VERIFICATION_PROVIDER_ARCHITECTURE.md`
- `docs/IDENTITY_VERIFICATION_STORAGE_LOCKDOWN.md`
- `docs/IDENTITY_VERIFICATION_WEBHOOK_CONTRACT.md`
- `docs/MORT_84_SECURITY_WARNING_RECONCILIATION.md`
- `docs/MORT_MUTUAL_IDENTITY_VERIFICATION_ARCHITECTURE.md`
- `docs/MORT_MUTUAL_TRUST_RLS_MATRIX.md`
- `docs/MORT_VERIFICATION_EVIDENCE_MATRIX.md`
- `docs/MORT_1891_FEATURE_REGISTRY.md`
- `docs/MORT_VERIFICATION_PROVIDER_SAFE_FOUNDATION_RESULTS.md`
- `docs/MORT_VERIFICATION_PROVIDER_SAFE_CHANGED_FILES.md`

## Generated Outside Delivery Artifacts

- `backups/remote-feature-schema-rakjydmgwwgtdislanbt-2026-07-18T05-06-59-417Z.json` - valid pre-change catalog backup, excluded from zips.
- `backups/remote-schema-rakjydmgwwgtdislanbt-20260718-010736.sql` - zero-byte failed Docker-dependent dump attempt, excluded from zips and not treated as a backup.
- `supabase/.temp/cli-latest` - Supabase CLI state, excluded from zips.
- `flutter_mort/build/web` and root `dist` - generated builds, excluded from source archives; Flutter web output is packaged separately.
