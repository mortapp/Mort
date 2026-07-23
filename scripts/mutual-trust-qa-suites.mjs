import { createHash, randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  saveJob,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const jpegBytes = Buffer.from(
  "/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAEf/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EB//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EB//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EB//2Q==",
  "base64",
);
const evidenceHash = createHash("sha256").update(jpegBytes).digest("hex").toUpperCase();
const uploadedObjects = [];

async function withMutualUsers(scope, definitions, run) {
  await withQaUsers(scope, definitions, async (users) => {
    try {
      await run(users);
    } finally {
      await cleanupMutualTrustData(users);
      await cleanupUploads(scope);
    }
  });
}

async function cleanupMutualTrustData(users) {
  const userIds = Object.values(users).map((user) => user.id);
  await withDatabase(async (database) => {
      await database.query("begin");
    try {
      await database.query("select set_config('mort.internal_update', 'true', true)");
      await database.query(
        `
          create temporary table qa_mutual_incidents (
            id uuid primary key
          ) on commit drop
        `,
      );
      await database.query(
        `
          insert into qa_mutual_incidents (id)
          select distinct incident.id
          from public.safety_incidents incident
          where incident.reporter_id = any($1::uuid[])
             or incident.subject_user_id = any($1::uuid[])
             or exists (
               select 1
               from public.incident_participants participant
               where participant.incident_id = incident.id
                 and participant.user_id = any($1::uuid[])
             )
        `,
        [userIds],
      );
      await database.query(
        `
          delete from public.verification_audit_events
          where verification_id in (
            select id
            from public.identity_verifications
            where user_id = any($1::uuid[])
          )
        `,
        [userIds],
      );
      await database.query(
        `
          delete from public.identity_verification_evidence
          where verification_id in (
            select id
            from public.identity_verifications
            where user_id = any($1::uuid[])
          )
        `,
        [userIds],
      );
      await database.query(
        "delete from public.message_safety_evidence where sender_id = any($1::uuid[])",
        [userIds],
      );
      for (const table of [
        "incident_actions",
        "incident_appeals",
        "incident_contact_attempts",
        "incident_evidence",
        "incident_law_enforcement_requests",
        "incident_outcomes",
        "incident_preservation_orders",
        "incident_timeline_events",
      ]) {
        await database.query(`delete from public.${table} where incident_id in (select id from qa_mutual_incidents)`);
      }
      await database.query(
        "delete from public.safety_incidents where id in (select id from qa_mutual_incidents)",
      );
      await database.query(
        "delete from public.safety_cancellations where actor_id = any($1::uuid[])",
        [userIds],
      );
      await database.query(
        "delete from public.job_execution_events where actor_id = any($1::uuid[])",
        [userIds],
      );
      await database.query(
        "delete from public.job_arrival_handshakes where teen_id = any($1::uuid[]) or adult_id = any($1::uuid[])",
        [userIds],
      );
      await database.query(
        "delete from private.stripe_job_payment_intents where adult_id = any($1::uuid[]) or teen_id = any($1::uuid[])",
        [userIds],
      );
      await database.query("commit");
    } catch (error) {
      await database.query("rollback").catch(() => {});
      throw error;
    }
  });
}

async function cleanupUploads(scope) {
  const byBucket = Map.groupBy(uploadedObjects.splice(0), (item) => item.bucket);
  for (const [bucket, items] of byBucket) {
    const { error } = await serviceClient.storage.from(bucket).remove(items.map((item) => item.path));
    if (error) console.error(`[${scope}] storage cleanup warning: ${error.message}`);
  }
}

function expectRpc(result, context) {
  assertQa(!result.error, `${context} transport failed: ${result.error?.message}`);
  assertQa(result.data?.ok === true, `${context} rejected: ${JSON.stringify(result.data)}`);
  return result.data;
}

function nearTermDaytimeSchedule() {
  const now = new Date();
  const offsetHours = 12 - now.getUTCHours();
  const timezone = offsetHours === 0
    ? "UTC"
    : `Etc/GMT${offsetHours > 0 ? "-" : "+"}${Math.abs(offsetHours)}`;
  return {
    schedule_type: "exact",
    starts_at: new Date(now.getTime() + 5 * 60 * 1000).toISOString(),
    ends_at: new Date(now.getTime() + 65 * 60 * 1000).toISOString(),
    timezone,
  };
}

async function uploadIncidentEvidence(user, incidentId, evidenceType = "photo") {
  const evidenceId = randomUUID();
  const path = `${user.id}/${incidentId}/${evidenceId}.jpg`;
  const stored = await user.client.storage.from("incident-evidence").upload(path, jpegBytes, {
    contentType: "image/jpeg",
    upsert: false,
  });
  assertQa(!stored.error, `incident evidence upload failed: ${stored.error?.message}`);
  uploadedObjects.push({ bucket: "incident-evidence", path });
  const registered = await user.client.rpc("register_incident_evidence", {
    p_incident_id: incidentId,
    p_evidence_id: evidenceId,
    p_storage_path: path,
    p_evidence_type: evidenceType,
    p_sha256: evidenceHash,
  });
  expectRpc(registered, "register incident evidence");
  return { evidenceId, path };
}

async function createAcceptedApplication(teen, adult, overrides = {}) {
  const created = await saveJob(adult.client, overrides);
  assertQa(created.result?.ok === true, `job publish failed: ${JSON.stringify(created.result)}`);
  assertQa(
    created.result.job?.status === "open" && created.result.job?.applications_open === true,
    `published QA job was not open: ${JSON.stringify({
      status: created.result.job?.status,
      applicationsOpen: created.result.job?.applications_open,
      pilotReviewStatus: created.result.job?.pilot_review_status,
      pilotReasons: created.result.job?.pilot_restriction_reasons,
    })}`,
  );
  const submitted = await teen.client.rpc("submit_job_application", {
    p_job_id: created.result.job.id,
    p_note: "I am available and understand the posted scope and safety expectations.",
    p_availability_confirmed: true,
    p_portfolio_ids: [],
  });
  const application = expectRpc(submitted, "submit job application").application;
  const accepted = await adult.client.rpc("update_application_status_v2", {
    p_application_id: application.id,
    p_action: "accepted",
  });
  expectRpc(accepted, "accept application");
  return { job: created.result.job, application };
}

async function confirmAgreement(teen, adult, applicationId) {
  const agreementQuery = await teen.client
    .from("job_safety_agreements")
    .select("id,agreement_version,status")
    .eq("application_id", applicationId)
    .single();
  assertQa(!agreementQuery.error, `safety agreement unavailable: ${agreementQuery.error?.message}`);
  const version = agreementQuery.data.agreement_version;
  expectRpc(
    await teen.client.rpc("confirm_job_safety_agreement", {
      p_application_id: applicationId,
      p_agreement_version: version,
    }),
    "teen safety agreement confirmation",
  );
  const confirmed = expectRpc(
    await adult.client.rpc("confirm_job_safety_agreement", {
      p_application_id: applicationId,
      p_agreement_version: version,
    }),
    "adult safety agreement confirmation",
  );
  assertQa(confirmed.status === "confirmed", "both confirmations did not confirm the agreement");
  return version;
}

async function activateAndFundJobExecution(teen, adult, applicationId) {
  const contract = await serviceClient
    .from("job_contracts")
    .select("id,active_version_id,status")
    .eq("application_id", applicationId)
    .single();
  assertQa(!contract.error && contract.data, `job contract unavailable: ${contract.error?.message}`);
  const version = await serviceClient
    .from("job_contract_versions")
    .select("id")
    .eq("contract_id", contract.data.id)
    .eq("version_number", 1)
    .single();
  assertQa(!version.error && version.data, `job contract version unavailable: ${version.error?.message}`);

  const confirmation = {
    p_contract_version_id: version.data.id,
    p_affirmative_checkbox: true,
    p_confirmation_text: "I reviewed and confirm this exact job agreement.",
    p_platform: "qa",
    p_app_version: "qa-0.9.3",
  };
  const teenConfirmation = await teen.client.rpc("confirm_job_contract_version", confirmation);
  assertQa(
    !teenConfirmation.error && teenConfirmation.data?.ok === true,
    `teen contract confirmation failed: ${teenConfirmation.error?.message ?? teenConfirmation.data?.code}`,
  );
  const adultConfirmation = await adult.client.rpc("confirm_job_contract_version", confirmation);
  assertQa(
    !adultConfirmation.error && adultConfirmation.data?.contract_active === true,
    `adult contract confirmation failed: ${adultConfirmation.error?.message ?? adultConfirmation.data?.code}`,
  );

  const obligation = await serviceClient
    .from("job_payment_obligations")
    .select("id,amount_cents,currency_code")
    .eq("contract_id", contract.data.id)
    .eq("contract_version_id", version.data.id)
    .single();
  assertQa(!obligation.error && obligation.data, `job payment obligation unavailable: ${obligation.error?.message}`);
  await withDatabase(async (database) => {
    await database.query(
      `insert into private.stripe_job_payment_intents (
         contract_id, contract_version_id, obligation_id, adult_id, teen_id,
         environment, earnings_amount_cents, service_fee_cents,
         total_amount_cents, currency_code, transfer_group, idempotency_key,
         status, funded_at, last_synchronized_at
       ) values ($1, $2, $3, $4, $5, 'test', $6, 0, $6, $7, $8, $9, 'funded', now(), now())`,
      [
        contract.data.id,
        version.data.id,
        obligation.data.id,
        adult.id,
        teen.id,
        obligation.data.amount_cents,
        obligation.data.currency_code,
        `MORT_JOB_${randomUUID().replaceAll("-", "")}`,
        `qa-arrival-funded-${randomUUID()}`,
      ],
    );
  });
}

async function getApplicationThread(user, applicationId) {
  const query = await user.client
    .from("message_threads")
    .select("id")
    .eq("application_id", applicationId)
    .single();
  assertQa(!query.error, `application thread unavailable: ${query.error?.message}`);
  return query.data.id;
}

async function runMutualVerification(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "verifiedAdult", role: "adult" },
      { key: "verifiedTeen", role: "teen" },
      { key: "unverifiedAdult", role: "adult", identityVerified: false },
      { key: "unverifiedTeen", role: "teen", identityVerified: false },
    ],
    async ({ verifiedAdult, verifiedTeen, unverifiedAdult, unverifiedTeen }) => {
      const blockedPublish = await saveJob(unverifiedAdult.client);
      assertQa(blockedPublish.result?.ok === false && ["poster_verification_required", "identity_verification_required"].includes(blockedPublish.result.code), "unverified adult published a job");
      qaLog(scope, "unverified adult cannot publish");

      const published = await saveJob(verifiedAdult.client, {
        title: "QA Mutual Verification Public Library Help",
      });
      assertQa(published.result?.ok === true, "verified adult could not publish");
      const blockedEligibility = await unverifiedTeen.client.rpc("get_job_application_eligibility", {
        p_job_id: published.result.job.id,
      });
      assertQa(blockedEligibility.data?.code === "applicant_verification_required", "unverified teen was not blocked from applying");
      const eligible = await verifiedTeen.client.rpc("get_job_application_eligibility", {
        p_job_id: published.result.job.id,
      });
      assertQa(eligible.data?.eligible === true && eligible.data.guardian_mode_optional === true, "verified teen without guardian was not eligible");
      qaLog(scope, "verified teen can apply without Guardian Mode while unverified teen cannot");

      const submitted = expectRpc(
        await verifiedTeen.client.rpc("submit_job_application", {
          p_job_id: published.result.job.id,
          p_note: "I can complete this safe public-library task.",
          p_availability_confirmed: true,
          p_portfolio_ids: [],
        }),
        "verified teen application",
      );
      expectRpc(
        await verifiedAdult.client.rpc("update_application_status_v2", {
          p_application_id: submitted.application.id,
          p_action: "accepted",
        }),
        "application acceptance",
      );
      const threadId = await getApplicationThread(verifiedTeen, submitted.application.id);
      const message = await verifiedTeen.client.rpc("send_safe_message", {
        p_thread_id: threadId,
        p_body: "I will meet at the public check-in desk at the agreed time.",
      });
      assertQa(!message.error && message.data?.scanner_status === "clean", "verified teen could not message after acceptance");
      qaLog(scope, "verified accepted participants can use safety-scanned messaging");
    },
  );
}

