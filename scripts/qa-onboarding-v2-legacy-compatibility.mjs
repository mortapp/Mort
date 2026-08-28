import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-onboarding-v2-legacy-compatibility";
const tableName = "private.onboarding_v2_legacy_completion_compatibility";
const expectedTotal = 24;
const expectedTest = 17;
const expectedNonTest = 7;

function resultOf(queryResult) {
  return queryResult.rows[0]?.result;
}

await withDatabase(async (database) => {
  const relation = await database.query("select to_regclass($1) as relation", [tableName]);
  assertQa(relation.rows[0].relation === tableName, "legacy completion compatibility snapshot is not deployed");

  const counts = await database.query(
    `select
       count(*)::int as total,
       count(*) filter (where profile.is_test_account)::int as test_count,
       count(*) filter (where not profile.is_test_account)::int as non_test_count,
       count(distinct compatibility.user_id)::int as unique_users
     from ${tableName} compatibility
     join public.profiles profile on profile.id = compatibility.user_id`,
  );
  assertQa(counts.rows[0].total === expectedTotal, `expected ${expectedTotal} grandfathered users, got ${counts.rows[0].total}`);
  assertQa(counts.rows[0].test_count === expectedTest, `expected ${expectedTest} test/QA users, got ${counts.rows[0].test_count}`);
  assertQa(counts.rows[0].non_test_count === expectedNonTest, `expected ${expectedNonTest} non-test users, got ${counts.rows[0].non_test_count}`);
  assertQa(counts.rows[0].unique_users === expectedTotal, "compatibility snapshot contains duplicate users");

  for (const isTest of [false, true]) {
    const representative = await database.query(
      `select compatibility.user_id
       from ${tableName} compatibility
       join public.profiles profile on profile.id = compatibility.user_id
       where profile.is_test_account = $1
       order by compatibility.grandfathered_at, compatibility.user_id
       limit 1`,
      [isTest],
    );
    assertQa(representative.rowCount === 1, `missing ${isTest ? "test" : "non-test"} grandfathered representative`);
    const progress = resultOf(
      await database.query("select private.evaluate_onboarding_v2($1) as result", [representative.rows[0].user_id]),
    );
    assertQa(progress.completed === true && progress.active_step === "complete", "grandfathered representative was reopened");
  }

  const successfulV2InSnapshot = await database.query(
    `select count(*)::int as count
     from ${tableName} compatibility
     join private.onboarding_v2_requests request
       on request.user_id = compatibility.user_id
      and request.operation = 'complete'
      and coalesce((request.response->>'completed')::boolean, false)`,
  );
  assertQa(successfulV2InSnapshot.rows[0].count === 0, "post-cutover v2 completion entered the legacy snapshot");
});

await withQaUsers(
  scope,
  [{ key: "new-user", role: "teen", identityVerified: false }],
  async ({ "new-user": newUser }) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query("select set_config('mort.internal_update', 'true', true)");
        await database.query(
          `delete from private.onboarding_v2_requests where user_id = $1;
           delete from private.onboarding_v2_safety where user_id = $1;
           delete from public.onboarding_progress_events where user_id = $1;
           delete from public.onboarding_acknowledgements where user_id = $1;
           delete from public.onboarding_progress where user_id = $1;
           update public.profiles
           set onboarding_completed = false, role = null, display_name = null,
               username = null, dob = null, city = null, state = null,
               availability = null, preferred_job_categories = '{}',
               transportation_methods = '{}', guardian_setup_status = 'not_started'
           where id = $1`,
          [newUser.id],
        );
        await database.query("commit");
      } catch (error) {
        await database.query("rollback").catch(() => {});
        throw error;
      }
    });

    const progress = await newUser.client.rpc("get_my_onboarding_progress_v2");
    assertQa(!progress.error && progress.data?.active_step === "account", "new user did not enter canonical v2 onboarding");

    const insert = await newUser.client.schema("private").from("onboarding_v2_legacy_completion_compatibility").insert({
      user_id: newUser.id,
      source_version: "malicious",
    });
    assertQa(insert.error, "authenticated client self-grandfather INSERT was accepted");
    const update = await newUser.client.schema("private").from("onboarding_v2_legacy_completion_compatibility").update({
      source_version: "malicious",
    }).eq("user_id", newUser.id);
    assertQa(update.error, "authenticated client compatibility UPDATE was accepted");
    const remove = await newUser.client.schema("private").from("onboarding_v2_legacy_completion_compatibility").delete().eq("user_id", newUser.id);
    assertQa(remove.error, "authenticated client compatibility DELETE was accepted");

    const flags = await newUser.client.rpc("save_my_onboarding_safety_v2", {
      p_payload: { notification_intent: "ask_later", guardian_choice: "skip", grandfathered: true },
      p_client_request_id: crypto.randomUUID(),
      p_payload_version: 1,
    });
    assertQa(
      !flags.error && flags.data?.code === "onboarding_payload_unknown_fields",
      "client-supplied grandfathered flag gained authority",
    );

    const directUpdate = await newUser.client.from("profiles").update({ onboarding_completed: true }).eq("id", newUser.id);
    assertQa(directUpdate.error, "direct completion UPDATE was accepted");
    const directUpsert = await newUser.client.from("profiles").upsert({ id: newUser.id, onboarding_completed: true });
    assertQa(directUpsert.error, "direct completion UPSERT was accepted");
  },
);

qaLog(scope, "hosted count, representatives, canonical new user, client denial, and direct completion guard checks passed");
