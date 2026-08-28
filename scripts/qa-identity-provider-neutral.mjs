import { randomBytes, randomUUID } from "node:crypto";

import {
  normalizeProviderHandoff,
  safeProviderFailure,
} from "../supabase/functions/identity-verification-session/contract.mjs";
import {
  normalizeVerificationStatus,
  signWebhookBody,
  validateWebhookEnvelope,
} from "../supabase/functions/identity-verification-webhook/contract.mjs";
import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-identity-provider-neutral";
const probe = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);

const validHandoff = normalizeProviderHandoff({
  value: {
    provider: "qa-provider",
    provider_reference: `provider-${randomUUID()}`,
    status: "pending",
    handoff_url: "https://verify.example.test/session/opaque",
    handoff_expires_at: new Date(Date.now() + 10 * 60_000).toISOString(),
  },
  expectedProvider: "qa-provider",
  allowedHosts: ["verify.example.test"],
});
assertQa(validHandoff.ok, "valid short-lived provider handoff was rejected");
for (const handoffUrl of [
  "http://verify.example.test/session/opaque",
  "https://verify.example.test.evil.invalid/session/opaque",
  "https://user:password@verify.example.test/session/opaque",
]) {
  const rejected = normalizeProviderHandoff({
    value: {
      provider: "qa-provider",
      provider_reference: `provider-${randomUUID()}`,
      status: "pending",
      handoff_url: handoffUrl,
      handoff_expires_at: new Date(Date.now() + 10 * 60_000).toISOString(),
    },
    expectedProvider: "qa-provider",
    allowedHosts: ["verify.example.test"],
  });
  assertQa(!rejected.ok, `unsafe handoff was accepted: ${new URL(handoffUrl).hostname}`);
}
assertQa(normalizeVerificationStatus("approved") === "verified", "approved mapping failed");
assertQa(normalizeVerificationStatus("needs_review") === "under_review", "review mapping failed");
assertQa(safeProviderFailure(429) === "provider_unavailable", "retryable provider failure was not minimized");
qaLog(scope, "handoff validation enforces HTTPS, exact hosts, no userinfo, bounded expiry, and safe failures");

const secret = randomBytes(32).toString("hex");
const eventId = `evt-${randomUUID()}`;
const timestamp = Math.floor(Date.now() / 1000).toString();
const body = JSON.stringify({
  event_id: eventId,
  provider: "qa-provider",
  environment: "production",
  provider_reference: `provider-${randomUUID()}`,
  account_id: randomUUID(),
  result_status: "needs_input",
  failure_code: "document_unreadable",
  age_band: "adult_18_plus",
  verification_level: 0,
  delivery_attempt: 2,
  payload_version: "normalized-v1",
});
const signature = await signWebhookBody({ rawBody: body, eventId, timestamp, secret });
const envelope = await validateWebhookEnvelope({
  rawBody: body,
  headers: {
    "x-mort-event-id": eventId,
    "x-mort-timestamp": timestamp,
    "x-mort-signature": `v1=${signature}`,
  },
  secret,
  expectedProvider: "qa-provider",
});
assertQa(
  envelope.ok && envelope.normalizedStatus === "needs_input" && envelope.failureCode === "document_unreadable",
  "normalized signed webhook envelope failed",
);
qaLog(scope, "signed webhook normalizes statuses and accepts only bounded failure codes");

await withDatabase(async (database) => {
  const policy = await database.query(`
    select qual
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'storage_mort_owner_select'
  `);
  const qualification = String(policy.rows[0]?.qual ?? "");
  assertQa(
    qualification.includes("current_user_is_production_identity_reviewer") &&
      !qualification.includes("private.is_production_identity_reviewer"),
    "Storage policy bypasses the RLS-safe identity reviewer wrapper",
  );
});
qaLog(scope, "shared Storage policy uses the RLS-safe current-user reviewer wrapper");

