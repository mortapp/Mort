import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { writeRegistryArtifacts } from "./feature-registry-core.mjs";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const registryPath = join(root, "docs", "MORT_1891_FEATURE_REGISTRY.json");
const records = JSON.parse(readFileSync(registryPath, "utf8"));

const migration = "supabase/migrations/20260718150502_multi_signal_account_trust_foundation.sql";
const qa = "scripts/account-trust-qa-suites.mjs";
const swiftTrust = "swift_mort/MORT/Features/Trust/AccountTrustViews.swift";
const flutterTrust = "flutter_mort/lib/features/trust/account_trust_screens.dart";

const backend = (symbol, qaSymbol) => ({
  status: "implemented_verified_backend",
  platform: "Supabase hosted backend with server-owned policy and RLS",
  swiftPath: "not_applicable - backend authority",
  flutterPath: "not_applicable - backend authority",
  evidence: [
    { path: migration, symbol },
    { path: qa, symbol: qaSymbol },
  ],
  test: "Hosted account-trust QA passed against rakjydmgwwgtdislanbt; sandbox and production remained isolated.",
});

const shared = (symbol, qaSymbol, swiftSymbol, flutterSymbol) => ({
  status: "shared_implemented",
  platform: "SwiftUI source + Flutter Web/PWA + Supabase hosted backend",
  swiftPath: swiftTrust,
  flutterPath: flutterTrust,
  evidence: [
    { path: migration, symbol },
    { path: qa, symbol: qaSymbol },
    { path: swiftTrust, symbol: swiftSymbol },
    { path: flutterTrust, symbol: flutterSymbol },
  ],
  test: "Hosted account-trust QA passed; Flutter analyze passed, all 65 tests passed, and the release web preview built; Swift repository static audit passed. Mac compilation and physical iPhone testing were not performed.",
});

const foundation = (evidencePath, symbol, reason) => ({
  status: "foundation_ready",
  platform: "Disabled architecture with a server-controlled activation gate",
  swiftPath: evidencePath.startsWith("swift_mort/") ? evidencePath : "not_applicable - future native integration",
  flutterPath: evidencePath.startsWith("flutter_mort/") ? evidencePath : "not_applicable - future client integration",
  evidence: [],
  verificationEvidence: `${evidencePath} contains the disabled preparation architecture for ${symbol}.`,
  test: "Disabled-state architecture reviewed; activation and real-device/provider testing were not performed.",
  reason,
});

const swift = (path, symbol, testSymbol) => ({
  status: "Swift_source_implemented",
  platform: "Native SwiftUI/iOS source; no Mac or physical-device claim",
  swiftPath: path,
  flutterPath: "not_applicable - native iOS account-security capability",
  evidence: [
    { path, symbol },
    { path: "swift_mort/MORTTests/DeviceAuthenticationServiceTests.swift", symbol: testSymbol },
  ],
  test: "Swift source and unit-test cases passed repository static audit. Xcode compilation and physical iPhone testing were not performed.",
});