async function runTeenSchoolIsolation(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen", identityVerified: false },
      { key: "adult", role: "adult" },
      { key: "guardian", role: "guardian" },
    ],
    async ({ teen, adult, guardian }) => {
      const started = await teen.client.rpc("start_identity_verification", {
        p_evidence_route: "school_photo_id",
        p_attested: true,
        p_exception_reason: null,
      });
      assertQa(
        !started.error && started.data?.code === "identity_verification_disabled",
        "disabled mode accepted a teen school-ID route",
      );

      const attemptedPath = `sandbox/${teen.id}/${randomUUID()}.jpg`;
      const upload = await teen.client.storage
        .from("identity-evidence")
        .upload(attemptedPath, jpegBytes, { contentType: "image/jpeg", upsert: false });
      assertQa(upload.error, "disabled mode accepted a school-ID object");

      for (const observer of [teen, adult, guardian]) {
        const rows = await observer.client
          .from("identity_verification_evidence")
          .select("id,storage_path")
          .eq("user_id", teen.id);
        assertQa(
          rows.error || rows.data.length === 0,
          `${observer.role} could list teen identity evidence`,
        );
      }

      const profile = await adult.client.from("profiles").select().eq("id", teen.id).maybeSingle();
      if (profile.data) {
        const serialized = JSON.stringify(profile.data).toLowerCase();
        assertQa(!serialized.includes("school_name") && !serialized.includes("student_number"), "school identifiers entered the public profile payload");
      }
      const ownStatus = await teen.client.rpc("get_my_identity_verification");
      assertQa(ownStatus.data?.verification_mode === "disabled", "hosted mode was not disabled");
      assertQa(!JSON.stringify(ownStatus.data).includes(attemptedPath), "identity status leaked an attempted storage path");
      qaLog(scope, "teen school-ID intake is disabled and no school identifiers or object paths are exposed");
    },
  );
}

