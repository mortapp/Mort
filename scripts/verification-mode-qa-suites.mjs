import { randomBytes, randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  saveJob,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";
import {
  signWebhookBody,
  validateWebhookEnvelope,
} from "../supabase/functions/identity-verification-webhook/contract.mjs";

const rejectionProbe = Buffer.from(
  "MORT synthetic QA rejection probe. This is not an identity document.",
  "utf8",
);

async function hostedMode() {
  return withDatabase(async (database) => {
    const result = await database.query(
      "select mode, provider_configuration_present from private.identity_verification_control where singleton",
    );
    return result.rows[0];
  });
}

async function setHostedMode(mode) {
  await withDatabase((database) =>
    database.query(
      "update private.identity_verification_control set mode = $1, updated_at = now() where singleton",
      [mode],
    ),
  );
}

async function withSandboxMode(run) {
  const original = await hostedMode();
  assertQa(original.mode === "disabled", "sandbox QA did not start from hosted disabled mode");
  await setHostedMode("sandbox");
  try {
    await run();
  } finally {
    await setHostedMode("disabled");
  }
  const restored = await hostedMode();
  assertQa(restored.mode === "disabled", "sandbox QA did not restore hosted disabled mode");
}

async function runDisabled(scope) {
  const mode = await hostedMode();
  assertQa(mode.mode === "disabled", "hosted identity-verification mode is not disabled");
  await withQaUsers(
    scope,
    [{ key: "ordinary", role: "adult", identityVerified: false, isTest: false }],
    async ({ ordinary }) => {
      const status = await ordinary.client.rpc("get_my_identity_verification");
      assertQa(
        !status.error && status.data?.verification_mode === "disabled" && status.data?.submissions_enabled === false,
        "ordinary status did not report disabled submissions",
      );

      const start = await ordinary.client.rpc("start_identity_verification", {
        p_evidence_route: "government_id",
        p_attested: true,
        p_exception_reason: null,
      });
      assertQa(start.data?.code === "identity_verification_disabled", "ordinary user started verification while disabled");

      const path = `production/${ordinary.id}/${randomUUID()}.jpg`;
      const upload = await ordinary.client.storage
        .from("identity-evidence")
        .upload(path, rejectionProbe, { contentType: "image/jpeg", upsert: false });
      assertQa(upload.error, "ordinary user uploaded identity evidence while disabled");

      const insert = await ordinary.client.from("identity_verifications").insert({
        user_id: ordinary.id,
        account_role: "adult",
        evidence_route: "government_id",
        provider: "forged",
        provider_reference: `forged-${randomUUID()}`,
        environment: "production",
        decision_source: "provider_webhook",
        status: "verified",
        verification_level: 4,
        age_band: "adult_18_plus",
        verified_at: new Date().toISOString(),
      });
      assertQa(insert.error, "ordinary user inserted a verification record directly");

      const profileUpdate = await ordinary.client
        .from("profiles")
        .update({ verification_status: "approved" })
        .eq("id", ordinary.id)
        .select("id");
      assertQa(
        profileUpdate.error || profileUpdate.data.length === 0,
        "ordinary user set their profile verification status",
      );

      const modeEdit = await ordinary.client
        .schema("private")
        .from("identity_verification_control")
        .update({ mode: "production" })
        .eq("singleton", true);
      assertQa(modeEdit.error, "ordinary user changed the server verification mode");
      qaLog(scope, "disabled mode blocks starts, Storage uploads, direct records, status forgery, and mode changes");
    },
  );
}

async function runSandbox(scope) {
  await withSandboxMode(async () => {
    await withQaUsers(
      scope,
      [
        { key: "qaTeen", role: "teen", identityVerified: false, isTest: true },
        { key: "ordinaryTeen", role: "teen", identityVerified: false, isTest: false },
      ],
      async ({ qaTeen, ordinaryTeen }) => {
        const ordinary = await ordinaryTeen.client.rpc("start_identity_verification", {
          p_evidence_route: "sandbox_simulation",
          p_attested: true,
          p_exception_reason: null,
        });
        assertQa(ordinary.data?.code === "sandbox_qa_account_required", "non-QA user started sandbox verification");

        const session = await qaTeen.client.rpc("start_identity_verification", {
          p_evidence_route: "sandbox_simulation",
          p_attested: true,
          p_exception_reason: null,
        });
        assertQa(
          !session.error && session.data?.ok === true && session.data?.environment === "sandbox",
          "QA account did not receive a sandbox session",
        );
        assertQa(
          session.data?.test_mode === true && session.data?.documents_allowed === false && session.data?.production_eligible === false,
          "sandbox session omitted test-only or no-document controls",
        );

        const upload = await qaTeen.client.storage
          .from("identity-evidence")
          .upload(
            `sandbox/${qaTeen.id}/${session.data.id}/${randomUUID()}.jpg`,
            rejectionProbe,
            { contentType: "image/jpeg", upsert: false },
          );
        assertQa(upload.error, "QA sandbox account uploaded an identity document probe");

        const record = await serviceClient
          .from("identity_verifications")
          .select("environment,provider,decision_source,status,verification_level,risk_flags")
          .eq("id", session.data.id)
          .single();
        assertQa(
          record.data?.environment === "sandbox" &&
            record.data?.decision_source === "sandbox_simulation" &&
            record.data?.verification_level === 0 &&
            record.data?.risk_flags?.documents_collected === false,
          "sandbox record was not isolated and explicitly simulated",
        );
        qaLog(scope, "sandbox is QA-only, visibly simulated, document-free, and never production eligible");
      },
    );
  });
}

async function runEnvironmentIsolation(scope) {
  await withQaUsers(
    scope,
    [
      { key: "qaAdult", role: "adult", isTest: true },
      { key: "qaTeen", role: "teen", isTest: true },
      { key: "ordinaryTeen", role: "teen", identityVerified: false, isTest: false },
    ],
    async ({ qaAdult, qaTeen, ordinaryTeen }) => {
      const qaStatus = await qaAdult.client.rpc("get_my_identity_verification");
      assertQa(
        qaStatus.data?.environment === "sandbox" && qaStatus.data?.production_verified === false,
        "sandbox identity was represented as production verified",
      );

      const testJob = await saveJob(qaAdult.client, { title: "QA Isolated Sandbox Job" });
      const storedJob = await serviceClient
        .from("jobs")
        .select("is_test")
        .eq("id", testJob.result.job.id)
        .single();
      assertQa(
        testJob.result?.ok === true && storedJob.data?.is_test === true,
        "QA job was not isolated as test data",
      );
      const ordinaryFeed = await ordinaryTeen.client.from("jobs").select("id").eq("id", testJob.result.job.id);
      assertQa(!ordinaryFeed.error && ordinaryFeed.data.length === 0, "ordinary user saw a sandbox QA job");

      const badge = await ordinaryTeen.client.rpc("get_public_trust_badges", { p_user_id: qaAdult.id });
      assertQa(badge.data?.code === "profile_not_found", "production caller could probe a sandbox QA profile");

      const guardianPolicy = await qaTeen.client.rpc("get_guardian_policy_for_user");
      assertQa(
        guardianPolicy.data?.guardian_link_required === false &&
          guardianPolicy.data?.guardian_approval_required_for_application === false,
        "Guardian Mode became mandatory through verification isolation",
      );
      qaLog(scope, "sandbox identities and jobs stay out of production views while Guardian Mode remains optional");
    },
  );
}

async function runStorageLockdown(scope) {
  await withQaUsers(
    scope,
    [
      { key: "owner", role: "adult", identityVerified: false },
      { key: "guardian", role: "guardian", identityVerified: false },
      { key: "admin", role: "admin" },
    ],
    async ({ owner, guardian, admin }) => {
      const paths = [
        `sandbox/${owner.id}/${randomUUID()}.jpg`,
        `production/${owner.id}/${randomUUID()}.jpg`,
        `${owner.id}/${randomUUID()}.jpg`,
      ];
      for (const path of paths) {
        const upload = await owner.client.storage
          .from("identity-evidence")
          .upload(path, rejectionProbe, { contentType: "image/jpeg", upsert: false });
        assertQa(upload.error, `identity upload path was accepted: ${path.split("/")[0]}`);
      }

      const copied = await owner.client.storage
        .from("identity-evidence")
        .copy(paths[0], paths[1]);
      assertQa(copied.error, "client copied a sandbox path into production scope");
      const deletionProbePath = `sandbox/${owner.id}/${randomUUID()}-delete-probe.jpg`;
      const seededDeletionProbe = await serviceClient.storage
        .from("identity-evidence")
        .upload(deletionProbePath, rejectionProbe, {
          contentType: "image/jpeg",
          upsert: false,
        });
      assertQa(!seededDeletionProbe.error, "service could not seed the deletion probe");
      try {
        await owner.client.storage
          .from("identity-evidence")
          .remove([deletionProbePath]);
        const retainedProbe = await serviceClient.storage
          .from("identity-evidence")
          .download(deletionProbePath);
        assertQa(!retainedProbe.error, "client received identity-object deletion authority");
      } finally {
        await serviceClient.storage
          .from("identity-evidence")
          .remove([deletionProbePath]);
      }

      for (const observer of [guardian, admin]) {
        const tableRows = await observer.client
          .from("identity_verification_evidence")
          .select("id,storage_path")
          .eq("user_id", owner.id);
        assertQa(
          tableRows.error || tableRows.data.length === 0,
          `${observer.role} read raw identity metadata`,
        );
        const download = await observer.client.storage.from("identity-evidence").download(paths[1]);
        assertQa(download.error, `${observer.role} downloaded identity evidence`);
      }

      const buckets = await owner.client.storage.listBuckets();
      assertQa(
        buckets.error || !buckets.data?.some((bucket) => bucket.id === "identity-evidence"),
        "ordinary user listed the private identity bucket",
      );
      qaLog(scope, "identity Storage denies upload, copy, delete, bucket listing, guardian access, and ordinary-admin access");
    },
  );
}

async function runClientForgery(scope) {
  await withQaUsers(
    scope,
    [
      { key: "adult", role: "adult", identityVerified: false },
      { key: "admin", role: "admin" },
    ],
    async ({ adult, admin }) => {
      const providerResult = await adult.client.rpc("process_identity_verification_provider_result", providerResultParams(adult.id));
      assertQa(providerResult.error, "ordinary client invoked the service-only provider-result RPC");

      const review = await admin.client.rpc("admin_review_identity_verification", {
        p_verification_id: randomUUID(),
        p_action: "approve",
        p_decision_code: "qa_forgery",
        p_identity_match_result: "passed",
        p_liveness_result: "passed",
        p_email_result: "passed",
        p_phone_result: "passed",
        p_address_result: "passed",
        p_expires_at: new Date(Date.now() + 86400000).toISOString(),
      });
      assertQa(
        review.data?.code === "production_identity_reviewer_required",
        "ordinary admin received production identity approval authority",
      );

      const directUpdate = await adult.client
        .from("identity_verifications")
        .update({ environment: "production", status: "verified", verification_level: 4 })
        .eq("user_id", adult.id)
        .select("id");
      assertQa(directUpdate.error || directUpdate.data.length === 0, "client altered protected verification fields");

      const profile = await adult.client.from("profiles").select("verification_status").eq("id", adult.id).single();
      assertQa(profile.data?.verification_status !== "approved", "forgery attempt changed public verification status");
      qaLog(scope, "clients and ordinary admins cannot forge environment, provider result, status, level, or approval");
    },
  );
}

async function runWebhookReplay(scope) {
  const secret = randomBytes(32).toString("hex");
  const eventId = `evt-${randomUUID()}`;
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const body = JSON.stringify({
    event_id: eventId,
    provider: "qa-provider",
    environment: "production",
    provider_reference: `inquiry-${randomUUID()}`,
    account_id: randomUUID(),
    result_status: "approved",
    age_band: "adult_18_plus",
    verification_level: 2,
    expires_at: new Date(Date.now() + 30 * 86400000).toISOString(),
  });
  const signature = await signWebhookBody({ rawBody: body, eventId, timestamp, secret });
  const valid = await validateWebhookEnvelope({
    rawBody: body,
    headers: {
      "x-mort-event-id": eventId,
      "x-mort-timestamp": timestamp,
      "x-mort-signature": `v1=${signature}`,
    },
    secret,
    expectedProvider: "qa-provider",
  });
  assertQa(valid.ok, "valid signed webhook contract was rejected");

  const unsigned = await validateWebhookEnvelope({
    rawBody: body,
    headers: { "x-mort-event-id": eventId, "x-mort-timestamp": timestamp },
    secret,
    expectedProvider: "qa-provider",
  });
  assertQa(!unsigned.ok && unsigned.code === "signature_missing", "unsigned webhook was accepted");

  const sandboxBody = body.replace('"environment":"production"', '"environment":"sandbox"');
  const sandboxSignature = await signWebhookBody({ rawBody: sandboxBody, eventId, timestamp, secret });
  const sandbox = await validateWebhookEnvelope({
    rawBody: sandboxBody,
    headers: {
      "x-mort-event-id": eventId,
      "x-mort-timestamp": timestamp,
      "x-mort-signature": sandboxSignature,
    },
    secret,
    expectedProvider: "qa-provider",
  });
  assertQa(
    !sandbox.ok && sandbox.code === "provider_environment_mismatch",
    "sandbox webhook passed the production contract",
  );

  await withDatabase(async (database) => {
    await database.query("begin");
    try {
      const params = [
        "qa-provider",
        eventId,
        "sandbox",
        `inquiry-${randomUUID()}`,
        new Date(),
        "A".repeat(64),
      ];
      const statement = `
        insert into private.identity_verification_webhook_events (
          provider, event_id, environment, provider_reference,
          event_timestamp, signature_verified, payload_sha256,
          result_status, processing_status
        ) values ($1, $2, $3, $4, $5, true, $6, 'rejected', 'rejected')
      `;
      await database.query(statement, params);
      let replayRejected = false;
      try {
        await database.query(statement, params);
      } catch (error) {
        replayRejected = error.code === "23505";
      }
      assertQa(replayRejected, "duplicate provider event ID bypassed replay protection");
    } finally {
      await database.query("rollback");
    }
  });
  qaLog(scope, "signed contract validates HMAC and timestamp, rejects unsigned/sandbox events, and enforces replay uniqueness");
}

async function runProductionFailClosed(scope) {
  const mode = await hostedMode();
  assertQa(mode.mode === "disabled" && mode.provider_configuration_present === false, "hosted provider unexpectedly became ready");

  await withDatabase(async (database) => {
    await database.query("begin");
    let rejected = false;
    try {
      await database.query(
        "update private.identity_verification_control set mode = 'production' where singleton",
      );
    } catch (error) {
      rejected = error.code === "23514";
    } finally {
      await database.query("rollback");
    }
    assertQa(rejected, "production mode enabled without readiness configuration");
  });

  await withQaUsers(
    scope,
    [{ key: "adult", role: "adult", identityVerified: false, isTest: false }],
    async ({ adult }) => {
      const providerResult = await serviceClient.rpc(
        "process_identity_verification_provider_result",
        providerResultParams(adult.id),
      );
      assertQa(
        !providerResult.error && providerResult.data?.code === "production_verification_not_ready",
        "service-side provider result did not fail closed without configuration",
      );

      const profile = await serviceClient
        .from("profiles")
        .select("verification_status")
        .eq("id", adult.id)
        .single();
      assertQa(profile.data?.verification_status !== "approved", "failed provider result marked user approved");

      const guardianPolicy = await adult.client.rpc("get_guardian_policy_for_user");
      assertQa(guardianPolicy.data?.guardian_link_required === false, "production fail-closed mode made Guardian Mode mandatory");
      qaLog(scope, "missing provider configuration blocks production mode and provider decisions without changing Guardian Mode");
    },
  );

  const restored = await hostedMode();
  assertQa(restored.mode === "disabled", "hosted mode changed during production fail-closed QA");
}

function providerResultParams(userId) {
  return {
    p_event_id: `qa-${randomUUID()}`,
    p_provider: "unconfigured-provider",
    p_environment: "production",
    p_provider_reference: `qa-${randomUUID()}`,
    p_user_id: userId,
    p_result_status: "approved",
    p_age_band: "adult_18_plus",
    p_verification_level: 2,
    p_expires_at: new Date(Date.now() + 30 * 86400000).toISOString(),
    p_event_timestamp: new Date().toISOString(),
    p_payload_sha256: "A".repeat(64),
    p_signature_verified: true,
  };
}

const suites = {
  "qa-verification-mode-disabled": runDisabled,
  "qa-verification-mode-sandbox": runSandbox,
  "qa-verification-environment-isolation": runEnvironmentIsolation,
  "qa-verification-storage-lockdown": runStorageLockdown,
  "qa-verification-client-forgery": runClientForgery,
  "qa-verification-webhook-replay": runWebhookReplay,
  "qa-verification-production-fail-closed": runProductionFailClosed,
};

export async function runVerificationModeSuite(name) {
  const suite = suites[name];
  if (!suite) throw new Error(`Unknown verification-mode QA suite: ${name}`);
  await suite(name);
}