const definitions = [
  { id: "MORT-F-0676", title: "Multi-level trust profile", slug: "multi-signal-trust-multi-level-profile", behavior: "Returns levels 0 through 5 with precise sections and indicators instead of one vague verified state.", impl: shared("get_my_account_trust_profile", "runLevels", "AccountTrustView", "AccountTrustScreen") },
  { id: "MORT-F-0677", title: "Passkey readiness", slug: "multi-signal-trust-passkey-readiness", behavior: "Detects browser WebAuthn capability, reads server availability, and keeps enrollment disabled until relying-party and recovery review is complete.", impl: shared("passkeys_enabled_by_server", "runLevels", "PasskeySettingsView", "detectPasskeyCapability") },
  { id: "MORT-F-0678", title: "Active session management", slug: "multi-signal-trust-active-session-management", behavior: "Lists current account sessions, identifies the current session, supports unfamiliar-session reporting, and offers a safe sign-out recovery path.", impl: shared("suspicious_session_monitoring_enabled", "runBiometric", "SessionManagementView", "DeviceSecuritySettingsScreen") },
  { id: "MORT-F-0679", title: "School-domain affiliation", slug: "multi-signal-trust-school-domain-affiliation", behavior: "Checks the already-confirmed teen account email against an environment-bound approved school domain and grants affiliation only.", impl: shared("request_school_email_affiliation", "runSchoolAffiliation", "SchoolEmailVerificationView", "SchoolEmailVerificationScreen") },
  { id: "MORT-F-0680", title: "School partner code", slug: "multi-signal-trust-school-partner-code", behavior: "Redeems an expiring hash-only limited-use school invitation atomically without revealing participant lists or granting identity.", impl: shared("redeem_partner_invite_code", "runPartnerCode", "PartnerCodeVerificationView", "PartnerCodeVerificationScreen") },
  { id: "MORT-F-0686", title: "Youth program affiliation", slug: "multi-signal-trust-youth-program-affiliation", behavior: "Supports approved nonprofit, vocational, community, workforce, and youth-program memberships with expiry and revocation.", impl: backend("youth_program", "runPartnerCode") },
  { id: "MORT-F-0687", title: "Partner organization verification", slug: "multi-signal-trust-partner-organization-verification", behavior: "Restricts organization creation and approval to audited affiliation reviewers and prevents staff from browsing unrelated teens.", impl: backend("admin_review_partner_organization", "runPartnerCode") },
  { id: "MORT-F-0688", title: "Business registry matching", slug: "multi-signal-trust-business-registry-matching", behavior: "Records a manual match against an allowlisted official registry with confidence, snapshot time, mismatch reason, appeal, and expiry.", impl: shared("request_business_registry_match", "runBusinessRegistry", "BusinessRegistryMatchView", "BusinessRegistryMatchScreen") },
  { id: "MORT-F-0689", title: "Authorized representative claim", slug: "multi-signal-trust-authorized-representative-claim", behavior: "Records an attested relationship separately from the registry record and leaves authority unverified until an approved provider exists.", impl: shared("request_business_representative_claim", "runBusinessRegistry", "requestBusinessRepresentativeClaim", "requestBusinessRepresentativeClaim") },
  { id: "MORT-F-0690", title: "Digital government ID provider", slug: "multi-signal-trust-digital-government-id-provider", behavior: "Defines a service-only signed-credential session and result contract while all production provider flags remain disabled.", impl: foundation("supabase/migrations/20260718150502_multi_signal_account_trust_foundation.sql", "create_digital_credential_session", "Requires platform approval, a cryptographic verifier, issuer policy, legal/privacy review, and real-device QA.") },
  { id: "MORT-F-0691", title: "Android digital credential preparation", slug: "multi-signal-trust-android-digital-credential-preparation", behavior: "Provides a truthful unsupported state and a server validation protocol for a future Android Credential Manager implementation.", impl: shared("android_digital_credentials_enabled", "runDigitalReplay", "DigitalIDAvailabilityView", "DigitalIDAvailabilityScreen") },
  { id: "MORT-F-0692", title: "Credential replay protection", slug: "multi-signal-trust-credential-replay-protection", behavior: "Binds one credential event to one unconsumed server session and rejects reused event IDs, nonces, and completed sessions.", impl: backend("digital_credential_replay_detected", "runDigitalReplay") },
  { id: "MORT-F-0693", title: "Credential issuer validation", slug: "multi-signal-trust-credential-issuer-validation", behavior: "Requires a trusted server to match the expected issuer and credential type before a digital credential can create a signal.", impl: backend("v_issuer_valid", "runDigitalReplay") },
  { id: "MORT-F-0694", title: "Trust badge explanations", slug: "multi-signal-trust-badge-explanations", behavior: "Every server-derived indicator states what was checked, what was not checked, timing, expiry, access effect, and safety limitation.", impl: shared("what_was_not_checked", "runBadgeForgery", "TrustExplanationSheet", "TrustExplanationSheet") },
  { id: "MORT-F-0695", title: "Structured trust eligibility", slug: "multi-signal-trust-structured-eligibility", behavior: "Returns allowed state, required and current levels, missing requirements, reason codes, retry timing, and support route for each sensitive action.", impl: shared("get_marketplace_trust_eligibility", "runMarketplaceGating", "MarketplaceTrustEligibility", "MarketplaceTrustEligibility") },
  { id: "MORT-F-0696", title: "Trust-policy versioning", slug: "multi-signal-trust-policy-versioning", behavior: "Keeps immutable auditable policy versions for production closure, minimum levels, providers, screening, pilots, regions, and allowlists.", impl: backend("trust_policy_versions", "runMarketplaceGating") },
  { id: "MORT-F-0697", title: "Trust-signal audit", slug: "multi-signal-trust-signal-audit", behavior: "Records source, environment, reviewer, timestamps, expiry, revocation, public wording, and minimized metadata for each signal.", impl: backend("trust_signal_events", "runBadgeForgery") },
  { id: "MORT-F-0698", title: "Verification expiration", slug: "multi-signal-trust-verification-expiration", behavior: "Excludes expired provider and digital-credential results from current trust and returns an explicit expired state instead of stale approval.", impl: backend("expires_at is null or verification.expires_at > now()", "runDigitalReplay") },
  { id: "MORT-F-0699", title: "Affiliation expiration", slug: "multi-signal-trust-affiliation-expiration", behavior: "Expires school, program, and partner membership signals and prevents expired records from satisfying current affiliation policy.", impl: backend("membership.expires_at", "runPartnerCode") },
  { id: "MORT-F-0700", title: "Account trust appeal", slug: "multi-signal-trust-account-trust-appeal", behavior: "Lets an account submit a bounded appeal to a restricted human-review queue without automatically changing level or access.", impl: shared("submit_account_trust_appeal", "runProfilePrivacy", "VerificationAppealView", "VerificationAppealScreen") },
  { id: "MORT-F-0701", title: "No numerical safety score", slug: "multi-signal-trust-no-numerical-safety-score", behavior: "Shows precise checks, risk reasons, and restrictions without presenting one unexplained number as a prediction that someone is safe.", impl: shared("not_a_criminal_accusation", "runProfilePrivacy", "TrustLevelCard", "TrustLevelCard") },
  { id: "MORT-F-0751", title: "Suspicious login alerts", slug: "multi-signal-trust-suspicious-login-alerts", behavior: "Defines session monitoring, unfamiliar-session reporting, and notification-ready event boundaries without claiming an APNs alert was delivered.", impl: foundation("supabase/migrations/20260718150502_multi_signal_account_trust_foundation.sql", "suspicious_session_monitoring_enabled", "Requires finalized detection thresholds, APNs delivery configuration, abuse tuning, and physical-device notification QA.") },
  { id: "MORT-F-0752", title: "Device and account risk signals", slug: "multi-signal-trust-device-account-risk-signals", behavior: "Evaluates neutral account, session, verification, affiliation, abuse, restriction, and test-environment signals without criminal labels.", impl: backend("evaluate_account_risk", "runMarketplaceGating") },
  { id: "MORT-F-0753", title: "Transparent risk reasons", slug: "multi-signal-trust-transparent-risk-reasons", behavior: "Returns minimized reason codes, recommended action, and human-review requirement while reserving confidential incident evidence.", impl: backend("risk_reasons", "runProfilePrivacy") },
  { id: "MORT-F-1697", title: "Public data allowlist", slug: "multi-signal-trust-public-data-allowlist", behavior: "Allows only reviewed official-source hosts by category and jurisdiction, with automation disabled unless separately approved.", impl: backend("official_source_allowlist", "runPublicData") },
  { id: "MORT-F-1698", title: "Data broker rejection", slug: "multi-signal-trust-data-broker-rejection", behavior: "Rejects people-search, address-history, phone-owner, social-inference, roster, juvenile-record, and dossier sources by default.", impl: backend("People-search and data-broker sources are rejected", "runPublicData") },
  { id: "MORT-F-1699", title: "Account-security education", slug: "multi-signal-trust-account-security-education", behavior: "Explains that passwords, passkeys, contact checks, sessions, and device authentication protect account access but do not prove identity.", impl: shared("email_or_phone_is_legal_identity", "runLevels", "DeviceSecuritySettingsView", "DeviceSecuritySettingsScreen") },
  { id: "MORT-F-1700", title: "Biometric limitations disclosure", slug: "multi-signal-trust-biometric-limitations-disclosure", behavior: "States that Face ID and Touch ID stay on the device, expose no biometric material to MORT, and never establish legal identity.", impl: shared("device_biometrics_are_local_account_security_only", "runBiometric", "Device biometrics protect your account", "A web page cannot read Face ID or Touch ID data") },
  { id: "MORT-F-1837", title: "Device biometric reauthentication", slug: "multi-signal-trust-device-biometric-reauthentication", behavior: "Uses LocalAuthentication with truthful unavailable, denied, failed, canceled, lockout, fallback, and success outcomes.", impl: swift("swift_mort/MORT/Services/DeviceAuthenticationService.swift", "DeviceAuthenticationService", "testUnavailableBiometrics") },
  { id: "MORT-F-1838", title: "Sensitive action biometric gate", slug: "multi-signal-trust-sensitive-action-biometric-gate", behavior: "Issues a short-lived one-action authorization after device-owner authentication and keeps the action blocked after failure.", impl: swift("swift_mort/MORT/Services/BiometricReauthenticationService.swift", "consumeAuthorization", "testSuccessUnlocksOnlyRequestedActionAndIsOneShot") },
  { id: "MORT-F-1839", title: "Apple Wallet identity preparation", slug: "multi-signal-trust-apple-wallet-identity-preparation", behavior: "Defines minimal-attribute wallet request and server-validation result types behind a disabled provider with no local approval path.", impl: { status: "Swift_source_implemented", platform: "Native SwiftUI architecture; Apple entitlement and verification are disabled", swiftPath: "swift_mort/MORT/Services/AppleWalletIdentityProvider.swift", flutterPath: "not_applicable - Apple native provider", evidence: [{ path: "swift_mort/MORT/Services/AppleWalletIdentityProvider.swift", symbol: "AppleWalletIdentityProvider" }, { path: swiftTrust, symbol: "DigitalIDAvailabilityView" }], test: "Swift source passed repository static audit. Apple entitlement, Xcode compile, server verifier, and physical-iPhone testing were not performed." } },
];

