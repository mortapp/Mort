import { createHash, randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  serviceClient,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "privacy-observability";

function expectOk(result, message) {
  assertQa(!result.error, `${message}: ${result.error?.message ?? "RPC error"}`);
  assertQa(result.data?.ok === true, `${message}: ${result.data?.code ?? "not ok"}`);
  return result.data;
}

function eventParams(requestId = randomUUID()) {
  return {
    p_event_name: "screen_view",
    p_surface: "jobs",
    p_outcome: "opened",
    p_platform: "android",
    p_app_version: "0.9.11+101",
    p_release_stage: "closed_test",
    p_client_request_id: requestId,
  };
}

await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
  const consentVersion = "analytics-2026-07";
  const safeCode = "repository.network_timeout";
  const operationalType = "api_failure";

  const defaults = expectOk(
    await teen.client.rpc("get_my_analytics_preferences"),
    "default analytics preference failed",
  );
  assertQa(
    defaults.product_analytics_opt_in === false && defaults.consent_version == null,
    "product analytics did not default to opt-out",
  );
  const optedOutEvent = expectOk(
    await teen.client.rpc("record_my_product_analytics", eventParams()),
    "opt-out analytics call failed",
  );
  assertQa(
    optedOutEvent.recorded === false && optedOutEvent.code === "analytics_opt_out",
    "opt-out user produced a product event",
  );
  qaLog(scope, "product analytics defaults off and opt-out writes no event");

  const invalidConsent = await teen.client.rpc("update_my_analytics_preferences", {
    p_product_analytics_opt_in: true,
    p_consent_version: "free-form-consent",
  });
  assertQa(
    !invalidConsent.error && invalidConsent.data?.code === "invalid_analytics_consent",
    "invalid consent version was accepted",
  );
  expectOk(
    await teen.client.rpc("update_my_analytics_preferences", {
      p_product_analytics_opt_in: true,
      p_consent_version: consentVersion,
    }),
    "analytics opt-in failed",
  );
  const preference = expectOk(
    await teen.client.rpc("get_my_analytics_preferences"),
    "opted-in preference read failed",
  );
  assertQa(
    preference.product_analytics_opt_in === true &&
      preference.consent_version === consentVersion &&
      Boolean(preference.consented_at),
    "analytics consent was not timestamped and versioned",
  );
  qaLog(scope, "analytics opt-in is explicit, versioned, and timestamped");

  const eventRequest = randomUUID();
  const recorded = expectOk(
    await teen.client.rpc("record_my_product_analytics", eventParams(eventRequest)),
    "valid analytics event failed",
  );
  const replayed = expectOk(
    await teen.client.rpc("record_my_product_analytics", eventParams(eventRequest)),
    "analytics event replay failed",
  );
  const substituted = await teen.client.rpc("record_my_product_analytics", {
    ...eventParams(eventRequest),
    p_surface: "messages",
  });
  const invalidEvent = await teen.client.rpc("record_my_product_analytics", {
    ...eventParams(),
    p_event_name: "exact_location_viewed",
  });
  assertQa(
    recorded.recorded === true &&
      replayed.replayed === true &&
      substituted.data?.code === "analytics_request_id_reused" &&
      invalidEvent.data?.code === "invalid_analytics_event",
    "analytics idempotency, payload binding, or taxonomy failed",
  );
  qaLog(scope, "product events are idempotent, payload-bound, and fixed-taxonomy");

  const correlationId = randomUUID();
  const operationalRequest = randomUUID();
  const operationalParams = {
    p_event_type: operationalType,
    p_safe_code: safeCode,
    p_correlation_id: correlationId,
    p_platform: "android",
    p_app_version: "0.9.11+101",
    p_release_stage: "closed_test",
    p_client_request_id: operationalRequest,
  };
  const operational = expectOk(
    await teen.client.rpc("record_my_client_operational_event", operationalParams),
    "operational event failed",
  );
  const operationalReplay = expectOk(
    await teen.client.rpc("record_my_client_operational_event", operationalParams),
    "operational event replay failed",
  );
  const operationalSubstitution = await teen.client.rpc(
    "record_my_client_operational_event",
    { ...operationalParams, p_safe_code: "repository.other_failure" },
  );
  assertQa(
    operational.recorded === true &&
      operationalReplay.replayed === true &&
      operationalSubstitution.data?.code === "operational_request_id_reused",
    "operational event replay or payload binding failed",
  );
  qaLog(scope, "operational events are content-free, replay-safe, and payload-bound");

  const directPreferenceRead = await teen.client
    .from("analytics_preferences")
    .select("user_id")
    .limit(1);
  const adminDashboard = await teen.client.rpc("get_admin_observability_dashboard", {
    p_window_hours: 24,
  });
  const purgeAttempt = await teen.client.rpc("service_purge_observability_data");
  assertQa(
    Boolean(directPreferenceRead.error) &&
      !adminDashboard.error &&
      adminDashboard.data?.code === "operational_review_role_required" &&
      Boolean(purgeAttempt.error),
    "RLS, admin dashboard authorization, or retention worker isolation failed",
  );

  await withDatabase(async (database) => {
    const analyticsRows = await database.query(
      `select event_name, surface, outcome, platform, app_version, release_stage
       from private.product_analytics_events where user_id = $1`,
      [teen.id],
    );
    const operationalRows = await database.query(
      `select event_type, safe_code, correlation_id, platform, app_version, release_stage
       from private.client_operational_events where user_id = $1`,
      [teen.id],
    );
    const columns = await database.query(
      `select table_name, column_name from information_schema.columns
       where table_schema = 'private'
         and table_name in ('product_analytics_events', 'client_operational_events')`,
    );
    const names = columns.rows.map((row) => row.column_name);
    const prohibited = [
      "message", "body", "content", "address", "location", "pin",
      "email", "phone", "ip_address", "advertising_id", "evidence",
    ];
    assertQa(
      analyticsRows.rowCount === 1 &&
        operationalRows.rowCount === 1 &&
        operationalRows.rows[0].correlation_id === correlationId &&
        prohibited.every((name) => !names.includes(name)),
      "raw observability rows contain duplicates or a prohibited data column",
    );
    const analyticsHash = createHash("sha256")
      .update(["screen_view", "jobs", "opened", "android", "0.9.11+101", "closed_test"].join("|"))
      .digest("hex");
    const storedHash = await database.query(
      `select payload_sha256 from private.product_analytics_events
       where user_id = $1 and client_request_id = $2`,
      [teen.id, eventRequest],
    );
    assertQa(
      storedHash.rows[0]?.payload_sha256 === analyticsHash,
      "analytics payload binding hash did not match the strict payload",
    );
  });
  qaLog(scope, "raw rows are service-only and schemas contain no sensitive-content fields");

  expectOk(
    await teen.client.rpc("update_my_analytics_preferences", {
      p_product_analytics_opt_in: false,
      p_consent_version: consentVersion,
    }),
    "analytics opt-out failed",
  );
  const optedOut = expectOk(
    await teen.client.rpc("get_my_analytics_preferences"),
    "final opt-out preference failed",
  );
  assertQa(
    optedOut.product_analytics_opt_in === false &&
      optedOut.consent_version == null &&
      optedOut.consented_at == null,
    "analytics opt-out retained consent metadata",
  );
  qaLog(scope, "opt-out is immediate and clears consent metadata");
});

const runtime = expectOk(
  await serviceClient.rpc("service_get_push_runtime"),
  "push runtime verification failed",
);
assertQa(runtime.remote_push_enabled === false, "observability QA enabled remote push");
qaLog(scope, "all privacy observability checks completed without changing provider gates");
