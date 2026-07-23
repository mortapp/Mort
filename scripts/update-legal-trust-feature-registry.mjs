import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { writeRegistryArtifacts } from "./feature-registry-core.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const registryPath = join(root, "docs", "MORT_1891_FEATURE_REGISTRY.json");
const records = JSON.parse(readFileSync(registryPath, "utf8"));

const legalMigration = "supabase/migrations/20260719050000_legal_contract_payment_foundation.sql";
const legalRpcMigration = "supabase/migrations/20260719050300_legal_contract_payment_rpcs.sql";
const trustMigration = "supabase/migrations/20260719050100_first_party_trust_team_foundation.sql";
const trustRpcMigration = "supabase/migrations/20260719050400_first_party_trust_team_rpcs.sql";
const swiftLegal = "swift_mort/MORT/Features/Settings/LegalCenterView.swift";
const swiftContracts = "swift_mort/MORT/Features/Jobs/ContractPaymentViews.swift";
const swiftTrust = "swift_mort/MORT/Features/Trust/FirstPartyTrustViews.swift";
const flutterLegal = "flutter_mort/lib/features/legal/legal_screens.dart";
const flutterContracts = "flutter_mort/lib/features/legal/contract_payment_screens.dart";
const flutterTrust = "flutter_mort/lib/features/legal/trust_foundation_screens.dart";

const evidence = (path, symbol) => ({ path, symbol });
const qa = (name) => evidence(`scripts/${name}.mjs`, name);

