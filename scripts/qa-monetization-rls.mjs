import {
  assertQa,
  qaLog,
  saveJob,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-monetization-rls";

function assertRejectedOrHidden(result, message) {
  assertQa(result.error || (result.data ?? []).length === 0, message);
}

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "admin", role: "admin" },
  ],
  async ({ teen, adult, admin }) => {
    const entitlementForge = await teen.client
      .from("monetization_entitlements_cache")
      .insert({ user_id: teen.id, entitlements: ["mort_plus"], source: "app" })
      .select("user_id");
    assertRejectedOrHidden(entitlementForge, "user forged the entitlement cache");
    qaLog(scope, "users cannot forge monetization entitlements");

    const usernameForge = await teen.client
      .from("username_change_credits")
      .upsert({ user_id: teen.id, token_credits: 100 })
      .select("user_id");
    assertRejectedOrHidden(usernameForge, "user granted username credits");

    const boostCreditForge = await adult.client
      .from("job_boost_credits")
      .upsert({ user_id: adult.id, available_credits: 100 })
      .select("user_id");
    assertRejectedOrHidden(boostCreditForge, "user granted job boost credits");
    qaLog(scope, "users cannot self-grant username or job-boost credits");

    const creditStatus = await adult.client.rpc("get_job_boost_credit_status");
    assertQa(!creditStatus.error, `own boost status failed: ${creditStatus.error?.message}`);
    qaLog(scope, "user can read only the checked job-boost status projection");

    const job = await saveJob(adult.client, {
      title: "QA Monetization RLS Job",
      summary: "An isolated open job for server-authorized boost checks.",
    });
    assertQa(job.result?.ok === true && job.result?.job?.id, "isolated boost job did not publish");

    const directBoost = await adult.client
      .from("boosted_jobs")
      .insert({
        job_id: job.result.job.id,
        purchaser_id: adult.id,
        revenuecat_product_id: "mort_job_boost_1",
        status: "pending",
      })
      .select("id");
    assertRejectedOrHidden(directBoost, "user directly inserted a boost without a server credit");

    const consumeWithoutCredit = await adult.client.rpc("consume_job_boost_credit", {
      p_job_id: job.result.job.id,
    });
    assertQa(consumeWithoutCredit.error, "boost RPC accepted an account without credits");
    qaLog(scope, "direct boosts and creditless boost consumption are rejected");

    const adminAudit = await admin.client.from("purchase_audit_logs").select("id").limit(1);
    assertQa(!adminAudit.error, `admin purchase audit read failed: ${adminAudit.error?.message}`);
    qaLog(scope, "server-recognized admin can read the purchase audit queue");
  },
);

qaLog(scope, "monetization RLS QA passed");
