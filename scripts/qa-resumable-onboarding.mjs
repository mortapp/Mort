import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-resumable-onboarding";
const acknowledgementVersion = "mort-closed-pilot-safety-v1";

function assertRpc(result, message) {
  assertQa(!result.error, `${message}: ${result.error?.message}`);
  assertQa(result.data?.ok === true, `${message}: ${result.data?.code}`);
  return result.data;
}

function assertCode(result, code, message) {
  assertQa(!result.error, `${message}: ${result.error?.message}`);
  assertQa(
    result.data?.ok === false && result.data?.code === code,
    `${message}: expected ${code}, received ${JSON.stringify(result.data)}`,
  );
}

async function resetToNewAccount(users) {
  const ids = Object.values(users).map((user) => user.id);
  await withDatabase(async (database) => {
    await database.query("begin");
    try {
      await database.query(
        "select set_config('mort.internal_update', 'true', true)",
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
        `
          update public.profiles
          set role = null,
              display_name = null,
              username = null,
              dob = null,
              city = null,
              state = null,
              location_setup_mode = 'city_state',
              onboarding_completed = false,
              payment_preference = 'none',
              guardian_setup_status = 'not_started',
              updated_at = now()
          where id = any($1::uuid[])
        `,
        [ids],
      );
      await database.query("commit");
    } catch (error) {
      await database.query("rollback").catch(() => {});
      throw error;
    }
  });
}

async function saveAge(user, dob) {
  return user.client.rpc("save_my_onboarding_age", {
    p_dob: dob,
    p_client_request_id: randomUUID(),
  });
}

async function saveRole(user, role) {
  return user.client.rpc("save_my_onboarding_role", {
    p_role: role,
    p_client_request_id: randomUUID(),
  });
}

async function saveProfile(user, { role, dob, complete = false }) {
  return user.client.rpc("save_my_onboarding_profile", {
    p_role: role,
    p_display_name: `QA ${role} onboarding`,
    p_dob: dob,
    p_city: "Indianapolis",
    p_state: "IN",
    p_location_setup_mode: "city_state",
    p_complete_onboarding: complete,
    p_payment_preference: "none",
    p_client_request_id: randomUUID(),
  });
}

async function saveStep(user, step, preferences = {}) {
  return user.client.rpc("save_my_onboarding_progress", {
    p_step: step,
    p_preferences: preferences,
    p_client_request_id: randomUUID(),
  });
}

async function acknowledge(user, overrides = {}) {
  return user.client.rpc("record_my_onboarding_acknowledgement", {
    p_acknowledgement_version: acknowledgementVersion,
    p_pilot_terms_notice_acknowledged: true,
    p_privacy_notice_acknowledged: true,
    p_community_rules_acknowledged: true,
    p_prohibited_work_acknowledged: true,
    p_safety_rules_acknowledged: true,
    p_platform: "hosted_qa",
    p_app_version: "0.9.11+101",
    p_client_request_id: randomUUID(),
    ...overrides,
  });
}

async function setUsername(user, suffix) {
  const result = await user.client.rpc("request_username_change", {
    p_new_username: `qa_onboard_${suffix}_${Date.now().toString(36)}`.slice(
      0,
      24,
    ),
  });
  assertQa(!result.error, `username setup failed: ${result.error?.message}`);
}

async function completeRolePath(user, { role, dob, profilePreferences = {} }) {
  assertRpc(await saveAge(user, dob), `${role} age save failed`);
  assertRpc(await saveRole(user, role), `${role} role save failed`);
  assertRpc(
    await saveProfile(user, { role, dob }),
    `${role} profile save failed`,
  );
  await setUsername(user, role);
  assertRpc(
    await saveStep(user, "profile", profilePreferences),
    `${role} profile progress failed`,
  );
  for (const step of [
    "skills",
    "availability",
    "transportation",
    "payment",
  ]) {
    assertRpc(await saveStep(user, step), `${role} ${step} failed`);
  }
  assertRpc(
    await saveStep(user, "guardian", {
      safety_setup_choice: "declined_optional",
    }),
    `${role} optional Guardian Mode failed`,
  );
  assertRpc(
    await saveStep(user, "preferences", {
      notification_choice: "ask_later",
      accessibility_preferences: {
        reduced_motion: false,
        larger_text: false,
        high_contrast: false,
      },
    }),
    `${role} preferences failed`,
  );
  assertRpc(await saveStep(user, "safety"), `${role} safety failed`);
  assertRpc(await saveStep(user, "review"), `${role} review failed`);
}

