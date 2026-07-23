import { randomBytes, randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

async function trustProfile(user) {
  const result = await user.client.rpc("get_my_account_trust_profile");
  assertQa(!result.error && result.data?.ok === true, `trust profile failed: ${result.error?.message}`);
  return result.data;
}

async function eligibility(user, action = "browse", jobId = null) {
  const result = await user.client.rpc("get_marketplace_trust_eligibility", {
    p_action: action,
    p_job_id: jobId,
  });
  assertQa(!result.error, `eligibility RPC failed: ${result.error?.message}`);
  return result.data;
}

async function grantAdminRole(userId, role) {
  await withDatabase(async (database) => {
    await database.query(
      `
        insert into public.admin_role_assignments (user_id, role, grant_reason)
        values ($1, $2::public.admin_safety_role, 'Isolated account-trust QA role assignment.')
        on conflict (user_id, role) where revoked_at is null do nothing
      `,
      [userId, role],
    );
  });
}

async function runLevels(scope) {
  await withQaUsers(
    scope,
    [{ key: "adult", role: "adult", identityVerified: false, isTest: false }],
    async ({ adult }) => {
      const basic = await trustProfile(adult);
      assertQa(basic.current_level === 0, "confirmed email did not remain basic level 0");
      assertQa(basic.identity_status === "not_identity_verified", "email was represented as identity verification");

      await withDatabase((database) =>
        database.query(
          "update auth.users set phone = $2, phone_confirmed_at = now() where id = $1",
          [adult.id, `+1317${Date.now().toString().slice(-7)}`],
        ),
      );
      const contact = await trustProfile(adult);
      assertQa(contact.contact_status.phone_verified === true, "confirmed QA phone was not detected");
      assertQa(contact.identity_status === "not_identity_verified", "phone ownership was represented as identity verification");

      const forged = await adult.client
        .from("account_trust_profiles")
        .update({ current_level: 5 })
        .eq("user_id", adult.id)
        .select("user_id");
      assertQa(forged.error || forged.data.length === 0, "ordinary user increased the server trust level");

      await withDatabase((database) =>
        database.query(
          `
            insert into public.trust_signal_events (
              user_id, signal_type, category, status, environment, source_kind,
              public_label, what_was_checked, what_was_not_checked,
              checked_at, expires_at, metadata
            ) values (
              $1, 'passkey_enabled', 'account_security', 'verified', 'production', 'auth',
              'Passkey enabled',
              'A synthetic QA server signal represents a registered passkey.',
              'The passkey does not verify legal identity, age, address, or safety.',
              now(), now() + interval '1 hour', '{"synthetic_qa":true}'::jsonb
            )
          `,
          [adult.id],
        ),
      );
      const passkey = await trustProfile(adult);
      assertQa(passkey.identity_status === "not_identity_verified", "passkey signal was represented as identity verification");
      assertQa(passkey.marketplace_eligibility.allowed === false, "account-security signal opened production marketplace access");
      qaLog(scope, "email, phone, and passkey signals remain account/contact security and cannot be self-forged into identity");
    },
  );
}

async function runBiometric(scope) {
  await withQaUsers(
    scope,
    [{ key: "adult", role: "adult", identityVerified: false, isTest: false }],
    async ({ adult }) => {
      const configured = await adult.client.rpc("update_account_security_preferences", {
        p_device_reauthentication_enabled: true,
        p_lock_after_minutes: 15,
      });
      assertQa(
        !configured.error && configured.data?.identity_verified === false && configured.data?.biometric_material_stored === false,
        "device authentication preference implied identity or stored biometric material",
      );
      const before = await trustProfile(adult);

      const failed = await serviceClient.rpc("record_server_reauthentication_event", {
        p_user_id: adult.id,
        p_action_type: "reveal_private_address",
        p_authentication_method: "device_owner_authentication",
        p_result: "failed",
        p_session_reference: "qa-session-failed",
        p_valid_until: null,
      });
      assertQa(!failed.error && failed.data?.identity_effect === false, "failed biometric event affected identity");
      const succeeded = await serviceClient.rpc("record_server_reauthentication_event", {
        p_user_id: adult.id,
        p_action_type: "reveal_private_address",
        p_authentication_method: "device_owner_authentication",
        p_result: "succeeded",
        p_session_reference: "qa-session-success",
        p_valid_until: new Date(Date.now() + 60_000).toISOString(),
      });
      assertQa(!succeeded.error && succeeded.data?.identity_effect === false, "successful biometric event affected identity");
      const after = await trustProfile(adult);
      assertQa(after.identity_status === "not_identity_verified", "device authentication granted identity verification");
      assertQa(after.marketplace_eligibility.allowed === false, "device authentication opened production marketplace access");
      assertQa(before.current_level === after.current_level, "reauthentication outcomes changed the trust level");
      qaLog(scope, "device-owner authentication events store no biometric material and never act as identity evidence");
    },
  );
}

async function runMarketplaceGating(scope) {
  await withQaUsers(
    scope,
    [
      { key: "ordinary", role: "adult", identityVerified: false, isTest: false },
      { key: "qaAdult", role: "adult", isTest: true },
    ],
    async ({ ordinary, qaAdult }) => {
      const blocked = await eligibility(ordinary, "publish_job");
      assertQa(blocked.allowed === false, "ordinary production account passed closed marketplace policy");
      assertQa(blocked.reason_codes.includes("production_marketplace_closed"), "closed policy did not return a structured reason");
      assertQa(Array.isArray(blocked.missing_requirements) && blocked.support_route, "eligibility response was not structured");

      const sandbox = await eligibility(qaAdult, "publish_job");
      assertQa(sandbox.allowed === true && sandbox.test_mode === true, "isolated QA sandbox account was not eligible for QA actions");
      assertQa(sandbox.reason_codes.includes("sandbox_account_only"), "QA eligibility omitted sandbox-only disclosure");

      await withDatabase(async (database) => {
        await database.query("select set_config('mort.internal_update', 'true', false)");
        await database.query("update public.profiles set account_status = 'suspended' where id = $1", [qaAdult.id]);
      });
      const restricted = await eligibility(qaAdult, "publish_job");
      assertQa(restricted.allowed === false && restricted.reason_codes.includes("account_restricted"), "account restriction did not override QA trust");
      qaLog(scope, "server policy returns structured reasons, keeps production closed, permits isolated QA, and lets restrictions override trust");
    },
  );
}

async function runSchoolAffiliation(scope) {
  await withQaUsers(
    scope,
    [
      { key: "qaTeen", role: "teen", identityVerified: false, isTest: true },
      { key: "ordinaryTeen", role: "teen", identityVerified: false, isTest: false },
    ],
    async ({ qaTeen, ordinaryTeen }) => {
      const verified = await qaTeen.client.rpc("request_school_email_affiliation", {
        p_school_email: qaTeen.email,
      });
      assertQa(!verified.error && verified.data?.affiliation_verified === true, "approved QA school domain did not grant affiliation");
      assertQa(
        verified.data?.identity_verified === false && verified.data?.government_id_verified === false && verified.data?.grants_marketplace_access === false,
        "school email was promoted beyond affiliation",
      );
      const profile = await trustProfile(qaTeen);
      assertQa(profile.identity_status !== "provider_identity_verified", "school affiliation appeared as provider identity");
      assertQa(profile.school_name_public_by_default === false, "school name became public by default");

      const pending = await ordinaryTeen.client.rpc("request_school_email_affiliation", {
        p_school_email: ordinaryTeen.email,
      });
      assertQa(!pending.error && pending.data?.status === "pending_domain_review", "unapproved production domain did not fail closed to review");
      assertQa(pending.data?.affiliation_verified === false, "unapproved production domain granted affiliation");
      qaLog(scope, "confirmed approved-domain email grants private affiliation only; unknown production domains remain pending");
    },
  );
}

async function runPartnerCode(scope) {
  await withQaUsers(
    scope,
    [
      { key: "teen", role: "teen", identityVerified: false, isTest: true },
      { key: "admin", role: "admin", identityVerified: false, isTest: true },
    ],
    async ({ teen, admin }) => {
      await grantAdminRole(admin.id, "affiliation_reviewer");
      let organizationId;
      try {
        const created = await admin.client.rpc("admin_create_partner_organization", {
          p_organization_type: "youth_program",
          p_legal_name: "MORT Synthetic QA Youth Program",
          p_display_name: "Synthetic QA Program",
          p_environment: "sandbox",
          p_official_directory_url: "https://mort.test/qa-program",
          p_access_reason: "Create an isolated synthetic organization for account-trust QA.",
          p_case_id: `QA-${Date.now()}`,
        });
        assertQa(!created.error && created.data?.ok === true, `partner organization create failed: ${created.error?.message}`);
        organizationId = created.data.organization_id;
        const reviewed = await admin.client.rpc("admin_review_partner_organization", {
          p_organization_id: organizationId,
          p_approve: true,
          p_access_reason: "Approve only the isolated synthetic organization for partner-code QA.",
          p_case_id: `QA-${Date.now()}`,
        });
        assertQa(!reviewed.error && reviewed.data?.status === "verified", "synthetic partner organization was not approved");
        const generated = await admin.client.rpc("admin_create_partner_invite_code", {
          p_organization_id: organizationId,
          p_program_id: null,
          p_expires_at: new Date(Date.now() + 3_600_000).toISOString(),
          p_max_uses: 2,
          p_access_reason: "Generate a limited-use synthetic invitation for partner-code QA.",
          p_case_id: `QA-${Date.now()}`,
        });
        assertQa(!generated.error && generated.data?.stored_as_hash_only === true, "partner code was not generated hash-only");
        const rawCode = generated.data.invite_code;
        const first = await teen.client.rpc("redeem_partner_invite_code", { p_code: rawCode });
        const second = await teen.client.rpc("redeem_partner_invite_code", { p_code: rawCode });
        assertQa(!first.error && first.data?.affiliation_verified === true && first.data?.identity_verified === false, "partner code exceeded affiliation scope");
        assertQa(!second.error && second.data?.status === "already_redeemed", "partner code redemption was not idempotent");
        const code = await serviceClient.from("partner_invite_codes").select("use_count,code_hash").eq("id", generated.data.code_id).single();
        assertQa(code.data?.use_count === 1 && code.data?.code_hash, "idempotent redemption consumed the code more than once");
        qaLog(scope, "hash-only limited-use partner code grants private program affiliation once and never identity or production access");
      } finally {
        if (organizationId) {
          await serviceClient.from("partner_organizations").delete().eq("id", organizationId);
        }
      }
    },
  );
}

async function runBusinessRegistry(scope) {
  await withQaUsers(
    scope,
    [
      { key: "adult", role: "adult", identityVerified: false, isTest: false },
      { key: "admin", role: "admin", identityVerified: false, isTest: false },
    ],
    async ({ adult, admin }) => {
      await grantAdminRole(admin.id, "business_reviewer");
      const requested = await adult.client.rpc("request_business_registry_match", {
        p_jurisdiction: "US-IN",
        p_legal_business_name: "MORT Synthetic QA LLC",
        p_registration_number: `QA-${Date.now()}`,
        p_entity_type: "limited_liability_company",
        p_official_source_url: "https://bsd.sos.in.gov/PublicBusinessSearch/Index",
      });
      assertQa(!requested.error && requested.data?.manual_review_required === true, "official registry request did not require manual review");
      assertQa(requested.data?.representative_identity_verified === false, "registry request claimed representative identity");
      const reviewed = await admin.client.rpc("admin_review_business_registry_match", {
        p_check_id: requested.data.check_id,
        p_decision: "matched",
        p_match_confidence: 0.95,
        p_registration_status: "active",
        p_mismatch_explanation: null,
        p_access_reason: "Review the synthetic official-source registry record for isolated QA.",
        p_case_id: `QA-${Date.now()}`,
      });
      assertQa(!reviewed.error && reviewed.data?.business_record_matched === true, "registry reviewer did not record the synthetic match");
      assertQa(reviewed.data?.representative_identity_verified === false && reviewed.data?.grants_marketplace_access === false, "registry match proved authority or access");
      const claim = await adult.client.rpc("request_business_representative_claim", {
        p_business_registry_check_id: requested.data.check_id,
        p_relationship_type: "owner",
        p_attested: true,
      });
      assertQa(!claim.error && claim.data?.provider_required === true && claim.data?.representative_identity_verified === false, "representative claim bypassed the provider gap");
      const direct = await adult.client.from("business_registry_checks").update({ status: "matched" }).eq("id", requested.data.check_id).select("id");
      assertQa(direct.error || direct.data.length === 0, "adult self-approved a business registry match");
      qaLog(scope, "official registry match is reviewer-controlled and remains separate from representative identity");
    },
  );
}

async function runPublicData(scope) {
  await withQaUsers(
    scope,
    [{ key: "adult", role: "adult", identityVerified: false, isTest: false }],
    async ({ adult }) => {
      const rejected = await adult.client.rpc("request_business_registry_match", {
        p_jurisdiction: "US-IN",
        p_legal_business_name: "MORT Synthetic QA LLC",
        p_registration_number: `QA-${Date.now()}`,
        p_entity_type: "llc",
        p_official_source_url: "https://people-search.example/person",
      });
      assertQa(!rejected.error && rejected.data?.code === "official_source_not_allowed", "people-search source was accepted");
      const visibleSources = await adult.client.from("official_source_allowlist").select("hostname");
      assertQa(
        visibleSources.error || visibleSources.data.length === 0,
        "ordinary user browsed the restricted source allowlist",
      );
      const policy = await withDatabase((database) =>
        database.query(
          "select bool_and(not automated_matching_allowed) as no_automation, bool_and(hostname in ('inbiz.in.gov','bsd.sos.in.gov')) as official_only from public.official_source_allowlist where source_category='business_registry'",
        ),
      );
      assertQa(policy.rows[0].no_automation && policy.rows[0].official_only, "allowlist enabled scraping or a non-official registry source");
      qaLog(scope, "people-search sources are rejected and the Indiana allowlist is manual-review-only");
    },
  );
}

async function runGuardianOptional(scope) {
  await withQaUsers(
    scope,
    [
      { key: "teen", role: "teen", identityVerified: false, isTest: true },
      { key: "guardian", role: "guardian", identityVerified: false, isTest: true },
    ],
    async ({ teen, guardian }) => {
      const before = await trustProfile(teen);
      const policy = await teen.client.rpc("get_guardian_policy_for_user");
      assertQa(!policy.error && policy.data?.guardian_link_required === false, "Guardian Mode became mandatory");
      await withDatabase((database) =>
        database.query(
          "insert into public.guardian_connections (teen_id,guardian_id,status) values ($1,$2,'active')",
          [teen.id, guardian.id],
        ),
      );
      const after = await trustProfile(teen);
      assertQa(before.current_level === after.current_level, "guardian linking changed the independent trust level");
      assertQa(after.guardian_mode_optional === true, "trust profile stopped labeling Guardian Mode optional");
      const browse = await eligibility(teen, "browse");
      assertQa(browse.reason_codes.includes("guardian_not_required"), "general eligibility made a guardian mandatory");
      qaLog(scope, "linking or skipping Guardian Mode does not raise or lower the independent trust level");
    },
  );
}

async function runBadgeForgery(scope) {
  await withQaUsers(
    scope,
    [
      { key: "adult", role: "adult", identityVerified: false, isTest: false },
      { key: "admin", role: "admin", identityVerified: false, isTest: false },
    ],
    async ({ adult, admin }) => {
      const signal = await adult.client.from("trust_signal_events").insert({
        user_id: adult.id,
        signal_type: "provider_identity_verified",
        category: "provider_identity",
        status: "verified",
        environment: "production",
        source_kind: "identity_provider",
        public_label: "Provider identity verified",
        what_was_checked: "Forged client claim that should never be accepted.",
        what_was_not_checked: "Nothing was actually checked by a trusted server.",
        checked_at: new Date().toISOString(),
      });
      assertQa(signal.error, "ordinary user inserted a trust badge");
      const trust = await adult.client.from("account_trust_profiles").update({ current_level: 5 }).eq("user_id", adult.id).select("user_id");
      assertQa(trust.error || trust.data.length === 0, "ordinary user altered server-derived trust");
      const adminAttempt = await admin.client.rpc("admin_review_school_domain", {
        p_domain: "forged.example",
        p_organization_name: "Forged",
        p_organization_type: "school",
        p_environment: "production",
        p_official_source_url: "https://forged.example",
        p_approve: true,
        p_access_reason: "Attempt without an assigned least-privilege reviewer role.",
        p_case_id: `QA-${Date.now()}`,
      });
      assertQa(adminAttempt.data?.code === "affiliation_reviewer_required", "ordinary admin granted affiliation");
      const profile = await trustProfile(adult);
      assertQa(profile.identity_status === "not_identity_verified", "forgery changed the trust profile");
      qaLog(scope, "trust badges, levels, and reviewer decisions remain server-derived and least-privileged");
    },
  );
}

async function runProfilePrivacy(scope) {
  await withQaUsers(
    scope,
    [
      { key: "teen", role: "teen", identityVerified: false, isTest: true },
      { key: "viewer", role: "adult", identityVerified: false, isTest: true },
    ],
    async ({ teen, viewer }) => {
      const affiliation = await teen.client.rpc("request_school_email_affiliation", { p_school_email: teen.email });
      assertQa(!affiliation.error && affiliation.data?.signal_id, "QA affiliation setup failed");
      const visibility = await teen.client.rpc("set_trust_signal_visibility", {
        p_signal_type: "school_affiliation",
        p_visible: true,
      });
      assertQa(!visibility.error && visibility.data?.organization_name_public === false, "visibility toggle exposed organization name");
      const publicProfile = await viewer.client.rpc("get_public_trust_badges", { p_user_id: teen.id });
      assertQa(!publicProfile.error && publicProfile.data?.ok === true, "same-environment public trust profile failed");
      const serialized = JSON.stringify(publicProfile.data).toLowerCase();
      assertQa(!serialized.includes(teen.email.toLowerCase()), "public trust profile exposed email");
      assertQa(!serialized.includes("synthetic qa school domain"), "public trust profile exposed school name");
      assertQa(
        !("residential_address" in publicProfile.data) && !("full_address" in publicProfile.data),
        "public trust profile exposed a residential address field",
      );
      assertQa(publicProfile.data.school_name_exposed === false && publicProfile.data.email_or_phone_exposed === false, "privacy flags were not fail-closed");
      qaLog(scope, "public trust indicators expose precise checks without email, phone, school name, residence, or confidential reports");
    },
  );
}

async function runDigitalReplay(scope) {
  await withQaUsers(
    scope,
    [{ key: "adult", role: "adult", identityVerified: false, isTest: true }],
    async ({ adult }) => {
      await withDatabase(async (database) => {
        await database.query("begin");
        try {
          await database.query("update private.trust_policy_versions set android_digital_credentials_enabled=true where is_active");
          async function createSession() {
            const nonce = randomBytes(32).toString("hex");
            const result = await database.query(
              "select public.create_digital_credential_session($1,'android_credential_manager','sandbox',$2,'issuer.qa.gov','org.iso.18013.5.1.mDL',$3::jsonb,now()+interval '5 minutes') as result",
              [adult.id, nonce, JSON.stringify(["age_over_18"])],
            );
            assertQa(result.rows[0].result?.ok === true, "digital credential QA session was not created");
            return result.rows[0].result.session_id;
          }
          async function process(sessionId, overrides = {}) {
            const values = {
              eventId: `evt-${randomUUID()}`,
              payload: randomBytes(32).toString("hex"),
              signature: true,
              nonce: true,
              binding: true,
              issuer: "issuer.qa.gov",
              type: "org.iso.18013.5.1.mDL",
              validUntil: new Date(Date.now() + 3_600_000),
              ...overrides,
            };
            const result = await database.query(
              "select public.process_digital_credential_result($1,$2,$3,$4,$5,$6,$7,$8,$9) as result",
              [sessionId, values.eventId, values.payload, values.signature, values.nonce, values.binding, values.issuer, values.type, values.validUntil],
            );
            return { result: result.rows[0].result, values };
          }

          const missingValidation = await process(await createSession(), { signature: false });
          assertQa(missingValidation.result.code === "signature_validation_failed", "missing backend signature validation did not fail closed");
          const unknownIssuer = await process(await createSession(), { issuer: "unknown.qa.gov" });
          assertQa(unknownIssuer.result.code === "unknown_issuer", "unknown credential issuer was accepted");
          const expired = await process(await createSession(), { validUntil: new Date(Date.now() - 1_000) });
          assertQa(expired.result.code === "credential_expired", "expired credential was accepted");
          const sessionId = await createSession();
          const valid = await process(sessionId);
          assertQa(valid.result.ok === true && valid.result.marketplace_access_granted === false, "valid sandbox credential bypassed marketplace policy");
          const replay = await database.query(
            "select public.process_digital_credential_result($1,$2,$3,true,true,true,'issuer.qa.gov','org.iso.18013.5.1.mDL',now()+interval '1 hour') as result",
            [sessionId, valid.values.eventId, valid.values.payload],
          );
          assertQa(replay.rows[0].result.code === "digital_credential_replay_detected", "digital credential replay was accepted");
          qaLog(scope, "digital credential flow rejects missing validation, unknown issuer, expiration, and replay; sandbox never grants production access");
        } finally {
          await database.query("rollback");
        }
      });
    },
  );
}

async function runSandboxIsolation(scope) {
  await withQaUsers(
    scope,
    [
      { key: "qaTeen", role: "teen", identityVerified: false, isTest: true },
      { key: "ordinary", role: "adult", identityVerified: false, isTest: false },
    ],
    async ({ qaTeen, ordinary }) => {
      const school = await qaTeen.client.rpc("request_school_email_affiliation", { p_school_email: qaTeen.email });
      assertQa(!school.error && school.data?.affiliation_verified === true, "sandbox affiliation setup failed");
      const crossEnvironment = await ordinary.client.rpc("get_public_trust_badges", { p_user_id: qaTeen.id });
      assertQa(crossEnvironment.data?.code === "profile_not_found", "production caller probed sandbox trust profile");
      const ordinaryEligibility = await eligibility(ordinary, "browse");
      assertQa(ordinaryEligibility.allowed === false && ordinaryEligibility.reason_codes.includes("production_marketplace_closed"), "sandbox work altered production policy");
      const qaEligibility = await eligibility(qaTeen, "browse");
      assertQa(qaEligibility.allowed === false, "affiliation-only QA user bypassed the existing sandbox identity requirement");
      qaLog(scope, "sandbox signals stay isolated and affiliation alone cannot become sandbox or production marketplace identity");
    },
  );
}

const suites = new Map([
  ["qa-account-trust-levels", runLevels],
  ["qa-biometric-not-identity", runBiometric],
  ["qa-marketplace-trust-gating", runMarketplaceGating],
  ["qa-school-email-affiliation", runSchoolAffiliation],
  ["qa-partner-code-affiliation", runPartnerCode],
  ["qa-business-registry-trust", runBusinessRegistry],
  ["qa-public-data-boundaries", runPublicData],
  ["qa-guardian-optional-trust", runGuardianOptional],
  ["qa-trust-badge-forgery", runBadgeForgery],
  ["qa-trust-profile-privacy", runProfilePrivacy],
  ["qa-digital-credential-replay", runDigitalReplay],
  ["qa-sandbox-production-trust-isolation", runSandboxIsolation],
]);

export async function runAccountTrustSuite(scope) {
  const suite = suites.get(scope);
  if (!suite) throw new Error(`Unknown account-trust QA suite: ${scope}`);
  await suite(scope);
}