async function runTeenAlternatives(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "schoolAccountTeen", role: "teen", identityVerified: false },
      { key: "programTeen", role: "teen", identityVerified: false },
      { key: "exceptionTeen", role: "teen", identityVerified: false },
    ],
    async ({ schoolAccountTeen, programTeen, exceptionTeen }) => {
      for (const [user, route] of [
        [schoolAccountTeen, "verified_school_account"],
        [programTeen, "approved_program_id"],
        [exceptionTeen, "manual_exception"],
      ]) {
        const result = await user.client.rpc("start_identity_verification", {
          p_evidence_route: route,
          p_attested: true,
          p_exception_reason: route === "manual_exception"
            ? "No personal evidence may be collected while provider verification is disabled."
            : null,
        });
        assertQa(
          !result.error && result.data?.code === "identity_verification_disabled",
          `${route} bypassed disabled verification mode`,
        );
      }
      const rows = await serviceClient
        .from("identity_verifications")
        .select("id")
        .in("user_id", [schoolAccountTeen.id, programTeen.id, exceptionTeen.id]);
      assertQa(rows.data?.length === 0, "disabled alternative routes created verification records");
      qaLog(scope, "all teen alternative routes fail closed without collecting school, program, or referee evidence");
    },
  );
}

async function runAdultIDIsolation(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "adult", role: "adult", identityVerified: false },
      { key: "teen", role: "teen" },
      { key: "otherAdult", role: "adult" },
    ],
    async ({ adult, teen, otherAdult }) => {
      const started = await adult.client.rpc("start_identity_verification", {
        p_evidence_route: "government_id",
        p_attested: true,
        p_exception_reason: null,
      });
      assertQa(
        !started.error && started.data?.code === "identity_verification_disabled",
        "disabled mode accepted an adult government-ID route",
      );
      const productionPath = `production/${adult.id}/${randomUUID()}.jpg`;
      const attemptedUpload = await adult.client.storage
        .from("identity-evidence")
        .upload(productionPath, jpegBytes, { contentType: "image/jpeg", upsert: false });
      assertQa(attemptedUpload.error, "ordinary adult uploaded production identity evidence");

      for (const observer of [teen, otherAdult]) {
        const rows = await observer.client
          .from("identity_verification_evidence")
          .select("id,storage_path")
          .eq("user_id", adult.id);
        assertQa(
          rows.error || rows.data.length === 0,
          `${observer.role} could list another adult's ID evidence`,
        );
        const download = await observer.client.storage.from("identity-evidence").download(productionPath);
        assertQa(download.error, `${observer.role} downloaded another adult's ID evidence`);
      }
      const publicBadge = await teen.client.rpc("get_public_trust_badges", { p_user_id: adult.id });
      assertQa(!JSON.stringify(publicBadge.data).includes("adult_identity_verified"), "sandbox QA identity appeared as production verified");
      assertQa(!JSON.stringify(publicBadge.data).includes(productionPath), "public trust badge leaked an attempted ID path");
      qaLog(scope, "adult ID, selfie, and address collection is disabled and cannot produce a public verification badge");
    },
  );
}