await withQaUsers(
  scope,
  [
    { key: "onboardingTeen", role: "teen", identityVerified: false },
    { key: "onboardingAdult", role: "adult", identityVerified: false },
    { key: "onboardingGuardian", role: "guardian", identityVerified: false },
  ],
  async ({ onboardingTeen: teen, onboardingAdult: adult, onboardingGuardian: guardian }) => {
    await resetToNewAccount({ teen, adult, guardian });

    const initial = assertRpc(
      await teen.client.rpc("get_my_onboarding_progress"),
      "initial progress failed",
    );
    assertQa(initial.current_step === "age", "new account did not start at age");
    assertQa(initial.resume_path === "/onboarding/age", "age resume path was wrong");

    assertCode(
      await saveStep(teen, "skills"),
      "onboarding_prerequisite_required",
      "out-of-order step was not rejected",
    );
    assertCode(
      await saveAge(teen, "2017-01-15"),
      "under_13_not_eligible",
      "under-13 age was not rejected",
    );
    assertRpc(await saveAge(teen, "2011-01-15"), "teen age failed");
    assertCode(
      await saveRole(teen, "adult"),
      "adult_role_age_mismatch",
      "teen account selected an adult role",
    );
    assertRpc(await saveRole(teen, "teen"), "teen role failed");
    assertRpc(
      await saveProfile(teen, { role: "teen", dob: "2011-01-15" }),
      "teen profile failed",
    );

    const bypass = await saveProfile(teen, {
      role: "teen",
      dob: "2011-01-15",
      complete: true,
    });
    assertQa(
      bypass.error?.message?.includes("onboarding_completion_rpc_required"),
      `legacy profile completion parameter bypass check returned ${JSON.stringify({
        error: bypass.error
          ? {
              code: bypass.error.code,
              message: bypass.error.message,
              details: bypass.error.details,
              hint: bypass.error.hint,
            }
          : null,
        data: bypass.data,
      })}`,
    );
    qaLog(scope, "legacy profile completion bypass is blocked by the profile trigger");

    await setUsername(teen, "teen");
    assertRpc(await saveStep(teen, "profile"), "teen profile step failed");
    assertRpc(await saveStep(teen, "skills"), "teen skills failed");
    const ageReplay = assertRpc(
      await saveAge(teen, "2011-01-15"),
      "same-age replay failed",
    );
    assertQa(
      ageReplay.current_step === "availability",
      `same-age replay regressed cursor to ${ageReplay.current_step}`,
    );
    for (const step of ["availability", "transportation", "payment"]) {
      assertRpc(await saveStep(teen, step), `teen ${step} failed`);
    }
    assertRpc(
      await saveStep(teen, "guardian", {
        safety_setup_choice: "declined_optional",
      }),
      "teen Guardian Mode skip failed",
    );
    assertRpc(
      await saveStep(teen, "preferences", {
        notification_choice: "disabled",
        accessibility_preferences: {
          reduced_motion: true,
          larger_text: true,
          high_contrast: false,
        },
      }),
      "teen preferences failed",
    );
    assertRpc(await saveStep(teen, "safety"), "teen safety failed");
    assertRpc(await saveStep(teen, "review"), "teen review failed");
    assertCode(
      await teen.client.rpc("complete_my_onboarding"),
      "onboarding_acknowledgement_required",
      "completion succeeded without safety acknowledgement",
    );
    assertCode(
      await acknowledge(teen, { p_privacy_notice_acknowledged: false }),
      "all_acknowledgements_required",
      "partial acknowledgement was accepted",
    );
    assertRpc(await acknowledge(teen), "teen acknowledgement failed");
    const teenComplete = assertRpc(
      await teen.client.rpc("complete_my_onboarding"),
      "teen completion failed",
    );
    assertQa(
      teenComplete.profile?.onboarding_completed === true,
      "teen profile was not completed",
    );
    const completeProgress = assertRpc(
      await teen.client.rpc("get_my_onboarding_progress"),
      "complete progress failed",
    );
    assertQa(completeProgress.current_step === "complete", "cursor was not complete");
    qaLog(scope, "teen path resumes, acknowledges, and completes server-side");

    await completeRolePath(adult, {
      role: "adult",
      dob: "1990-01-15",
      profilePreferences: { adult_account_type: "business" },
    });
    assertRpc(await acknowledge(adult), "adult acknowledgement failed");
    assertCode(
      await adult.client.rpc("complete_my_onboarding"),
      "business_name_required",
      "business onboarding completed without a business name",
    );
    const businessRepair = assertRpc(
      await saveStep(adult, "profile", {
        adult_account_type: "business",
        business_name: "MORT QA Neighborhood Services",
      }),
      "business name repair failed",
    );
    assertQa(
      businessRepair.current_step === "review",
      "editing an earlier adult step regressed the resume cursor",
    );
    assertRpc(
      await adult.client.rpc("complete_my_onboarding"),
      "adult completion failed",
    );
    qaLog(scope, "adult/business path enforces account type and business name");

    await completeRolePath(guardian, {
      role: "guardian",
      dob: "1988-05-20",
    });
    assertRpc(await acknowledge(guardian), "guardian acknowledgement failed");
    assertRpc(
      await guardian.client.rpc("complete_my_onboarding"),
      "guardian completion failed",
    );
    qaLog(scope, "guardian path completes without a mandatory guardian link");

    for (const table of [
      "onboarding_progress",
      "onboarding_acknowledgements",
      "onboarding_progress_events",
    ]) {
      const directRead = await teen.client.from(table).select("*").limit(1);
      assertQa(
        directRead.error || directRead.data?.length === 0,
        `authenticated client directly read service-only ${table}`,
      );
    }
    const otherProfile = await adult.client
      .from("profiles")
      .select("id,onboarding_completed")
      .eq("id", teen.id);
    assertQa(
      otherProfile.error || otherProfile.data?.[0]?.onboarding_completed == null,
      "adult read another user's private onboarding completion state",
    );
    qaLog(scope, "onboarding tables and completion state remain account-isolated");
  },
);
