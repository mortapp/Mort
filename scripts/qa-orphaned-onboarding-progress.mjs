import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-orphaned-onboarding-progress";

await withQaUsers(
  scope,
  [{ key: "legacyTeen", role: "teen", identityVerified: false }],
  async ({ legacyTeen }) => {
    const username = `qa_legacy_${Date.now().toString(36)}`;

    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query(
          "select set_config('mort.internal_update', 'true', true)",
        );
        await database.query(
          `
            update public.profiles
            set onboarding_completed = false,
                display_name = 'QA legacy onboarding',
                username = $2,
                updated_at = now()
            where id = $1
          `,
          [legacyTeen.id, username],
        );
        await database.query(
          "delete from public.onboarding_progress_events where user_id = $1",
          [legacyTeen.id],
        );
        await database.query(
          "delete from public.onboarding_acknowledgements where user_id = $1",
          [legacyTeen.id],
        );
        await database.query(
          "delete from public.onboarding_progress where user_id = $1",
          [legacyTeen.id],
        );
        const profile = await database.query(
          "select id from public.profiles where id = $1 and username = $2",
          [legacyTeen.id, username],
        );
        assertQa(
          profile.rowCount === 1,
          "legacy profile fixture was not created",
        );
        await database.query("commit");
      } catch (error) {
        await database.query("rollback").catch(() => {});
        throw error;
      }
    });

    const before = await legacyTeen.client.rpc("get_my_onboarding_progress");
    assertQa(
      !before.error,
      `precondition lookup failed: ${before.error?.message}`,
    );
    assertQa(
      before.data?.current_step === "profile",
      "fixture did not resume at profile",
    );
    assertQa(
      Array.isArray(before.data?.completed_steps) &&
        before.data.completed_steps.length === 0,
      "fixture unexpectedly had onboarding progress",
    );
    qaLog(scope, "reproduced a validated legacy profile with no progress row");

    const requestId = randomUUID();
    const payload = {
      role: "teen",
      display_name: "QA legacy onboarding",
      username,
      dob: "2011-01-15",
      city: "Indianapolis",
      state: "IN",
      location_setup_mode: "city_state",
      bio: null,
      availability: null,
      preferred_job_categories: [],
      approximate_area: null,
      goals: null,
    };
    const saved = await legacyTeen.client.rpc("save_my_profile_setup_v2", {
      p_payload: payload,
      p_client_request_id: requestId,
      p_edit_existing: false,
    });
    assertQa(!saved.error, `legacy profile save failed: ${saved.error?.message}`);
    assertQa(
      saved.data?.ok === true,
      `legacy profile save returned ${saved.data?.code}`,
    );
    assertQa(
      saved.data?.onboarding_progress?.current_step === "skills",
      "legacy profile did not advance to skills",
    );
    for (const step of ["age", "role", "profile"]) {
      assertQa(
        saved.data.onboarding_progress.completed_steps.includes(step),
        `legacy profile progress omitted ${step}`,
      );
    }
    qaLog(
      scope,
      "profile setup repaired missing prerequisites and advanced atomically",
    );

    const replay = await legacyTeen.client.rpc("save_my_profile_setup_v2", {
      p_payload: payload,
      p_client_request_id: requestId,
      p_edit_existing: false,
    });
    assertQa(
      !replay.error,
      `idempotent replay failed: ${replay.error?.message}`,
    );
    assertQa(
      replay.data?.ok === true && replay.data?.replayed === true,
      "save replay was not idempotent",
    );

    const directRead = await legacyTeen.client
      .from("onboarding_progress")
      .select("user_id")
      .eq("user_id", legacyTeen.id);
    assertQa(
      directRead.error || directRead.data?.length === 0,
      "authenticated client directly read private onboarding progress",
    );
    qaLog(scope, "repair preserves RPC-only onboarding state isolation");
  },
);
