import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { assertQa, qaLog, withDatabase } from "./feature-qa-helpers.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const sourceOnly = process.argv.includes("--source-only");

const falseFlags = [
  "stripe_payments_enabled",
  "stripe_connected_onboarding_enabled",
  "stripe_job_funding_enabled",
  "stripe_transfers_enabled",
  "stripe_refunds_enabled",
  "stripe_live_mode_enabled",
  "live_owner_approved",
  "connected_accounts_approved",
  "payouts_approved",
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
];

if (!sourceOnly) {
  await withDatabase(async (database) => {
    const result = await database.query(`
      select *
        from private.stripe_runtime_controls
       where singleton
    `);
    const control = result.rows[0];
    assertQa(control?.mode === "sandbox", "Stripe runtime must remain sandbox during production freeze.");
    for (const flag of falseFlags) {
      assertQa(control?.[flag] === false, `${flag} must remain false before production approval`);
    }
    assertQa(control?.partial_compensation_policy_version == null, "production partial-compensation policy must remain unset");
    assertQa(control?.production_approved_at == null, "production approval timestamp must remain unset");
  
    const functionResult = await database.query(`
      select pg_get_functiondef(to_regprocedure('private.stripe_live_financial_ready()')) as definition
    `);
    const definition = functionResult.rows[0]?.definition ?? "";
    for (const required of [
      "control.mode = 'live'",
      "control.stripe_live_mode_enabled",
      "control.live_owner_approved",
      "control.provider_use_case_approved",
      "control.legal_financial_approved",
      "control.privacy_financial_approved",
      "control.minor_payout_flow_approved",
      "control.tax_reporting_approved",
      "control.negative_balance_plan_approved",
      "control.reconciliation_schedule_approved",
      "control.monitoring_on_call_approved",
      "control.partial_compensation_policy_version is not null",
      "control.production_release_approved",
      "control.production_approved_at is not null",
    ]) {
      assertQa(definition.includes(required), `live readiness gate missing ${required}`);
    }
  });
}


const readinessDoc = await readFile(
  path.join(root, "docs", "payments", "MORT_STRIPE_LIVE_READINESS.md"),
  "utf8",
);
const activationChecklist = await readFile(
  path.join(root, "docs", "MORT_PAYMENT_PRODUCTION_ACTIVATION_CHECKLIST.md"),
  "utf8",
);
const docs = `${readinessDoc}\n${activationChecklist}`.toLowerCase();

for (const [label, content] of [
  ["live readiness", readinessDoc.toLowerCase()],
  ["activation checklist", activationChecklist.toLowerCase()],
]) {
  assertQa(content.includes("| gate | owner | evidence | status |"), `${label} must include gate owner/evidence/status fields`);
}

for (const required of [
  "production pricing",
  "radar pro",
  "transaction cost",
  "provider fee payer",
  "reserve",
  "chart of accounts",
  "production partial-compensation",
  "minor connect",
  "legal",
  "tax",
  "privacy",
  "monitoring/on-call",
  "provider pricing",
  "final owner approval",
]) {
  assertQa(docs.includes(required), `production blocker documentation missing: ${required}`);
}

qaLog(
  "stripe-activation-gates",
  sourceOnly
    ? "production blocker documentation is complete; hosted runtime verification intentionally skipped in source-only mode"
    : "live runtime and approval controls remain closed and every required external/economic blocker is documented",
);