async function runAddressPrivacy(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
      { key: "outsider", role: "teen" },
    ],
    async ({ teen, adult, outsider }) => {
      const { job, application } = await createAcceptedApplication(teen, adult, {
        title: "QA Private Address Stage Test",
        location_text: "Broad Ripple public area",
      });
      const address = "123 QA Restricted Street, Indianapolis, IN 46204";
      expectRpc(
        await adult.client.rpc("save_job_private_location", {
          p_job_id: job.id,
          p_exact_address: address,
          p_arrival_instructions: "Meet at the staffed front entrance.",
          p_access_notes: null,
        }),
        "save restricted location",
      );

      const publicJob = await outsider.client.from("jobs").select().eq("id", job.id).maybeSingle();
      assertQa(!publicJob.error, `outsider job lookup failed: ${publicJob.error?.message}`);
      assertQa(!JSON.stringify(publicJob.data).includes(address), "exact address appeared in accessible job payload");
      const directPrivateRead = await teen.client.from("job_private_locations").select().eq("job_id", job.id);
      assertQa(!directPrivateRead.error && directPrivateRead.data.length === 0, "teen bypassed staged-location RPC with a direct read");

      const before = await teen.client.rpc("get_released_job_location", { p_application_id: application.id });
      assertQa(before.data?.code === "exact_location_not_released", "exact address released before mutual confirmation");
      const agreement = await teen.client
        .from("job_safety_agreements")
        .select("agreement_version")
        .eq("application_id", application.id)
        .single();
      expectRpc(
        await teen.client.rpc("confirm_job_safety_agreement", {
          p_application_id: application.id,
          p_agreement_version: agreement.data.agreement_version,
        }),
        "teen location terms confirmation",
      );
      const oneSided = await teen.client.rpc("get_released_job_location", { p_application_id: application.id });
      assertQa(oneSided.data?.code === "exact_location_not_released", "one-sided confirmation released exact address");
      expectRpc(
        await adult.client.rpc("confirm_job_safety_agreement", {
          p_application_id: application.id,
          p_agreement_version: agreement.data.agreement_version,
        }),
        "adult location terms confirmation",
      );
      const released = expectRpc(
        await teen.client.rpc("get_released_job_location", { p_application_id: application.id }),
        "staged location release",
      );
      assertQa(released.exact_address === address, "confirmed participant did not receive the restricted address");
      const outsiderRelease = await outsider.client.rpc("get_released_job_location", { p_application_id: application.id });
      assertQa(outsiderRelease.data?.code === "exact_location_not_released", "unrelated teen received exact job location");
      qaLog(scope, "exact home/job address stays private until acceptance and two-sided confirmation");
    },
  );
}

async function runVerificationForgery(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "adult", role: "adult", identityVerified: false },
      { key: "secondAdult", role: "adult", identityVerified: false },
      { key: "reviewer", role: "admin" },
      { key: "unprivilegedAdmin", role: "admin" },
    ],
    async ({ adult, secondAdult, reviewer, unprivilegedAdmin }) => {
      const forgedInsert = await adult.client.from("identity_verifications").insert({
        user_id: adult.id,
        account_role: "adult",
        evidence_route: "government_id",
        status: "verified",
        verification_level: 4,
        age_band: "adult_18_plus",
      });
      assertQa(forgedInsert.error, "ordinary adult forged a verified identity row");
      const profileForge = await adult.client.from("profiles").update({ verification_status: "approved" }).eq("id", adult.id).select("id");
      assertQa(profileForge.error || profileForge.data.length === 0, "ordinary adult forged profile verification status");

      const disabledStart = await adult.client.rpc("start_identity_verification", {
        p_evidence_route: "government_id",
        p_attested: true,
        p_exception_reason: null,
      });
      assertQa(disabledStart.data?.code === "identity_verification_disabled", "disabled mode allowed verification start");
      const evidenceRegistration = await adult.client.rpc("register_identity_evidence", {
        p_verification_id: randomUUID(),
        p_evidence_id: randomUUID(),
        p_storage_path: `production/${adult.id}/${randomUUID()}.jpg`,
        p_evidence_type: "drivers_license",
        p_sha256: evidenceHash,
      });
      assertQa(
        evidenceRegistration.data?.code === "identity_document_collection_disabled",
        "identity evidence registration RPC did not fail closed",
      );

      await serviceClient.from("admin_role_assignments").insert({
        user_id: reviewer.id,
        role: "verification_reviewer",
        grant_reason: "Isolated QA role must not grant production identity access.",
      });
      const unauthorizedManifest = await unprivilegedAdmin.client.rpc("get_identity_evidence_manifest", {
        p_verification_id: randomUUID(),
      });
      assertQa(unauthorizedManifest.error, "unprivileged admin received identity evidence manifest");
      const manifest = await reviewer.client.rpc("get_identity_evidence_manifest", {
        p_verification_id: randomUUID(),
      });
      assertQa(manifest.error, "legacy verification_reviewer role received production identity evidence access");

      const adminApproval = await reviewer.client.rpc("admin_review_identity_verification", {
        p_verification_id: randomUUID(),
        p_action: "approve",
        p_decision_code: "qa_attempt",
        p_identity_match_result: "passed",
        p_liveness_result: "passed",
        p_email_result: "passed",
        p_phone_result: "passed",
        p_address_result: "passed",
        p_expires_at: new Date(Date.now() + 86400000).toISOString(),
      });
      assertQa(
        adminApproval.data?.code === "production_identity_reviewer_required",
        "ordinary verification reviewer could approve production identity",
      );

      const clientProviderResult = await secondAdult.client.rpc(
        "process_identity_verification_provider_result",
        {
          p_event_id: `qa-${randomUUID()}`,
          p_provider: "unconfigured",
          p_environment: "production",
          p_provider_reference: `qa-${randomUUID()}`,
          p_user_id: secondAdult.id,
          p_result_status: "approved",
          p_age_band: "adult_18_plus",
          p_verification_level: 2,
          p_expires_at: new Date(Date.now() + 86400000).toISOString(),
          p_event_timestamp: new Date().toISOString(),
          p_payload_sha256: evidenceHash,
          p_signature_verified: true,
        },
      );
      assertQa(clientProviderResult.error, "ordinary client executed the service-only provider result RPC");
      qaLog(scope, "client rows, profile status, evidence registration, admin approval, and provider results cannot be forged");
    },
  );
}