await withQaUsers(
  scope,
  [
    { key: "adult", role: "adult", identityVerified: false, isTest: false },
    { key: "teen", role: "teen", identityVerified: false, isTest: false },
  ],
  async ({ adult, teen }) => {
    const status = await adult.client.rpc("get_my_identity_verification_v2");
    assertQa(
      !status.error && status.data?.status === "not_started" &&
        status.data?.documents_collected_by_mort === false &&
        status.data?.production_adult_only === true,
      "normalized disabled identity status was not honest",
    );
    const request = await adult.client.rpc("request_identity_verification_session_v2", {
      p_client_request_id: randomUUID(),
    });
    assertQa(request.data?.code === "production_verification_not_ready", "disabled production session did not fail closed");
    const teenRequest = await teen.client.rpc("request_identity_verification_session_v2", {
      p_client_request_id: randomUUID(),
    });
    assertQa(teenRequest.data?.code === "adult_identity_verification_required", "teen reached adult production verification");

    const path = `${adult.id}/${randomUUID()}.jpg`;
    const upload = await adult.client.storage
      .from("verification-uploads")
      .upload(path, probe, { contentType: "image/jpeg", upsert: false });
    assertQa(upload.error, "legacy direct business-document upload remained open");
    const business = await adult.client.rpc("submit_business_verification", {
      p_verification_id: randomUUID(),
      p_storage_path: path,
      p_business_name: "QA Business",
      p_business_type: "business",
      p_notes: null,
    });
    assertQa(business.data?.code === "business_verification_provider_required", "legacy business submission remained open");

    for (const table of ["identity_verification_sessions", "identity_verification_webhook_events"]) {
      const raw = await adult.client.schema("private").from(table).select("*").limit(1);
      assertQa(raw.error, `ordinary user read private ${table}`);
    }
    const forged = await adult.client.rpc("process_identity_verification_provider_event_v2", {
      p_event_id: `evt-${randomUUID()}`,
      p_provider: "qa-provider",
      p_environment: "production",
      p_provider_reference: `provider-${randomUUID()}`,
      p_user_id: adult.id,
      p_normalized_status: "verified",
      p_failure_code: null,
      p_age_band: "adult_18_plus",
      p_verification_level: 2,
      p_expires_at: new Date(Date.now() + 86400000).toISOString(),
      p_event_timestamp: new Date().toISOString(),
      p_payload_sha256: "A".repeat(64),
      p_signature_verified: true,
      p_delivery_attempt: 1,
      p_payload_version: "normalized-v1",
    });
    assertQa(forged.error, "ordinary user invoked service-only provider event processing");
    qaLog(scope, "hosted disabled mode closes adult/teen sessions, direct uploads, business submission, raw tables, and client events");
  },
);

await withQaUsers(
  scope,
  [{ key: "syntheticAdult", role: "adult", identityVerified: false, isTest: true }],
  async ({ syntheticAdult }) => withDatabase(async (database) => {
  await database.query("begin");
  try {
    const userId = syntheticAdult.id;
    const verificationId = randomUUID();
    const sessionId = randomUUID();
    const providerReference = `provider-${randomUUID()}`;
    const event = `evt-${randomUUID()}`;
    const hash = "B".repeat(64);
    await database.query(
      "select set_config('request.jwt.claims', '{\"role\":\"service_role\"}', true)",
    );
    await database.query(`
      update private.identity_verification_control set
        mode = 'production', provider_slug = 'qa-provider', provider_environment = 'production',
        provider_configuration_present = true, provider_session_configured = true,
        signed_webhook_configured = true, provider_webhook_adapter_verified = true,
        workflow_approved = true, adult_workflow_approved = true,
        retention_policy_configured = true, legal_approved = true,
        operational_ready = true, trained_reviewers_ready = true,
        privacy_notice_version = 'qa-only-v1', production_approved_at = now(),
        allowed_handoff_hosts = array['verify.example.test']::text[]
      where singleton
    `);
    await database.query(`
      insert into public.identity_verifications(
        id, user_id, account_role, evidence_route, provider, provider_reference,
        environment, decision_source, status, age_band, retention_delete_at, audit_version
      ) values (
        $2, $1, 'adult', 'government_id', 'qa-provider', $3,
        'production', 'provider_webhook', 'verification_pending', 'adult_18_plus',
        now() + interval '90 days', 'provider-neutral-qa'
      )
    `, [userId, verificationId, providerReference]);
    await database.query(`
      insert into private.identity_verification_sessions(
        id, verification_id, user_id, environment, provider, provider_reference,
        workflow_reference, status, normalized_status, expires_at
      ) values (
        $4, $2, $1, 'production', 'qa-provider', $3,
        'adult-identity-provider-v2', 'pending', 'pending', now() + interval '15 minutes'
      )
    `, [userId, verificationId, providerReference, sessionId]);

    const params = [
      event, "qa-provider", "production", providerReference, userId,
      "verified", null, "adult_18_plus", 2,
      new Date(Date.now() + 86400000), new Date(), hash, true, 1, "normalized-v1",
    ];
    const first = await database.query(
      "select public.process_identity_verification_provider_event_v2($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) result",
      params,
    );
    assertQa(first.rows[0].result?.ok === true && first.rows[0].result?.idempotent === false, "synthetic provider event failed");
    const replay = await database.query(
      "select public.process_identity_verification_provider_event_v2($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) result",
      params,
    );
    assertQa(replay.rows[0].result?.ok === true && replay.rows[0].result?.idempotent === true, "identical provider replay was not idempotent");
    const conflict = await database.query(
      "select public.process_identity_verification_provider_event_v2($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) result",
      [...params.slice(0, 11), "C".repeat(64), ...params.slice(12)],
    );
    assertQa(conflict.rows[0].result?.code === "provider_webhook_replay_conflict", "payload substitution did not fail closed");
    qaLog(scope, "synthetic production transaction proves signed service events, normalized verification, idempotency, and replay conflict");
  } finally {
    await database.query("rollback");
  }
}),
);

await withDatabase(async (database) => {
  const mode = await database.query(`
    select mode, provider_configuration_present
    from private.identity_verification_control
    where singleton
  `);
  assertQa(
    mode.rows[0]?.mode === "disabled" && mode.rows[0]?.provider_configuration_present === false,
    "hosted identity mode changed",
  );
});
console.log(`[${scope}] Identity provider-neutral QA passed.`);
