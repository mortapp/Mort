# MORT Legal/Liveness/Payment/Trust Changed Files

This inventory covers the source, schema, QA, and documentation files created or modified for this mission. Generated build folders, clean delivery ZIPs, local environment files, and remote schema backups are intentionally excluded.

## Supabase migrations

- `supabase/migrations/20260719050000_legal_contract_payment_foundation.sql`
- `supabase/migrations/20260719050100_first_party_trust_team_foundation.sql`
- `supabase/migrations/20260719050200_legal_contract_trust_rls.sql`
- `supabase/migrations/20260719050300_legal_contract_payment_rpcs.sql`
- `supabase/migrations/20260719050400_first_party_trust_team_rpcs.sql`
- `supabase/migrations/20260719050500_legal_draft_catalog.sql`
- `supabase/migrations/20260719050600_legal_trust_foreign_key_indexes.sql`
- `supabase/migrations/20260719061004_fix_payment_dispute_atomic_validation.sql`
- `supabase/migrations/20260719061607_fix_assigned_reviewer_web_reuse_rls.sql`
- `supabase/migrations/20260719070500_poster_payment_restriction_fk_indexes.sql`

## Build, validation, QA, and packaging scripts

- `scripts/build-legal-research-corpus.mjs`
- `scripts/validate-legal-research-corpus.mjs`
- `scripts/build-legal-operations-docs.mjs`
- `scripts/legal-trust-qa-suites.mjs`
- `scripts/feature-qa-helpers.mjs`
- `scripts/update-legal-trust-feature-registry.mjs`
- `scripts/audit-remote-storage.mjs`
- `scripts/audit-supabase-advisors.mjs`
- `scripts/package-legal-liveness-payment-trust.ps1`
- `scripts/qa-legal-clickwrap.mjs`
- `scripts/qa-legal-version-forgery.mjs`
- `scripts/qa-legal-reacceptance.mjs`
- `scripts/qa-job-contract-immutability.mjs`
- `scripts/qa-contract-change-consent.mjs`
- `scripts/qa-payment-obligation.mjs`
- `scripts/qa-nonpayment-dispute-isolation.mjs`
- `scripts/qa-payment-evidence-preservation.mjs`
- `scripts/qa-no-automatic-legal-advice.mjs`
- `scripts/qa-document-web-reuse-signal.mjs`
- `scripts/qa-web-reuse-not-authenticity.mjs`
- `scripts/qa-live-presence-challenge.mjs`
- `scripts/qa-live-presence-replay.mjs`
- `scripts/qa-live-presence-accessibility.mjs`
- `scripts/qa-appearance-review-two-person.mjs`
- `scripts/qa-face-id-not-identity.mjs`
- `scripts/qa-team-role-isolation.mjs`
- `scripts/qa-reviewer-assignment.mjs`
- `scripts/qa-founder-no-automatic-id-access.mjs`
- `scripts/qa-sensitive-data-not-in-group-chat.mjs`
- `scripts/qa-guardian-remains-optional.mjs`

## Legal research artifacts

- `docs/legal-research/MORT_LEGAL_CORPUS_INDEX.csv`
- `docs/legal-research/MORT_LEGAL_CORPUS_INDEX.json`
- `docs/legal-research/MORT_300_DOCUMENT_RESEARCH_REPORT.md`
- `docs/legal-research/MORT_MARKETPLACE_CLAUSE_MATRIX.md`
- `docs/legal-research/MORT_MINOR_USER_CLAUSE_MATRIX.md`
- `docs/legal-research/MORT_PAYMENT_DISPUTE_CLAUSE_MATRIX.md`
- `docs/legal-research/MORT_SAFETY_LIABILITY_CLAUSE_MATRIX.md`
- `docs/legal-research/MORT_TERMS_RESEARCH_LIMITATIONS.md`

## Attorney-review legal drafts

- `docs/legal/MORT_TERMS_OF_SERVICE_DRAFT.md`
- `docs/legal/MORT_TERMS_OF_USE_DRAFT.md`
- `docs/legal/MORT_PRIVACY_POLICY_DRAFT.md`
- `docs/legal/MORT_TEEN_PLAIN_LANGUAGE_TERMS.md`
- `docs/legal/MORT_ADULT_POSTER_AGREEMENT_DRAFT.md`
- `docs/legal/MORT_BUSINESS_ACCOUNT_AGREEMENT_DRAFT.md`
- `docs/legal/MORT_PARTNER_ORGANIZATION_AGREEMENT_DRAFT.md`
- `docs/legal/MORT_JOB_SERVICE_AGREEMENT_DRAFT.md`
- `docs/legal/MORT_PAYMENT_OBLIGATION_AGREEMENT_DRAFT.md`
- `docs/legal/MORT_MARKETPLACE_RISK_DISCLOSURE.md`
- `docs/legal/MORT_ACCEPTABLE_USE_POLICY.md`
- `docs/legal/MORT_COMMUNITY_AND_SAFETY_RULES.md`
- `docs/legal/MORT_PROHIBITED_WORK_POLICY.md`
- `docs/legal/MORT_LOCATION_AND_MEETING_POLICY.md`
- `docs/legal/MORT_IDENTITY_REVIEW_DISCLOSURE.md`
- `docs/legal/MORT_LIVENESS_CHECK_DISCLOSURE.md`
- `docs/legal/MORT_FACE_ID_DISCLOSURE.md`
- `docs/legal/MORT_PAYMENT_DISPUTE_POLICY.md`
- `docs/legal/MORT_MODERATION_AND_APPEALS_POLICY.md`
- `docs/legal/MORT_INCIDENT_AND_EVIDENCE_POLICY.md`
- `docs/legal/MORT_DATA_RETENTION_AND_DELETION_DRAFT.md`
- `docs/legal/MORT_LIMITATION_OF_LIABILITY_DRAFT.md`
- `docs/legal/MORT_INSURANCE_DISCLOSURE_DRAFT.md`
- `docs/legal/MORT_CLOSED_PILOT_RULES.md`
- `docs/legal/MORT_VOLUNTEER_AND_TESTER_POLICY_DRAFT.md`