async function runGuardianOptional(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const policy = await teen.client.rpc("get_guardian_policy_for_user");
      assertQa(!policy.error, `guardian policy lookup failed: ${policy.error?.message}`);
      assertQa(policy.data.guardian_link_required === false, "guardian link became globally required");
      assertQa(policy.data.guardian_approval_required_for_application === false, "guardian application approval became global");
      const skipped = expectRpc(await teen.client.rpc("set_guardian_setup_skipped"), "skip Guardian Mode");
      assertQa(skipped.ok, "Guardian Mode skip failed");
      const job = await saveJob(adult.client);
      const eligibility = await teen.client.rpc("get_job_application_eligibility", { p_job_id: job.result.job.id });
      assertQa(eligibility.data?.eligible === true && eligibility.data.guardian_mode_optional === true, "verified teen without guardian lost normal marketplace access");
      qaLog(scope, "Guardian Mode remains optional and separate from mandatory identity verification");
    },
  );
}

async function runSafetyCircle(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "contact", role: "guardian", identityVerified: true },
      { key: "outsider", role: "guardian", identityVerified: true },
    ],
    async ({ teen, contact, outsider }) => {
      const invite = expectRpc(
        await teen.client.rpc("create_safety_circle_invite", {
          p_relationship_label: "Trusted QA aunt",
          p_permissions: {
            receive_safety_ping: false,
            receive_missed_checkin: true,
            receive_job_summary: true,
            receive_job_status: false,
            view_limited_safety_plan: false,
          },
        }),
        "create Safety Circle invite",
      );
      expectRpc(
        await contact.client.rpc("accept_safety_circle_invite", { p_invite_code: invite.invite_code }),
        "accept Safety Circle invite",
      );
      const outsiderRows = await outsider.client.from("safety_circle_members").select("id").eq("id", invite.circle_id);
      assertQa(!outsiderRows.error && outsiderRows.data.length === 0, "unrelated guardian read Safety Circle membership");

      const silentPing = await teen.client
        .from("safety_pings")
        .insert({ teen_id: teen.id, status: "ok", note: "Permission-off QA ping" })
        .select("id")
        .single();
      assertQa(!silentPing.error, `silent ping insert failed: ${silentPing.error?.message}`);
      const hidden = await contact.client.from("safety_pings").select("id").eq("id", silentPing.data.id);
      assertQa(!hidden.error && hidden.data.length === 0, "contact received a disabled Safety Ping permission");

      const contactPermissionWrite = await contact.client.rpc("update_safety_circle_permissions", {
        p_circle_id: invite.circle_id,
        p_permissions: { receive_safety_ping: true },
      });
      assertQa(contactPermissionWrite.data?.code === "safety_circle_not_found", "trusted contact changed teen-controlled permissions");
      expectRpc(
        await teen.client.rpc("update_safety_circle_permissions", {
          p_circle_id: invite.circle_id,
          p_permissions: { receive_safety_ping: true },
        }),
        "teen updates Safety Circle permission",
      );
      const visiblePing = await teen.client
        .from("safety_pings")
        .insert({ teen_id: teen.id, status: "needs_help", note: "Permission-on QA ping" })
        .select("id")
        .single();
      const visible = await contact.client.from("safety_pings").select("id").eq("id", visiblePing.data.id);
      assertQa(visible.data?.length === 1, "contact did not receive an enabled Safety Ping");
      expectRpc(
        await contact.client.rpc("unlink_safety_circle_member", { p_circle_id: invite.circle_id }),
        "contact unlinks Safety Circle",
      );
      qaLog(scope, "Safety Circle grants only teen-selected alerts and either participant can unlink");
    },
  );
}

async function runLocationStages(scope) {
  await runAddressPrivacy(scope);
}

async function runArrivalHandshake(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const { application } = await createAcceptedApplication(teen, adult, {
        title: "QA Arrival Handshake Public Task",
        ...nearTermDaytimeSchedule(),
      });
      await confirmAgreement(teen, adult, application.id);
      await activateAndFundJobExecution(teen, adult, application.id);
      const generated = expectRpc(
        await adult.client.rpc("generate_job_arrival_code", { p_application_id: application.id }),
        "generate arrival code",
      );
      const wrong = await teen.client.rpc("confirm_job_arrival_code", {
        p_application_id: application.id,
        p_code: "ABCDEF",
        p_person_matches_profile: true,
      });
      assertQa(
        ["six_digit_pin_required", "pin_format_invalid", "arrival_code_invalid"].includes(wrong.data?.code),
        "wrong arrival code was accepted",
      );
      const confirmed = expectRpc(
        await teen.client.rpc("confirm_job_arrival_code", {
          p_application_id: application.id,
          p_code: generated.arrival_code,
          p_person_matches_profile: true,
        }),
        "confirm arrival code",
      );
      assertQa(confirmed.identity_documents_exchanged !== true, "arrival handshake claimed documents were exchanged");
      const replay = await teen.client.rpc("confirm_job_arrival_code", {
        p_application_id: application.id,
        p_code: generated.arrival_code,
        p_person_matches_profile: true,
      });
      assertQa(
        !replay.error && replay.data?.ok === true && replay.data?.replayed === true,
        "arrival confirmation replay was not handled idempotently",
      );
      qaLog(scope, "arrival code is short-lived, validated, and single-use without document exchange");
    },
  );
}

