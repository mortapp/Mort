import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-four-step-onboarding-v2";
const steps = ["account", "work_preferences", "safety_support", "review"];

function assertRpc(result, message) {
  assertQa(!result.error, `${message}: ${result.error?.message}`);
  assertQa(result.data?.ok === true, `${message}: ${result.data?.code}`);
  return result.data;
}

function assertCode(result, code, message) {
  assertQa(!result.error, `${message}: ${result.error?.message}`);
  assertQa(
    result.data?.ok === false && result.data?.code === code,
    `${message}: expected ${code}, got ${JSON.stringify(result.data)}`,
  );
}

async function resetUsers(users) {
  const ids = Object.values(users).map((user) => user.id);
  await withDatabase(async (database) => {
    await database.query("begin");
    try {
      await database.query("select set_config('mort.internal_update', 'true', true)");
      const ledger = await database.query(
        "select to_regclass('private.onboarding_v2_requests') as relation",
      );
      if (ledger.rows[0]?.relation) {
        await database.query(
          "delete from private.onboarding_v2_requests where user_id = any($1::uuid[])",
          [ids],
        );
      }
      await database.query(
        "delete from public.legal_acceptance_audit_events where user_id = any($1::uuid[])",
        [ids],
      );
      await database.query(
        "delete from public.legal_acceptances where user_id = any($1::uuid[])",
        [ids],
      );
      await database.query(
        "delete from public.onboarding_progress_events where user_id = any($1::uuid[])",
        [ids],
      );
      await database.query(
        "delete from public.onboarding_acknowledgements where user_id = any($1::uuid[])",
        [ids],
      );
      await database.query(
        "delete from public.onboarding_progress where user_id = any($1::uuid[])",
        [ids],
      );
      await database.query(
        `update public.profiles
         set role = null, display_name = null, username = null, dob = null,
             city = null, state = null, onboarding_completed = false,
             availability = null, preferred_job_categories = '{}',
             transportation_methods = '{}', guardian_setup_status = 'not_started',
             updated_at = now()
         where id = any($1::uuid[])`,
        [ids],
      );
      await database.query("commit");
    } catch (error) {
      await database.query("rollback").catch(() => {});
      throw error;
    }
  });
}

function accountPayload(role, dob, suffix) {
  return {
    role,
    display_name: `QA ${role} Person`,
    username: `qa_v2_${role}_${suffix}`.slice(0, 24),
    dob,
    city: "Indianapolis",
    state: "IN",
    location_setup_mode: "city_state",
    adult_account_type: role === "adult" ? "individual" : null,
    business_name: null,
  };
}

async function save(user, rpc, payload, requestId = randomUUID(), revision = null) {
  return user.client.rpc(rpc, {
    p_payload: payload,
    p_client_request_id: requestId,
    p_payload_version: 1,
    ...(revision == null ? {} : { p_expected_revision: revision }),
  });
}

await withQaUsers(
  scope,
  [
    { key: "teen", role: "teen", identityVerified: false },
    { key: "adult", role: "adult", identityVerified: false },
    { key: "guardian", role: "guardian", identityVerified: false },
  ],
  async ({ teen, adult, guardian }) => {
    await resetUsers({ teen, adult, guardian });

    const initial = assertRpc(
      await teen.client.rpc("get_my_onboarding_progress_v2"),
      "initial v2 progress failed",
    );
    assertQa(initial.active_step === "account", "new user did not start at account");
    assertQa(
      JSON.stringify(initial.primary_steps) === JSON.stringify(steps),
      `primary step contract changed: ${JSON.stringify(initial.primary_steps)}`,
    );

    const suffix = Date.now().toString(36);
    const requestId = randomUUID();
    const teenAccount = accountPayload("teen", "2010-05-10", suffix);
    const savedAccount = assertRpc(
      await save(teen, "save_my_onboarding_account_v2", teenAccount, requestId),
      "teen account save failed",
    );
    assertQa(savedAccount.active_step === "work_preferences", "account did not advance");

    const replay = assertRpc(
      await save(teen, "save_my_onboarding_account_v2", teenAccount, requestId),
      "same-payload replay failed",
    );
    assertQa(replay.replayed === true, "same request was not replayed safely");
    assertCode(
      await save(
        teen,
        "save_my_onboarding_account_v2",
        { ...teenAccount, display_name: "Different Person" },
        requestId,
      ),
      "onboarding_request_payload_mismatch",
      "mismatched replay was accepted",
    );

    const sharedRequestId = randomUUID();
    assertRpc(
      await save(adult, "save_my_onboarding_account_v2", accountPayload("adult", "1990-05-10", suffix), sharedRequestId),
      "adult cross-user request failed",
    );
    assertRpc(
      await save(guardian, "save_my_onboarding_account_v2", accountPayload("guardian", "1988-05-10", suffix), sharedRequestId),
      "guardian cross-user request failed",
    );

    assertCode(
      await save(teen, "complete_my_onboarding_v2", { legal_version_ids: [] }),
      "onboarding_work_preferences_required",
      "completion trusted progress instead of canonical work data",
    );

    const directUpdate = await teen.client
      .from("profiles")
      .update({ onboarding_completed: true })
      .eq("id", teen.id);
    assertQa(directUpdate.error, "direct completion UPDATE was accepted");

    const directUpsert = await teen.client
      .from("profiles")
      .upsert({ id: teen.id, onboarding_completed: true });
    assertQa(directUpsert.error, "direct completion UPSERT was accepted");
    qaLog(scope, "v2 contract, replay isolation, and direct completion boundary passed");
  },
);