## Operations, limitations, and runbooks

- `docs/MORT_NONPAYMENT_OPERATIONAL_PROCESS.md`
- `docs/MORT_LEGAL_INFORMATION_NOT_ADVICE_POLICY.md`
- `docs/MORT_PAYMENT_EVIDENCE_EXPORT_STANDARD.md`
- `docs/MORT_WEB_REUSE_SIGNAL_LIMITATIONS.md`
- `docs/MORT_EXTERNAL_IMAGE_PROCESSING_PRIVACY_REVIEW.md`
- `docs/operations/MORT_TEAM_ROLE_MATRIX.md`
- `docs/operations/MORT_VOLUNTEER_EXPECTATIONS_DRAFT.md`
- `docs/operations/MORT_PAID_WORK_COMPLIANCE_HOLD.md`
- `docs/operations/MORT_CONFIDENTIALITY_AND_DATA_ACCESS.md`
- `docs/operations/MORT_SECURITY_ADVISOR_SCOPE.md`
- `docs/operations/MORT_REVIEWER_ACCESS_READINESS.md`
- `docs/operations/MORT_REVIEWER_TRAINING_CURRICULUM.md`
- `docs/runbooks/MORT_MISSING_PERSON_ESCALATION.md`
- `docs/runbooks/MORT_ABDUCTION_CONCERN_RUNBOOK.md`
- `docs/runbooks/MORT_SEXUAL_SAFETY_RUNBOOK.md`
- `docs/runbooks/MORT_NONPAYMENT_RUNBOOK.md`
- `docs/runbooks/MORT_LAW_ENFORCEMENT_REQUEST_RUNBOOK.md`
- `docs/runbooks/MORT_DATA_BREACH_RUNBOOK.md`

## Results and registry artifacts

- `docs/MORT_LEGAL_LIVENESS_PAYMENT_TRUST_IMPLEMENTATION_RESULTS.md`
- `docs/MORT_LEGAL_LIVENESS_PAYMENT_TRUST_RLS_STORAGE_ADVISOR_REPORT.md`
- `docs/MORT_LEGAL_LIVENESS_PAYMENT_TRUST_VALIDATION_REPORT.md`
- `docs/MORT_LEGAL_LIVENESS_PAYMENT_TRUST_RELEASE_GATES.md`
- `docs/MORT_LEGAL_LIVENESS_PAYMENT_TRUST_CHANGED_FILES.md`
- `docs/WEB_BUILD_CONFIG_STATUS.md`
- `docs/MORT_1891_FEATURE_REGISTRY.json`
- `docs/MORT_1891_FEATURE_REGISTRY.csv`
- `docs/MORT_1891_FEATURE_REGISTRY.md`
- `docs/MORT_FEATURE_DEDUPLICATION_REPORT.md`
- `docs/MORT_REJECTED_FEATURES.md`
- `docs/MORT_FEATURE_PRIORITY_SCORECARD.md`
- `docs/MORT_FEATURE_IMPLEMENTATION_WAVES.md`
- `docs/MORT_FEATURE_DEPENDENCY_GRAPH.md`
- `docs/MORT_FEATURE_VALIDATION_REPORT.md`
- `docs/MORT_FEATURE_IMPLEMENTATION_AUDIT.md`

## SwiftUI source and project

- `swift_mort/MORT/Models/LegalContractPayment.swift`
- `swift_mort/MORT/Repositories/LegalAcceptanceRepository.swift`
- `swift_mort/MORT/Services/AppLockService.swift`
- `swift_mort/MORT/Services/DeviceAuthenticationService.swift`
- `swift_mort/MORT/App/DependencyContainer.swift`
- `swift_mort/MORT/App/RootView.swift`
- `swift_mort/MORT/App/Router.swift`
- `swift_mort/MORT/Features/Home/RoleShells.swift`
- `swift_mort/MORT/Features/Settings/SettingsView.swift`
- `swift_mort/MORT/Features/Settings/BiometricSettingsView.swift`
- `swift_mort/MORT/Features/Settings/LegalCenterView.swift`
- `swift_mort/MORT/Features/Applications/ApplicationDetailView.swift`
- `swift_mort/MORT/Features/Jobs/ContractPaymentViews.swift`
- `swift_mort/MORT/Features/Trust/FirstPartyTrustViews.swift`
- `swift_mort/MORT/Info.plist`
- `swift_mort/MORT.xcodeproj/project.pbxproj`
- `swift_mort/scripts/static-audit.ps1`

## Flutter Web/PWA source

- `flutter_mort/lib/data/repositories/legal_contract_repository.dart`
- `flutter_mort/lib/data/repositories/providers.dart`
- `flutter_mort/lib/core/routing/app_router.dart`
- `flutter_mort/lib/features/legal/legal_screens.dart`
- `flutter_mort/lib/features/legal/contract_payment_screens.dart`
- `flutter_mort/lib/features/legal/trust_foundation_screens.dart`
- `flutter_mort/lib/features/mort_screens.dart`
- `flutter_mort/test/legal_trust_foundation_test.dart`