async function runPersonMismatch(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const { application } = await createAcceptedApplication(teen, adult, {
        title: "QA Person Mismatch Check",
        ...nearTermDaytimeSchedule(),
      });
      await confirmAgreement(teen, adult, application.id);
      await activateAndFundJobExecution(teen, adult, application.id);
      const code = expectRpc(
        await adult.client.rpc("generate_job_arrival_code", { p_application_id: application.id }),
        "generate mismatch arrival code",
      );
      const mismatch = expectRpc(
        await teen.client.rpc("confirm_job_arrival_code", {
          p_application_id: application.id,
          p_code: code.arrival_code,
          p_person_matches_profile: false,
        }),
        "person mismatch report",
      );
      assertQa(mismatch.person_mismatch === true && mismatch.safe_exit_recommended === true, "person mismatch did not return safe-exit guidance");
      const incident = await serviceClient
        .from("safety_incidents")
        .select("category,severity,preservation_status")
        .eq("id", mismatch.incident_id)
        .single();
      assertQa(incident.data?.category === "identity_mismatch" && incident.data?.severity === "high", "person mismatch case was misclassified");
      qaLog(scope, "person mismatch creates a high-severity restricted incident and safe-exit response");
    },
  );
}

async function runMutualReporting(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const { job, application } = await createAcceptedApplication(teen, adult, {
        title: "QA Two-Way Reporting Test",
      });
      const teenReport = expectRpc(
        await teen.client.rpc("submit_safety_report", {
          p_target_user_id: adult.id,
          p_target_job_id: job.id,
          p_target_message_id: null,
          p_target_review_id: null,
          p_application_id: application.id,
          p_category: "unsafe_job_conditions",
          p_severity: "moderate",
          p_immediate_danger: false,
          p_details: "The physical job conditions differed materially from the posted scope.",
          p_occurred_at: null,
          p_location_type: "public",
          p_desired_outcome: "Review the changed job conditions.",
          p_confidential_safety_feedback: true,
        }),
        "teen reports adult",
      );
      const adultReport = expectRpc(
        await adult.client.rpc("submit_safety_report", {
          p_target_user_id: teen.id,
          p_target_job_id: job.id,
          p_target_message_id: null,
          p_target_review_id: null,
          p_application_id: application.id,
          p_category: "property_damage",
          p_severity: "moderate",
          p_immediate_danger: false,
          p_details: "Property damage was observed and needs a neutral factual review.",
          p_occurred_at: null,
          p_location_type: "public",
          p_desired_outcome: "Document facts and review both accounts.",
          p_confidential_safety_feedback: false,
        }),
        "adult reports teen",
      );
      assertQa(teenReport.incident_id !== adultReport.incident_id, "two independent reports were collapsed incorrectly");
      const teenCases = await teen.client.rpc("get_my_incident_cases");
      const adultCases = await adult.client.rpc("get_my_incident_cases");
      assertQa(teenCases.data.some((item) => item.incident_id === teenReport.incident_id), "teen cannot see own report case status");
      assertQa(adultCases.data.some((item) => item.incident_id === adultReport.incident_id), "adult cannot see own report case status");
      qaLog(scope, "teens and adults can independently report each other into isolated case records");
    },
  );
}

async function runHarassmentControls(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const { application } = await createAcceptedApplication(teen, adult, {
        title: "QA Harassment Scanner Test",
      });
      const threadId = await getApplicationThread(teen, application.id);
      const flagged = await adult.client.rpc("send_safe_message", {
        p_thread_id: threadId,
        p_body: "You are a stupid kid and this is humiliating.",
      });
      assertQa(!flagged.error && flagged.data?.scanner_status === "flagged" && flagged.data?.safer_rewrite_available === true, "harassing message was not flagged with safer rewrite");
      const threat = await adult.client.rpc("send_safe_message", {
        p_thread_id: threadId,
        p_body: "I will hurt you and I know where you live.",
      });
      assertQa(!threat.error && threat.data?.scanner_status === "blocked" && threat.data?.body === "[Blocked by MORT safety controls]", "threat was not blocked with placeholder body");
      const preserved = await serviceClient
        .from("message_safety_evidence")
        .select("severity,preserved_until")
        .eq("message_id", threat.data.id)
        .single();
      assertQa(preserved.data?.severity === "critical" && preserved.data?.preserved_until, "threat evidence was not restricted and preserved");

      const blocked = await teen.client.from("blocks").insert({ blocker_id: teen.id, blocked_id: adult.id });
      assertQa(!blocked.error, `block failed: ${blocked.error?.message}`);
      const afterBlock = await adult.client.rpc("send_safe_message", {
        p_thread_id: threadId,
        p_body: "This ordinary message should not be delivered after blocking.",
      });
      assertQa(afterBlock.error, "blocking did not stop ordinary contact");
      qaLog(scope, "harassment is flagged, threats are blocked and preserved, and blocking closes ordinary contact");
    },
  );
}

