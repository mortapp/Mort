import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  saveJob,
  serviceClient,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-username-credits";

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen" },
    { key: "adult", role: "adult" },
    { key: "admin", role: "admin" },
  ],
  async ({ teen, adult, admin }) => {
    const status = await teen.client.rpc("get_username_change_status");
    assertQa(!status.error, `username status failed: ${status.error?.message}`);
    qaLog(scope, "teen can read their own username-change status");

    const nonAdminGrant = await teen.client.rpc("admin_grant_username_change_credit", {
      p_user_id: teen.id,
      p_credit_count: 1,
      p_reason: "qa-negative",
    });
    assertQa(nonAdminGrant.error, "teen granted their own username credit");
    qaLog(scope, "non-admin cannot grant username credits");

    const adminGrant = await admin.client.rpc("admin_grant_username_change_credit", {
      p_user_id: teen.id,
      p_credit_count: 1,
      p_reason: "isolated-qa",
    });
    assertQa(!adminGrant.error, `admin credit grant failed: ${adminGrant.error?.message}`);

    const consumeUsername = await teen.client.rpc("consume_username_change_credit");
    assertQa(!consumeUsername.error, `credit consume failed: ${consumeUsername.error?.message}`);
    qaLog(scope, "admin grant and user consumption follow checked username-credit RPCs");

    const job = await saveJob(adult.client, {
      title: "QA Job Boost Credit",
      summary: "An isolated open job for a real server credit consumption check.",
    });
    assertQa(job.result?.ok === true && job.result?.job?.id, "isolated job did not publish");

    const serviceGrant = await serviceClient.from("job_boost_credits").upsert(
      {
        user_id: adult.id,
        available_credits: 1,
        used_credits: 0,
        last_revenuecat_event_id: "qa-" + randomUUID(),
      },
      { onConflict: "user_id" },
    );
    assertQa(!serviceGrant.error, `service credit grant failed: ${serviceGrant.error?.message}`);

    const consumeBoost = await adult.client.rpc("consume_job_boost_credit", {
      p_job_id: job.result.job.id,
    });
    assertQa(!consumeBoost.error && consumeBoost.data?.id, `boost consume failed: ${consumeBoost.error?.message}`);
    qaLog(scope, "server-granted job-boost credit is consumed only through the checked RPC");
  },
);

qaLog(scope, "username and job-boost credit QA passed");
