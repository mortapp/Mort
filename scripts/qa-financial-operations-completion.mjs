import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";

import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-financial-operations-completion";

await withDatabase(async (database) => {
  const controls = await database.query(`
    select * from private.stripe_runtime_controls where singleton
  `);
  const control = controls.rows[0];
  assertQa(control?.mode === "sandbox", "Stripe database mode changed from sandbox");
  for (const field of [
    "stripe_payments_enabled",
    "stripe_connected_onboarding_enabled",
    "stripe_job_funding_enabled",
    "stripe_transfers_enabled",
    "stripe_refunds_enabled",
    "stripe_live_mode_enabled",
    "live_owner_approved",
    "sandbox_provider_qa_approved",
    "provider_use_case_approved",
    "legal_financial_approved",
    "privacy_financial_approved",
    "minor_payout_flow_approved",
    "tax_reporting_approved",
    "negative_balance_plan_approved",
    "financial_retention_approved",
    "receipts_policy_approved",
    "reconciliation_schedule_approved",
    "monitoring_on_call_approved",
    "production_release_approved",
  ]) {
    assertQa(control?.[field] === false, `${field} is not fail-closed`);
  }
  assertQa(
    control?.payment_collection_strategy === "separate_charges_and_transfers" &&
      control?.capture_strategy === "automatic_capture_before_job_start" &&
      control?.transfer_release_strategy === "post_completion_human_gated",
    "financial strategy is absent or ambiguous",
  );

  const forcedRls = await database.query(`
    select relrowsecurity, relforcerowsecurity
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'private'
      and relation.relname = 'stripe_financial_incidents'
  `);
  assertQa(
    forcedRls.rows[0]?.relrowsecurity === true &&
      forcedRls.rows[0]?.relforcerowsecurity === true,
    "financial incidents do not use forced RLS",
  );

  const receiptSource = await functionSource(
    database,
    "public",
    "get_my_job_payment_receipt",
  );
  const summarySource = await functionSource(
    database,
    "public",
    "get_job_payment_summary",
  );
  const queueSource = await functionSource(
    database,
    "public",
    "get_my_payment_operations_queue",
  );
  assertQa(
    receiptSource.includes("not_tax_receipt") &&
      receiptSource.includes("not_escrow") &&
      !receiptSource.includes("provider_payment_intent_id"),
    "receipt projection is misleading or leaks provider references",
  );
  assertQa(
    summarySource.includes("contract_party_required"),
    "receipt summary is not participant-bound",
  );
  assertQa(
    queueSource.includes("stripe_financial_incidents") &&
      queueSource.includes("has_stripe_financial_role"),
    "financial incidents are absent from the restricted operations queue",
  );
});
qaLog(scope, "hosted strategies, live gates, receipt boundary, forced RLS, and restricted incident queue are present");

await withQaUsers(
  scope,
  [{ key: "adult", role: "adult", identityVerified: false, isTest: true }],
  async ({ adult }) => {
    const readiness = await adult.client.rpc("get_stripe_live_readiness");
    assertQa(
      !readiness.error && readiness.data?.ready === false &&
        readiness.data?.production_release_approved === false &&
        readiness.data?.minor_payout_flow_approved === false,
      "client readiness did not report the external production gates honestly",
    );
    const forgedIncident = await adult.client.rpc(
      "stripe_server_record_financial_incident",
      {
        p_request_id: randomUUID(),
        p_environment: "test",
        p_category: "negative_balance",
        p_severity: "high",
        p_subject_type: "platform",
        p_subject_id: null,
        p_amount_cents: 100,
        p_currency_code: "USD",
        p_safe_code: "forged_incident",
      },
    );
    assertQa(forgedIncident.error, "ordinary user recorded a financial incident");
    const rawIncident = await adult.client
      .schema("private")
      .from("stripe_financial_incidents")
      .select("*")
      .limit(1);
    assertQa(rawIncident.error, "ordinary user read private financial incidents");

    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query(
          "select set_config('request.jwt.claims', '{\"role\":\"service_role\"}', true)",
        );
        const providerAccountId = `acct_${randomUUID().replaceAll("-", "")}`;
        await database.query(`
          insert into private.stripe_connected_accounts(
            user_id, environment, provider_account_id
          ) values ($1, 'test', $2)
        `, [adult.id, providerAccountId]);

        const retention = await database.query(`
          select public.service_check_account_deletion_financial_retention($1) result
        `, [adult.id]);
        assertQa(
          retention.rows[0]?.result?.ok === true &&
            retention.rows[0]?.result?.retention_review_required === true,
          "financial records did not stop ordinary account deletion",
        );

        const requestId = randomUUID();
        const subjectId = randomUUID();
        const params = [
          requestId,
          "test",
          "negative_balance",
          "high",
          "platform",
          subjectId,
          1250,
          "USD",
          "platform_balance_negative",
        ];
        const statement = `
          select public.stripe_server_record_financial_incident(
            $1,$2,$3,$4,$5,$6,$7,$8,$9
          ) result
        `;
        const first = await database.query(statement, params);
        const replay = await database.query(statement, params);
        const conflict = await database.query(statement, [
          ...params.slice(0, 8),
          "platform_balance_changed",
        ]);
        assertQa(
          first.rows[0]?.result?.ok === true &&
            first.rows[0]?.result?.idempotent === false,
          "service financial incident was not recorded",
        );
        assertQa(
          replay.rows[0]?.result?.ok === true &&
            replay.rows[0]?.result?.idempotent === true,
          "exact financial incident replay was not idempotent",
        );
        assertQa(
          conflict.rows[0]?.result?.code === "financial_incident_replay_conflict",
          "financial incident payload substitution did not fail closed",
        );

        let blocked = false;
        try {
          await database.query(`
            select public.stripe_server_update_controls(
              true, false, true, false, false, 'synthetic enable rejection'
            )
          `);
        } catch (error) {
          blocked = String(error?.message).includes("stripe_sandbox_qa_not_approved");
        }
        assertQa(blocked, "sandbox provider operations enabled without approval");
        qaLog(scope, "financial retention, incident idempotency, replay conflict, and sandbox activation denial passed");
      } finally {
        await database.query("rollback");
      }
    });
  },
);

const deletionWorker = await readFile(
  new URL("../supabase/functions/account-deletion-processor/index.ts", import.meta.url),
  "utf8",
);
const retentionCheckPosition = deletionWorker.indexOf(
  '"service_check_account_deletion_financial_retention"',
);
const storageRemovalPosition = deletionWorker.indexOf(
  "removedStorageObjects = await removeOwnedStorage",
);
assertQa(
  retentionCheckPosition >= 0 &&
    storageRemovalPosition >= 0 &&
    retentionCheckPosition < storageRemovalPosition,
  "deletion worker removes data before financial retention review",
);

console.log(`[${scope}] Financial operations completion QA passed.`);

async function functionSource(database, schema, name) {
  const result = await database.query(`
    select pg_get_functiondef(routine.oid) source
    from pg_proc routine
    join pg_namespace namespace on namespace.oid = routine.pronamespace
    where namespace.nspname = $1 and routine.proname = $2
    order by routine.oid desc
    limit 1
  `, [schema, name]);
  assertQa(result.rows[0]?.source, `missing remote function ${schema}.${name}`);
  return result.rows[0].source;
}