async function runSexualSafety(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const { application } = await createAcceptedApplication(teen, adult, {
        title: "QA Sexual Safety Scanner Test",
      });
      const threadId = await getApplicationThread(teen, application.id);
      const blocked = await adult.client.rpc("send_safe_message", {
        p_thread_id: threadId,
        p_body: "Send me a nude photo and keep this secret from your guardian.",
      });
      assertQa(!blocked.error && blocked.data?.scanner_status === "blocked", "sexual adult-minor message was not blocked");
      assertQa(blocked.data.body === "[Blocked by MORT safety controls]" && blocked.data.safety_severity === "critical", "blocked sexual content leaked to the ordinary thread or had wrong severity");
      const teenEvidenceRead = await teen.client
        .from("message_safety_evidence")
        .select("raw_body")
        .eq("message_id", blocked.data.id);
      assertQa(!teenEvidenceRead.error && teenEvidenceRead.data.length === 0, "recipient could read restricted raw sexual evidence");
      const incident = await serviceClient
        .from("safety_incidents")
        .select("category,severity,priority")
        .eq("subject_user_id", adult.id)
        .eq("application_id", application.id)
        .eq("category", "sexual_conduct")
        .single();
      assertQa(incident.data?.severity === "critical" && incident.data?.priority === 1, "sexual safety event did not create critical human-review queue item");
      qaLog(scope, "sexual and grooming language is blocked, raw content is isolated, and critical review is created");
    },
  );
}

async function runIncidentIsolation(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "reporter", role: "teen" },
      { key: "subject", role: "adult" },
      { key: "outsider", role: "teen" },
      { key: "unprivilegedAdmin", role: "admin" },
    ],
    async ({ reporter, subject, outsider, unprivilegedAdmin }) => {
      const report = expectRpc(
        await reporter.client.rpc("submit_safety_report", {
          p_target_user_id: subject.id,
          p_target_job_id: null,
          p_target_message_id: null,
          p_target_review_id: null,
          p_application_id: null,
          p_category: "stalking",
          p_severity: "high",
          p_immediate_danger: false,
          p_details: "Repeated unwanted contact continued after a clear request to stop.",
          p_occurred_at: null,
          p_location_type: "online",
          p_desired_outcome: "Stop contact and review account restrictions.",
          p_confidential_safety_feedback: true,
        }),
        "isolated incident report",
      );
      const outsiderCases = await outsider.client.rpc("get_my_incident_cases");
      assertQa(!outsiderCases.error && !outsiderCases.data.some((item) => item.incident_id === report.incident_id), "unrelated user saw another incident case");
      const rawOutsider = await outsider.client.from("safety_incidents").select("id").eq("id", report.incident_id);
      assertQa(!rawOutsider.error && rawOutsider.data.length === 0, "unrelated user read raw incident row");
      const adminRows = await unprivilegedAdmin.client.from("safety_incidents").select("id").eq("id", report.incident_id);
      assertQa(!adminRows.error && adminRows.data.length === 0, "unprivileged admin bypassed specialized incident role");
      const reporterCases = await reporter.client.rpc("get_my_incident_cases");
      assertQa(reporterCases.data.some((item) => item.incident_id === report.incident_id), "reporter could not see approved case status");
      qaLog(scope, "incident case rows are isolated from unrelated users and unprivileged admins");
    },
  );
}

async function runEvidencePreservation(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "reporter", role: "teen" },
      { key: "subject", role: "adult" },
      { key: "incidentManager", role: "admin" },
    ],
    async ({ reporter, subject, incidentManager }) => {
      await serviceClient.from("admin_role_assignments").insert({
        user_id: incidentManager.id,
        role: "incident_manager",
        grant_reason: "Isolated QA incident manager for preservation testing.",
      });
      const report = expectRpc(
        await reporter.client.rpc("submit_safety_report", {
          p_target_user_id: subject.id,
          p_target_job_id: null,
          p_target_message_id: null,
          p_target_review_id: null,
          p_application_id: null,
          p_category: "threats",
          p_severity: "critical",
          p_immediate_danger: true,
          p_details: "A direct threat was made and supporting image evidence is available.",
          p_occurred_at: null,
          p_location_type: "online",
          p_desired_outcome: "Preserve evidence and triage immediately.",
          p_confidential_safety_feedback: true,
        }),
        "critical preservation report",
      );
      const evidence = await uploadIncidentEvidence(reporter, report.incident_id, "threat_screenshot");
      await reporter.client.storage.from("incident-evidence").remove([evidence.path]);
      const preservedObject = await serviceClient.storage.from("incident-evidence").download(evidence.path);
      assertQa(!preservedObject.error, "reporter deleted registered preserved evidence");

      const manifest = await incidentManager.client.rpc("get_incident_evidence_manifest", {
        p_incident_id: report.incident_id,
      });
      assertQa(!manifest.error && manifest.data.length === 1 && manifest.data[0].preserved === true, "incident manager did not receive preserved metadata manifest");
      assertQa(!JSON.stringify(manifest.data).includes(evidence.path), "incident manifest leaked storage path before access grant");
      const access = expectRpc(
        await incidentManager.client.rpc("authorize_incident_evidence_access", {
          p_evidence_id: evidence.evidenceId,
          p_reason: "Triage critical threat evidence for isolated preservation QA.",
        }),
        "authorize incident evidence access",
      );
      assertQa(access.storage_path === evidence.path, "reasoned incident evidence grant returned wrong path");
      expectRpc(
        await incidentManager.client.rpc("place_incident_preservation_hold", {
          p_incident_id: report.incident_id,
          p_legal_basis: "Internal safety preservation pending trained legal review and applicable process.",
          p_scope: "Preserve the report, uploaded screenshot, related notifications, and incident timeline.",
          p_expires_at: new Date(Date.now() + 30 * 86400000).toISOString(),
        }),
        "place incident preservation hold",
      );
      const row = await serviceClient
        .from("incident_evidence")
        .select("preserved_until,retention_delete_at")
        .eq("id", evidence.evidenceId)
        .single();
      assertQa(new Date(row.data.preserved_until) > new Date(), "preservation hold did not extend evidence preservation");
      qaLog(scope, "serious evidence is registered, cannot be user-deleted, and requires logged reviewer access");
    },
  );
}

