# MORT Mutual Trust Pass - Exact Changed Files

This manifest covers the mutual identity and real-world safety implementation pass completed on 2026-07-17. Generated build/cache/archive files are excluded.

## Root Expo reference

- `package.json`
- `pnpm-lock.yaml`

The root changes are Expo SDK 57 patch-alignment updates found by `expo-doctor`; no Expo feature was removed.

## Supabase migrations

- `supabase/migrations/20260717161125_mutual_identity_verification.sql`
- `supabase/migrations/20260717161132_mutual_trust_real_world_safety.sql`
- `supabase/migrations/20260717193747_trust_safety_evidence_manifests.sql`
- `supabase/migrations/20260718024657_allow_rls_policy_predicates.sql`
- `supabase/migrations/20260718024844_fix_identity_evidence_storage_policy.sql`
- `supabase/migrations/20260718030325_protect_registered_incident_evidence_objects.sql`
- `supabase/migrations/20260718040458_fix_mutual_safety_job_word_boundaries.sql`

## SwiftUI source

- `swift_mort/MORT.xcodeproj/project.pbxproj`
- `swift_mort/MORT/App/Router.swift`
- `swift_mort/MORT/Features/Admin/AdminViews.swift`
- `swift_mort/MORT/Features/Applications/ApplicationDetailView.swift`
- `swift_mort/MORT/Features/Home/RoleShells.swift`
- `swift_mort/MORT/Features/Onboarding/OnboardingView.swift`
- `swift_mort/MORT/Features/Safety/SafetyViews.swift`
- `swift_mort/MORT/Features/Safety/TrustSafetyViews.swift`
- `swift_mort/MORT/Features/Settings/SettingsView.swift`
- `swift_mort/MORT/Features/Verification/VerificationView.swift`
- `swift_mort/MORT/Models/TrustSafety.swift`
- `swift_mort/MORT/Repositories/AdminRepository.swift`
- `swift_mort/MORT/Repositories/SafetyRepository.swift`
- `swift_mort/MORT/Repositories/StorageRepository.swift`
- `swift_mort/MORT/Repositories/VerificationRepository.swift`

## Flutter Web/PWA source

- `flutter_mort/pubspec.yaml`
- `flutter_mort/pubspec.lock`
- `flutter_mort/lib/core/routing/app_router.dart`
- `flutter_mort/lib/data/models/trust_safety.dart`
- `flutter_mort/lib/data/repositories/admin_repository.dart`
- `flutter_mort/lib/data/repositories/providers.dart`
- `flutter_mort/lib/data/repositories/safety_repository.dart`
- `flutter_mort/lib/data/repositories/trust_safety_repository.dart`
- `flutter_mort/lib/features/jobs/application_screens.dart`
- `flutter_mort/lib/features/mort_screens.dart`
- `flutter_mort/lib/features/safety/trust_safety_screens.dart`

## QA and tooling

- `scripts/feature-qa-helpers.mjs`
- `scripts/mutual-trust-qa-suites.mjs`
- `scripts/transaction-dry-run.mjs`
- `scripts/cleanup-stale-feature-qa-users.mjs`
- `scripts/qa-mutual-verification.mjs`
- `scripts/qa-teen-school-id-isolation.mjs`
- `scripts/qa-teen-verification-alternatives.mjs`
- `scripts/qa-adult-id-isolation.mjs`
- `scripts/qa-address-privacy.mjs`
- `scripts/qa-verification-forgery.mjs`
- `scripts/qa-guardian-remains-optional.mjs`
- `scripts/qa-safety-circle-permissions.mjs`
- `scripts/qa-location-release-stages.mjs`
- `scripts/qa-arrival-handshake.mjs`
- `scripts/qa-person-mismatch-report.mjs`
- `scripts/qa-mutual-reporting.mjs`
- `scripts/qa-harassment-controls.mjs`
- `scripts/qa-sexual-safety-controls.mjs`
- `scripts/qa-incident-case-isolation.mjs`
- `scripts/qa-evidence-preservation.mjs`
- `scripts/qa-verification-expiration.mjs`
- `scripts/qa-account-sharing.mjs`
- `scripts/qa-safety-cancellation.mjs`
- `scripts/qa-job-applications.mjs`
- `scripts/qa-feature-expansion.mjs`
- `scripts/qa-complete-multi-user-isolation.mjs`
- `scripts/qa-reviews.mjs`
- `scripts/qa-business-verification.mjs`
- `scripts/qa-old-project-smoke.mjs`
- `scripts/feature-registry-core.mjs`
- `scripts/package-mutual-trust-safety.ps1`

## Architecture, policy, and results documentation

- `docs/MORT_MUTUAL_IDENTITY_VERIFICATION_ARCHITECTURE.md`
- `docs/MORT_VERIFICATION_EVIDENCE_MATRIX.md`
- `docs/MORT_VERIFICATION_PRIVACY_MODEL.md`
- `docs/MORT_VERIFICATION_RETENTION_POLICY_DRAFT.md`
- `docs/MORT_VERIFICATION_APPEALS_PROCESS.md`
- `docs/MORT_BACKGROUND_SCREENING_LEGAL_CHECKLIST.md`
- `docs/MORT_SCREENING_CONSENT_FLOW.md`
- `docs/MORT_ADVERSE_ACTION_PROCESS_DRAFT.md`
- `docs/MORT_SCREENING_APPEAL_AND_DISPUTE_FLOW.md`
- `docs/MORT_CHILD_SEXUAL_SAFETY_POLICY_DRAFT.md`
- `docs/MORT_GROOMING_SIGNAL_GUIDE.md`
- `docs/MORT_SEXUAL_SAFETY_ESCALATION_RUNBOOK.md`
- `docs/MORT_LAW_ENFORCEMENT_REQUEST_POLICY_DRAFT.md`
- `docs/MORT_EMERGENCY_DISCLOSURE_PROCESS_DRAFT.md`
- `docs/MORT_EVIDENCE_PRESERVATION_RUNBOOK.md`
- `docs/MORT_INCIDENT_CHAIN_OF_CUSTODY.md`
- `docs/MORT_MUTUAL_TRUST_RLS_MATRIX.md`
- `docs/MORT_MUTUAL_TRUST_SAFETY_IMPLEMENTATION_RESULTS.md`
- `docs/MORT_MUTUAL_TRUST_CHANGED_FILES.md`
- `docs/SUPABASE_FINAL_ADVISOR_AUDIT.md`

## Generated 1,891-feature artifacts

- `docs/MORT_1891_FEATURE_REGISTRY.csv`
- `docs/MORT_1891_FEATURE_REGISTRY.json`
- `docs/MORT_1891_FEATURE_REGISTRY.md`
- `docs/MORT_FEATURE_DEDUPLICATION_REPORT.md`
- `docs/MORT_FEATURE_DEPENDENCY_GRAPH.md`
- `docs/MORT_FEATURE_IMPLEMENTATION_AUDIT.md`
- `docs/MORT_FEATURE_IMPLEMENTATION_WAVES.md`
- `docs/MORT_FEATURE_PRIORITY_SCORECARD.md`
- `docs/MORT_FEATURE_VALIDATION_REPORT.md`
- `docs/MORT_REJECTED_FEATURES.md`