if (definitions.length !== 31) throw new Error(`Expected 31 trust definitions, found ${definitions.length}.`);

const byId = new Map(records.map((record) => [record.feature_id, record]));
for (const definition of definitions) {
  const record = byId.get(definition.id);
  if (!record) throw new Error(`Missing target feature ${definition.id}.`);
  if (record.implementation_status !== "accepted_roadmap" && record.unique_slug !== definition.slug) {
    throw new Error(`${definition.id} is no longer an eligible roadmap replacement.`);
  }

  const implementation = definition.impl;
  const roles = record.category.startsWith("Native iOS")
    ? ["all users", "system"]
    : record.category.startsWith("Admin")
      ? ["admin", "support staff"]
      : ["all users", "system"];
  Object.assign(record, {
    unique_slug: definition.slug,
    title: definition.title,
    subcategory: "multi-signal account trust",
    primary_user: roles[0],
    secondary_user: roles[1],
    real_world_problem: "Teen-safe local work needs precise evidence boundaries because account security, affiliation, public records, identity, screening, and safety are not interchangeable.",
    user_story: `As a ${roles[0]}, I want ${definition.title.toLowerCase()} so I can understand and use the exact trust check without a misleading verification claim.`,
    detailed_behavior: definition.behavior,
    reason_users_value_it: "It replaces vague verification with a specific, contestable check and a truthful unavailable state when authority is missing.",
    reason_users_return: "A durable account trust history and clear recovery path reduce repeated setup while preserving safety boundaries.",
    reason_it_is_different: "MORT separates contact ownership, account security, affiliation, business records, digital credentials, provider identity, and adult screening for ages 13-17 local work.",
    safety_impact: "Must fail closed, preserve account restrictions and report/block/Safety Ping, and never imply that verification guarantees safety.",
    accessibility_impact: "Requires semantic labels, responsive text, keyboard/focus support, non-color state, plain explanations, and accessible errors.",
    privacy_impact: "Minimize data; do not expose contact values, school name by default, residence, raw reports, biometric material, passkey secrets, or identity evidence.",
    monetization_relationship: "Core trust and safety capability; no safety, basic applying, Guardian Mode, report/block, or Safety Ping paywall.",
    free_or_paid: "free",
    platform_scope: implementation.platform,
    swift_path: implementation.swiftPath,
    flutter_path: implementation.flutterPath,
    backend_tables: "account_trust_profiles, trust_signal_events, trust_policy_versions, account_security_preferences, partner and registry tables as applicable",
    rpc_edge_function: "get_my_account_trust_profile, get_marketplace_trust_eligibility, and the least-privilege signal-specific RPC where applicable",
    storage_requirement: "No raw identity documents, biometric material, passkey private material, or residential dossier storage",
    analytics_requirement: "Privacy-safe state and failure metrics only; exclude raw evidence, contact values, school identity, residence, and sensitive risk details.",
    notification_requirement: definition.title === "Suspicious login alerts" ? "Future security alert with explicit preferences and safe payload minimization." : "None unless a time-sensitive user-owned state changes.",
    moderation_requirement: "Role-limited human review with reason, actor, timestamp, case ID, audit event, and appeal where a decision affects access.",
    legal_review_requirement: "Required before public marketplace activation, identity proofing, screening, real affiliation operations, or official credential use.",
    dependencies: "Authenticated Supabase account, server-owned policy, RLS, environment isolation, precise copy, loading/error/recovery states, and documented provider availability.",
    expected_impact: "high",
    implementation_priority: 100,
    implementation_status: implementation.status,
    verification_evidence: implementation.verificationEvidence ?? implementation.evidence.map((check) => `${check.path}#${check.symbol}`).join("; "),
    test_status: implementation.test,
    Mac_required: record.category.startsWith("Native iOS") || implementation.status === "Swift_source_implemented",
    iPhone_required: record.category.startsWith("Native iOS") || definition.title.includes("Apple Wallet") || definition.title.includes("biometric"),
    manual_dashboard_required: ["Passkey readiness", "Suspicious login alerts", "Digital government ID provider", "Apple Wallet identity preparation", "Android digital credential preparation"].includes(definition.title),
    reason_deferred: implementation.reason ?? "Mac/Xcode and physical-device validation remain where applicable; production identity, screening, and public launch require external provider and legal approval.",
    implementation_wave: "Wave 0 - multi-signal trust foundation",
    evidence_checks: implementation.evidence,
  });
}

writeRegistryArtifacts(records);
console.log("Updated exactly 31 roadmap records while preserving 1,891 records and category quotas.");