const definitions = [
  {
    id: "MORT-F-0441",
    title: "Job-specific contracts",
    slug: "legal-trust-job-specific-contracts",
    behavior: "Creates an immutable, versioned agreement for every accepted job with exact scope, timing, location-release state, hazards, payment obligation, proof, cancellation, and both-party confirmations.",
    status: "shared_implemented",
    tables: "job_contracts, job_contract_versions, job_contract_acceptances, job_payment_obligations",
    rpc: "confirm_job_contract_version",
    checks: [evidence(legalMigration, "create table public.job_contracts"), qa("qa-job-contract-immutability"), evidence(swiftContracts, "struct JobContractReviewView"), evidence(flutterContracts, "class JobContractScreen")],
  },
  {
    id: "MORT-F-0442",
    title: "Material-change consent",
    slug: "legal-trust-material-change-consent",
    behavior: "Requires both parties to affirm the exact proposed version before amount, scope, hours, location, hazards, expenses, or payment timing can replace an active job agreement.",
    status: "shared_implemented",
    tables: "job_contract_change_requests, job_contract_change_acceptances, job_contract_versions",
    rpc: "request_job_contract_change, respond_job_contract_change",
    checks: [evidence(legalRpcMigration, "create or replace function public.request_job_contract_change"), qa("qa-contract-change-consent"), evidence(swiftContracts, "struct JobContractChangeView"), evidence(flutterContracts, "class JobContractScreen")],
  },
  {
    id: "MORT-F-0702",
    title: "Document web-reuse signal",
    slug: "legal-trust-document-web-reuse-signal",
    behavior: "Records a server-signed synthetic-only public-image reuse signal that can require human review but can never approve, reject, or authenticate an identity document.",
    status: "shared_implemented",
    tables: "document_web_reuse_requests, document_web_reuse_results, private.document_web_reuse_provider_configs",
    rpc: "request_synthetic_web_reuse_signal; provider result remains service-only",
    checks: [evidence(trustRpcMigration, "request_synthetic_web_reuse_signal"), qa("qa-document-web-reuse-signal"), evidence(swiftTrust, "struct DocumentCaptureQualityView"), evidence(flutterTrust, "class BrowserSafeCapturePreparationScreen")],
  },
  {
    id: "MORT-F-0703",
    title: "Live-presence challenge",
    slug: "legal-trust-live-presence-challenge",
    behavior: "Issues a random, short-lived, server-bound synthetic challenge and preserves an explicit signal-only result without creating a reusable face template or legal-identity conclusion.",
    status: "shared_implemented",
    tables: "live_presence_challenges, live_presence_results",
    rpc: "start_live_presence_challenge; result recording is service-only",
    checks: [evidence(trustRpcMigration, "start_live_presence_challenge"), qa("qa-live-presence-challenge"), evidence(swiftTrust, "struct LivePresenceChallengeView"), evidence(flutterTrust, "class LivenessExplanationScreen")],
  },
  {
    id: "MORT-F-0704",
    title: "Appearance-consistency review",
    slug: "legal-trust-appearance-consistency-review",
    behavior: "Allows assigned trained adults to record a limited appearance-consistency review for synthetic QA while prohibiting persistent facial recognition, reusable embeddings, and identity-proven claims.",
    status: "implemented_verified_backend",
    tables: "appearance_review_cases, appearance_review_assignments, appearance_review_decisions",
    rpc: "submit_appearance_review_decision",
    checks: [evidence(trustMigration, "create table public.appearance_review_cases"), evidence(trustRpcMigration, "submit_appearance_review_decision"), qa("qa-appearance-review-two-person")],
  },
  {
    id: "MORT-F-0754",
    title: "Live-presence replay protection",
    slug: "legal-trust-live-presence-replay-protection",
    behavior: "Binds each synthetic challenge to one nonce, one short expiration window, and one result so a second submission or stale recording is rejected instead of treated as success.",
    status: "implemented_verified_backend",
    tables: "live_presence_challenges, live_presence_results",
    rpc: "private.record_live_presence_result",
    checks: [evidence(trustRpcMigration, "Challenge replay rejected"), qa("qa-live-presence-replay")],
  },
  {
    id: "MORT-F-0755",
    title: "Safety incident runbooks",
    slug: "legal-trust-safety-incident-runbooks",
    behavior: "Provides bounded escalation, evidence-preservation, emergency-service, privacy, and handoff procedures without directing volunteers to investigate crimes or make legal determinations.",
    status: "foundation_ready",
    tables: "incident_cases and restricted evidence records where an incident is actually reported",
    rpc: "existing incident and evidence-preservation authority only",
    checks: [evidence("docs/runbooks/MORT_MISSING_PERSON_ESCALATION.md", "DRAFT"), evidence("docs/runbooks/MORT_DATA_BREACH_RUNBOOK.md", "DRAFT")],
  },
  {
    id: "MORT-F-0871",
    title: "Payment-obligation record",
    slug: "legal-trust-payment-obligation-record",
    behavior: "Creates a contract-bound due record and keeps payment due, poster-marked-sent, and worker-confirmed-received states distinct without processing or pretending to receive money.",
    status: "shared_implemented",
    tables: "job_payment_obligations, payment_confirmation_records",
    rpc: "record_payment_confirmation",
    checks: [evidence(legalMigration, "create table public.job_payment_obligations"), qa("qa-payment-obligation"), evidence(swiftContracts, "struct PaymentStatusView"), evidence(flutterContracts, "class PaymentStatusScreen")],
  },
  {
    id: "MORT-F-0872",
    title: "Private nonpayment dispute",
    slug: "legal-trust-private-nonpayment-dispute",
    behavior: "Lets a worker report unpaid completed work, gives the poster a response path, preserves both statements, and keeps the allegation private without an automatic guilt finding.",
    status: "shared_implemented",
    tables: "payment_disputes, payment_dispute_evidence, payment_dispute_timeline, payment_dispute_decisions",
    rpc: "report_nonpayment, submit_payment_dispute_statement, review_payment_dispute",
    checks: [evidence(legalRpcMigration, "create or replace function public.report_nonpayment"), qa("qa-nonpayment-dispute-isolation"), evidence(swiftContracts, "struct PaymentDisputeView"), evidence(flutterContracts, "class PaymentDisputeScreen")],
  },
  {
    id: "MORT-F-0873",
    title: "Poster payment restriction",
    slug: "legal-trust-poster-payment-restriction",
    behavior: "Allows a trained assigned reviewer to apply a private, bounded, appealable marketplace restriction only after preliminary evidence review and never publishes a guilt label.",
    status: "implemented_verified_backend",
    tables: "poster_payment_restrictions, payment_dispute_assignments, payment_dispute_decisions",
    rpc: "review_payment_dispute; job/application enforcement triggers",
    checks: [evidence(legalRpcMigration, "block_new_job_publication"), evidence("supabase/migrations/20260719061004_fix_payment_dispute_atomic_validation.sql", "bounded_restriction_expiry_required"), qa("qa-payment-obligation")],
  },
  {
    id: "MORT-F-0874",
    title: "Payment evidence export",
    slug: "legal-trust-payment-evidence-export",
    behavior: "Builds an authorized plain-language dispute package from contract, timeline, status, hashes, and permitted messages while excluding identity evidence and residential information.",
    status: "shared_implemented",
    tables: "payment_evidence_export_events and authorized contract/dispute records",
    rpc: "request_payment_evidence_export",
    checks: [evidence(legalRpcMigration, "request_payment_evidence_export"), qa("qa-payment-evidence-preservation"), evidence(swiftContracts, "struct EvidenceExportView"), evidence(flutterContracts, "class EvidenceExportScreen")],
  },
  {
    id: "MORT-F-1164",
    title: "Live-presence accessibility alternative",
    slug: "legal-trust-live-presence-accessibility-alternative",
    behavior: "Offers a nonpunitive manual alternative when a person cannot perform a requested movement and records the limitation without inferring disability, health, emotion, or identity.",
    status: "shared_implemented",
    tables: "live_presence_challenges, team access and review records",
    rpc: "request_live_presence_accessibility_alternative",
    checks: [evidence(trustRpcMigration, "request_live_presence_accessibility_alternative"), qa("qa-live-presence-accessibility"), evidence(swiftTrust, "struct LivePresenceAccessibilityView"), evidence(flutterTrust, "class LivenessExplanationScreen")],
  },
  {
    id: "MORT-F-1259",
    title: "Teen plain-language terms summary",
    slug: "legal-trust-teen-plain-language-terms-summary",
    behavior: "Presents a teen-readable summary before the full versioned agreement while keeping the complete draft accessible and separating optional Guardian Mode from legal consent requirements.",
    status: "shared_implemented",
    tables: "legal_documents, legal_document_versions, legal_role_requirements",
    rpc: "get_my_legal_requirements, submit_legal_acceptance",
    checks: [evidence("docs/legal/MORT_TEEN_PLAIN_LANGUAGE_TERMS.md", "DRAFT"), evidence(swiftLegal, "struct TeenTermsSummaryView"), evidence(flutterLegal, "class TeenTermsSummaryScreen"), qa("qa-guardian-remains-optional")],
  },
  {
    id: "MORT-F-1552",
    title: "Two-person appearance-mismatch review",
    slug: "legal-trust-two-person-appearance-mismatch-review",
    behavior: "Prevents one reviewer from finalizing a consequential synthetic appearance mismatch and requires a distinct second trained reviewer plus an appeal or alternative path.",
    status: "implemented_verified_backend",
    tables: "appearance_review_cases, appearance_review_assignments, appearance_review_decisions",
    rpc: "admin_assign_appearance_reviewer, submit_appearance_review_decision",
    checks: [evidence(trustMigration, "requires_two_independent_reviewers"), evidence(trustRpcMigration, "second_independent_reviewer_required"), qa("qa-appearance-review-two-person")],
  },
  {
    id: "MORT-F-1553",
    title: "Adult reviewer training gate",
    slug: "legal-trust-adult-reviewer-training-gate",
    behavior: "Requires adult status, all assigned training modules, confidentiality, code of conduct, conflict disclosure, device readiness, approval, and unexpired access before evidence review.",
    status: "implemented_verified_backend",
    tables: "team_training_modules, team_role_training_requirements, team_training_completions, team_member_readiness",
    rpc: "admin_activate_team_role with private.has_ready_team_role checks",
    checks: [evidence(trustMigration, "create table public.team_role_training_requirements"), evidence(trustRpcMigration, "admin_activate_team_role"), qa("qa-team-role-isolation")],
  },
  {
    id: "MORT-F-1554",
    title: "Time-limited team access controls",
    slug: "legal-trust-time-limited-team-access-controls",
    behavior: "Uses individual accounts, approved least-privilege roles, purpose, environment, expiration, immutable access logs, revocation, and readiness checks rather than social-group membership.",
    status: "shared_implemented",
    tables: "team_role_assignments, team_member_readiness, team_access_audit_events",
    rpc: "admin_create_team_role_assignment, admin_activate_team_role, admin_revoke_team_role",
    checks: [evidence(trustMigration, "create table public.team_role_assignments"), qa("qa-team-role-isolation"), evidence(swiftTrust, "struct TeamAccessReviewView")],
  },
  {
    id: "MORT-F-1555",
    title: "Case-bound reviewer assignment",
    slug: "legal-trust-case-bound-reviewer-assignment",
    behavior: "Allows sensitive result access only to a currently trained reviewer explicitly assigned to the case for a recorded purpose and bounded expiration.",
    status: "shared_implemented",
    tables: "appearance_review_assignments, payment_dispute_assignments, reviewer access audit events",
    rpc: "admin_assign_appearance_reviewer and assignment-aware RLS helpers",
    checks: [evidence("supabase/migrations/20260719061607_fix_assigned_reviewer_web_reuse_rls.sql", "can_review_document_web_reuse_result"), qa("qa-reviewer-assignment"), evidence(swiftTrust, "struct ReviewerAssignmentView")],
  },
  {
    id: "MORT-F-1701",
    title: "Official legal-pattern research corpus",
    slug: "legal-trust-official-legal-pattern-research-corpus",
    behavior: "Maintains a deduplicated index of at least 300 distinct current official agreements and safety materials with original summaries, retrieval metadata, limitations, and legal-review flags.",
    status: "foundation_ready",
    tables: "none; research corpus is a version-controlled attorney-review input",
    rpc: "none",
    checks: [evidence("docs/legal-research/MORT_LEGAL_CORPUS_INDEX.json", "official_url"), evidence("scripts/validate-legal-research-corpus.mjs", "duplicate official URLs")],
  },
  {
    id: "MORT-F-1702",
    title: "Affirmative version-bound legal clickwrap",
    slug: "legal-trust-affirmative-version-bound-clickwrap",
    behavior: "Accepts only an unchecked-then-affirmed exact published version and records role, age band, hash, time, platform, app version, language, jurisdiction, UI version, and signature text when required.",
    status: "shared_implemented",
    tables: "legal_acceptances, legal_declines, legal_reacceptance_requirements, legal_acceptance_audit_events",
    rpc: "submit_legal_acceptance; direct client inserts denied",
    checks: [evidence(legalRpcMigration, "submit_legal_acceptance"), qa("qa-legal-clickwrap"), qa("qa-legal-version-forgery"), evidence(swiftLegal, "struct LegalCenterView"), evidence(flutterLegal, "class LegalCenterScreen")],
  },
  {
    id: "MORT-F-1703",
    title: "Legal-information boundary",
    slug: "legal-trust-legal-information-boundary",
    behavior: "Presents conditional official remedy information without selecting claims, predicting a win, preparing individualized pleadings, providing representation, or promising automatic litigation or recovery.",
    status: "shared_implemented",
    tables: "jurisdiction_legal_resources, payment_disputes, payment_evidence_export_events",
    rpc: "authorized evidence export and conditional resource lookup",
    checks: [evidence("docs/MORT_LEGAL_INFORMATION_NOT_ADVICE_POLICY.md", "individualized advice"), qa("qa-no-automatic-legal-advice"), evidence(swiftContracts, "struct EvidenceExportView"), evidence(flutterContracts, "class EvidenceExportScreen")],
  },
  {
    id: "MORT-F-1704",
    title: "Web-reuse processing privacy gate",
    slug: "legal-trust-web-reuse-processing-privacy-gate",
    behavior: "Keeps external image processing disabled until disclosure, consent, counsel, vendor terms, retention, redaction, server configuration, operational readiness, and deletion controls are approved.",
    status: "foundation_ready",
    tables: "first_party_trust_readiness, private.document_web_reuse_provider_configs",
    rpc: "get_first_party_trust_status; real external provider path disabled",
    checks: [evidence("docs/MORT_EXTERNAL_IMAGE_PROCESSING_PRIVACY_REVIEW.md", "disabled"), evidence(trustMigration, "external_web_reuse_enabled boolean not null default false"), qa("qa-web-reuse-not-authenticity")],
  },
  {
    id: "MORT-F-1705",
    title: "Group-chat sensitive-data restrictions",
    slug: "legal-trust-group-chat-sensitive-data-restrictions",
    behavior: "Prohibits raw IDs, face media, private case evidence, production secrets, and sensitive screenshots in group chat, and grants no platform role from group membership.",
    status: "foundation_ready",
    tables: "team_role_assignments and immutable team access audit events; no group-chat membership table",
    rpc: "no group-chat authorization path",
    checks: [evidence("docs/operations/MORT_CONFIDENTIALITY_AND_DATA_ACCESS.md", "group chat"), qa("qa-sensitive-data-not-in-group-chat")],
  },
  {
    id: "MORT-F-1838",
    title: "Sensitive-action device authentication",
    slug: "legal-trust-sensitive-action-device-authentication",
    behavior: "Issues a short-lived one-action authorization after device-owner authentication and consumes it once for private settings, location, evidence, exports, deletion, or Support Circle changes.",
    status: "Swift_source_implemented",
    tables: "none; device authentication result and biometric material never reach Supabase",
    rpc: "none; authorization remains in native application memory",
    checks: [evidence("swift_mort/MORT/Services/BiometricReauthenticationService.swift", "consumeAuthorization"), evidence("swift_mort/MORTTests/DeviceAuthenticationServiceTests.swift", "testSuccessUnlocksOnlyRequestedActionAndIsOneShot"), qa("qa-face-id-not-identity")],
  },
  {
    id: "MORT-F-1840",
    title: "Face ID and Touch ID app lock",
    slug: "legal-trust-face-id-touch-id-app-lock",
    behavior: "Locks signed-in MORT after backgrounding or configured inactivity and handles unavailable, not-enrolled, canceled, failed, lockout, system-canceled, and passcode-fallback outcomes truthfully.",
    status: "Swift_source_implemented",
    tables: "none; only local lock preference and timing state are stored on device",
    rpc: "none; LocalAuthentication is device-only",
    checks: [evidence("swift_mort/MORT/Services/AppLockService.swift", "final class AppLockService"), evidence("swift_mort/MORT/Features/Settings/BiometricSettingsView.swift", "struct AppLockView"), evidence("swift_mort/MORT/Services/DeviceAuthenticationService.swift", "LocalAuthentication"), qa("qa-face-id-not-identity")],
  },
];