async function runVerificationExpiration(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "expiredAdult", role: "adult", identityStatus: "verification_expired" },
      { key: "expiredTeen", role: "teen", identityStatus: "verification_expired" },
      { key: "verifiedAdult", role: "adult" },
    ],
    async ({ expiredAdult, expiredTeen, verifiedAdult }) => {
      const publish = await saveJob(expiredAdult.client);
      assertQa(["poster_verification_required", "identity_verification_required"].includes(publish.result?.code), "expired adult published a new job");
      const job = await saveJob(verifiedAdult.client);
      const eligibility = await expiredTeen.client.rpc("get_job_application_eligibility", { p_job_id: job.result.job.id });
      assertQa(eligibility.data?.code === "applicant_verification_required", "expired teen applied to a new job");
      const status = await expiredTeen.client.rpc("get_my_identity_verification");
      const appeal = expectRpc(
        await expiredTeen.client.rpc("submit_identity_verification_appeal", {
          p_verification_id: status.data.id,
          p_reason: "The expiration should be reviewed because updated supporting evidence is available now.",
        }),
        "expired verification appeal",
      );
      assertQa(appeal.status === "pending", "expiration appeal did not enter pending state");
      const afterAppeal = await expiredTeen.client.rpc("get_job_application_eligibility", { p_job_id: job.result.job.id });
      assertQa(afterAppeal.data?.code === "applicant_verification_required", "appeal automatically restored marketplace access");
      qaLog(scope, "expired verification blocks new marketplace actions and appeals do not auto-restore access");
    },
  );
}

async function runAccountSharing(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "user", role: "teen" },
      { key: "outsider", role: "adult" },
    ],
    async ({ user, outsider }) => {
      const sessions = await user.client.rpc("get_my_active_sessions");
      assertQa(!sessions.error && sessions.data.length >= 1, "signed-in user could not list privacy-safe active session references");
      const current = sessions.data.find((item) => item.is_current) ?? sessions.data[0];
      const concern = expectRpc(
        await user.client.rpc("report_account_security_concern", {
          p_event_type: "unrecognized_session",
          p_session_reference: current.session_reference,
          p_details: "The user does not recognize this active session reference.",
        }),
        "report unrecognized session",
      );
      const own = await user.client.from("account_security_events").select("id,event_type").eq("id", concern.event_id);
      assertQa(own.data?.length === 1, "user cannot see own account security event");
      const other = await outsider.client.from("account_security_events").select("id").eq("id", concern.event_id);
      assertQa(!other.error && other.data.length === 0, "outsider saw another user's account security event");
      qaLog(scope, "privacy-safe session review and isolated account-sharing reports work without exposing auth tokens");
    },
  );
}

async function runSafetyCancellation(scope) {
  await withMutualUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const { application } = await createAcceptedApplication(teen, adult, {
        title: "QA Safety Cancellation Test",
      });
      const result = expectRpc(
        await teen.client.rpc("submit_safety_cancellation", {
          p_application_id: application.id,
          p_reason: "unsafe_condition",
          p_details: "Unexpected unsafe equipment and people were present at the job location.",
        }),
        "safety cancellation",
      );
      assertQa(result.safety_related === true && result.reputation_penalty_applied === false && result.incident_id, "safety cancellation applied reputation penalty or skipped incident");
      const cancellation = await teen.client
        .from("safety_cancellations")
        .select("is_safety_related,reputation_penalty_applied,incident_id")
        .eq("id", result.cancellation_id)
        .single();
      assertQa(cancellation.data?.is_safety_related === true && cancellation.data?.reputation_penalty_applied === false, "stored cancellation contradicted no-retaliation response");
      const applicationRow = await serviceClient.from("applications").select("status").eq("id", application.id).single();
      assertQa(applicationRow.data?.status === "disputed", "safety cancellation did not pause the active workflow");
      qaLog(scope, "safety cancellation pauses the workflow, creates an incident, and applies no automatic reputation penalty");
    },
  );
}

const suites = {
  "qa-mutual-verification": runMutualVerification,
  "qa-teen-school-id-isolation": runTeenSchoolIsolation,
  "qa-teen-verification-alternatives": runTeenAlternatives,
  "qa-adult-id-isolation": runAdultIDIsolation,
  "qa-address-privacy": runAddressPrivacy,
  "qa-verification-forgery": runVerificationForgery,
  "qa-guardian-remains-optional": runGuardianOptional,
  "qa-safety-circle-permissions": runSafetyCircle,
  "qa-location-release-stages": runLocationStages,
  "qa-arrival-handshake": runArrivalHandshake,
  "qa-person-mismatch-report": runPersonMismatch,
  "qa-mutual-reporting": runMutualReporting,
  "qa-harassment-controls": runHarassmentControls,
  "qa-sexual-safety-controls": runSexualSafety,
  "qa-incident-case-isolation": runIncidentIsolation,
  "qa-evidence-preservation": runEvidencePreservation,
  "qa-verification-expiration": runVerificationExpiration,
  "qa-account-sharing": runAccountSharing,
  "qa-safety-cancellation": runSafetyCancellation,
};

export async function runMutualTrustSuite(name) {
  const suite = suites[name];
  if (!suite) throw new Error(`Unknown mutual-trust QA suite: ${name}`);
  await suite(name);
}