if (definitions.length !== 24) {
  throw new Error(`Expected 24 legal/trust definitions, found ${definitions.length}.`);
}

const byId = new Map(records.map((record) => [record.feature_id, record]));
for (const definition of definitions) {
  const record = byId.get(definition.id);
  if (!record) throw new Error(`Missing target feature ${definition.id}.`);
  if (record.implementation_status !== "accepted_roadmap" && record.unique_slug !== definition.slug && definition.id !== "MORT-F-1838") {
    throw new Error(`${definition.id} is no longer an eligible roadmap replacement.`);
  }

  const isNative = record.category.startsWith("Native iOS");
  const isAdmin = record.category.startsWith("Admin");
  const primaryUser = isAdmin ? "admin" : isNative ? "all users" : "all users";
  const secondaryUser = isAdmin ? "support staff" : "system";
  const isSwiftOnly = definition.status === "Swift_source_implemented";
  const isBackendOnly = definition.status === "implemented_verified_backend";

  Object.assign(record, {
    unique_slug: definition.slug,
    title: definition.title,
    subcategory: "legal, payment, and first-party trust foundation",
    primary_user: primaryUser,
    secondary_user: secondaryUser,
    real_world_problem: "Teen-safe local work needs enforceable, privacy-minimized legal, payment, identity-signal, and reviewer boundaries instead of informal promises or client-owned authority.",
    user_story: `As a ${primaryUser}, I want ${definition.title.toLowerCase()} so the exact protection is understandable, reviewable, and enforced without overstated legal or identity claims.`,
    detailed_behavior: definition.behavior,
    reason_users_value_it: "It converts a high-risk informal process into a specific, auditable capability with honest limits and a safe unavailable state.",
    reason_users_return: "Durable version history, clear status, correction paths, and bounded access reduce repeated setup while preserving participant agency.",
    reason_it_is_different: "MORT applies this boundary to ages 13-17 local work, optional Guardian Mode, private evidence, human review, and no authoritative identity claim without an approved provider.",
    safety_impact: "Core free protection; preserves report, block, Safety Ping, prohibited-work, anti-retaliation, emergency, appeal, and account-restriction controls.",
    accessibility_impact: "Requires plain language, semantic labels, responsive text, keyboard or focus support, non-color state, accessible errors, and an equivalent route where movement or biometrics are unavailable.",
    privacy_impact: "Minimizes data and denies public access to exact teen location, legal records, disputes, identity media, face data, provider secrets, and reviewer-only evidence.",
    monetization_relationship: "Required legal, trust, accessibility, and safety foundation; it cannot be paywalled or used to force an upgrade.",
    free_or_paid: "free",
    platform_scope: isSwiftOnly ? "Native SwiftUI source; Mac compile and physical iPhone validation remain" : isBackendOnly ? "Hosted Supabase backend with RLS and synthetic remote QA" : definition.status === "foundation_ready" ? "Documented or disabled foundation awaiting external legal, provider, or operational readiness" : "SwiftUI source + Flutter Web/PWA + hosted Supabase backend",
    swift_path: isSwiftOnly ? definition.checks.find((check) => check.path.startsWith("swift_mort/"))?.path ?? "not_applicable" : definition.checks.find((check) => check.path.startsWith("swift_mort/"))?.path ?? "not_applicable - backend, operations, or Flutter explanation",
    flutter_path: definition.checks.find((check) => check.path.startsWith("flutter_mort/"))?.path ?? "not_applicable - backend, operations, or native iOS capability",
    backend_tables: definition.tables,
    rpc_edge_function: definition.rpc,
    storage_requirement: /document|appearance|live-presence|evidence/i.test(definition.title) ? "Private, randomized, retention-bound storage only if readiness gates later permit collection; current QA contains no real identity or face media" : "No public sensitive-media storage; use existing private evidence storage only when the authorized workflow requires it",
    analytics_requirement: "Privacy-safe state, latency, and failure metrics only; exclude legal text, disputes, raw evidence, identity data, face media, addresses, secrets, and reviewer notes.",
    notification_requirement: "Only privacy-minimized, user-owned status or action reminders with preferences and no sensitive preview content.",
    moderation_requirement: "High-impact decisions require purpose-bound trained human review, immutable audit context, correction, and appeal; automation is never final authority.",
    legal_review_requirement: "Attorney and jurisdiction review required before public launch or reliance on legal terms, minor contracts, payment enforcement, identity processing, liveness, appearance review, or real evidence operations.",
    dependencies: "Hosted Supabase Auth, RLS, checked RPCs, exact-version state, private storage where applicable, accessible error/recovery states, and documented operational readiness.",
    expected_impact: "very_high",
    implementation_priority: 100,
    implementation_status: definition.status,
    verification_evidence: definition.checks.map((check) => `${check.path}#${check.symbol}`).join("; "),
    test_status: definition.status === "foundation_ready" ? "Foundation and disabled-state evidence validated; external legal/provider/operational approval remains." : isSwiftOnly ? "Swift source and repository static evidence passed; no Xcode compile or physical iPhone test was performed." : "Hosted legal/trust QA passed; Flutter analyze/tests/release web build and Swift repository static audit passed where applicable.",
    Mac_required: isSwiftOnly || definition.status === "shared_implemented",
    iPhone_required: isSwiftOnly || definition.status === "shared_implemented",
    manual_dashboard_required: /web-reuse|live-presence|appearance|legal clickwrap/i.test(definition.title),
    reason_deferred: "Attorney, child-safety, labor, privacy, and operational approval remain; real identity collection stays disabled; Mac/Xcode and physical-iPhone validation remain where applicable.",
    implementation_wave: "Wave 0 - legal, payment, and first-party trust foundation",
    evidence_checks: definition.checks,
  });
}

writeRegistryArtifacts(records);
console.log("Updated exactly 24 roadmap capabilities while preserving 1,891 records and category quotas.");
