import { randomUUID } from "node:crypto";

import { createClient } from "@supabase/supabase-js";

import {
  assertQa,
  anonKey,
  qaLog,
  serviceClient,
  supabaseUrl,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

function resultOf(response, label) {
  assertQa(!response.error, `${label} RPC failed: ${response.error?.message}`);
  assertQa(response.data && typeof response.data === "object", `${label} returned no object`);
  return response.data;
}

export async function runProfilePersistence(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const beforeResponse = await teen.client.rpc("get_my_profile");
    const before = beforeResponse.data?.[0];
    assertQa(before?.id === teen.id, "current profile was not available before update");
    const requestId = randomUUID();
    const displayName = `QA Persistent ${Date.now().toString(36)}`;
    const patch = {
      display_name: displayName,
      bio: "Reliable profile persistence QA biography.",
      availability: "Weekends after 10 AM",
      preferred_job_categories: ["organization", "yard work"],
      approximate_area: "Central Indianapolis",
      goals: "Build dependable work experience.",
    };
    const saved = resultOf(
      await teen.client.rpc("update_my_profile", {
        p_patch: patch,
        p_expected_updated_at: before.updated_at,
        p_client_request_id: requestId,
      }),
      "profile update",
    );
    assertQa(saved.ok === true && saved.profile.display_name === displayName, "server did not return the persisted display name");
    assertQa(saved.profile.bio === patch.bio, "server did not return persisted profile details");

    const replay = resultOf(
      await teen.client.rpc("update_my_profile", {
        p_patch: patch,
        p_expected_updated_at: before.updated_at,
        p_client_request_id: requestId,
      }),
      "idempotent profile replay",
    );
    assertQa(replay.ok === true && replay.replayed === true, "duplicate profile request was not idempotent");

    const stale = resultOf(
      await teen.client.rpc("update_my_profile", {
        p_patch: { bio: "This stale write must not win." },
        p_expected_updated_at: before.updated_at,
        p_client_request_id: randomUUID(),
      }),
      "stale profile update",
    );
    assertQa(stale.ok === false && stale.code === "profile_conflict_detected", "stale profile write did not fail with a conflict");

    await teen.client.auth.signOut();
    const signedBackIn = await teen.client.auth.signInWithPassword({ email: teen.email, password: teen.password });
    assertQa(!signedBackIn.error && signedBackIn.data.user?.id === teen.id, "QA user could not sign back in");
    const afterSignIn = await teen.client.rpc("get_my_profile");
    assertQa(afterSignIn.data?.[0]?.display_name === displayName, "profile edit did not persist after sign-out/sign-in");
    assertQa(afterSignIn.data?.[0]?.bio === patch.bio, "profile details did not persist after sign-out/sign-in");

    const audit = await serviceClient
      .from("profile_update_audit_events")
      .select("operation,updated_fields")
      .eq("user_id", teen.id)
      .eq("client_request_id", requestId)
      .single();
    assertQa(!audit.error && audit.data.operation === "profile_updated", "profile update audit event was not recorded");
    assertQa(!JSON.stringify(audit.data).includes(displayName), "profile audit event stored a profile value");
    qaLog(scope, "server-returned edits persist across reload and sign-out/sign-in; conflicts and duplicate submissions are safe");
  });
}

export async function runProfileForgery(scope) {
  await withQaUsers(scope, [{ key: "teen", role: "teen" }], async ({ teen }) => {
    const before = (await teen.client.rpc("get_my_profile")).data[0];
    for (const field of ["id", "role", "dob", "verification_status", "account_status", "is_test_account", "onboarding_completed"]) {
      const attempt = resultOf(
        await teen.client.rpc("update_my_profile", {
          p_patch: { [field]: field === "role" ? "admin" : "forged" },
          p_client_request_id: randomUUID(),
        }),
        `protected field ${field}`,
      );
      assertQa(attempt.ok === false && attempt.code === "protected_or_unknown_profile_field", `${field} was not rejected`);
    }
    const after = (await teen.client.rpc("get_my_profile")).data[0];
    assertQa(after.role === before.role && after.dob === before.dob, "protected profile state changed after forgery attempts");
    assertQa(after.verification_status === before.verification_status, "verification status changed after forgery attempts");
    qaLog(scope, "role, DOB, verification, moderation, account, and onboarding fields reject client forgery");
  });
}

export async function runProfileCrossUser(scope) {
  await withQaUsers(
    scope,
    [
      { key: "teenA", role: "teen" },
      { key: "teenB", role: "teen" },
    ],
    async ({ teenA, teenB }) => {
      const beforeB = (await teenB.client.rpc("get_my_profile")).data[0];
      const direct = await teenA.client.from("profiles").update({ display_name: "Cross User Forgery" }).eq("id", teenB.id).select("id");
      assertQa(!direct.error && direct.data.length === 0, "cross-user direct update was not hidden by RLS");
      const own = resultOf(
        await teenA.client.rpc("update_my_profile", {
          p_patch: { display_name: "QA Teen A Persisted" },
          p_client_request_id: randomUUID(),
        }),
        "caller-bound update",
      );
      assertQa(own.profile.id === teenA.id, "caller-bound RPC updated another profile");
      const afterB = (await teenB.client.rpc("get_my_profile")).data[0];
      assertQa(afterB.display_name === beforeB.display_name, "another user's profile changed");
      qaLog(scope, "direct and RPC profile writes cannot target another user");
    },
  );
}

export async function runProfileDuplicateRow(scope) {
  await withQaUsers(scope, [{ key: "adult", role: "adult" }], async ({ adult }) => {
    const duplicate = await adult.client.from("profiles").insert({ id: adult.id, role: "adult", display_name: "Duplicate", dob: "1990-01-15" });
    assertQa(duplicate.error, "duplicate profile primary-key insert unexpectedly succeeded");
    const count = await withDatabase(async (database) => {
      const result = await database.query("select count(*)::integer count from public.profiles where id = $1", [adult.id]);
      return result.rows[0].count;
    });
    assertQa(count === 1, `expected exactly one profile row; found ${count}`);
    qaLog(scope, "auth/profile one-to-one identity remains enforced by the primary key");
  });
}

export async function runProfileProjection(scope) {
  await withQaUsers(
    scope,
    [
      { key: "teen", role: "teen" },
      { key: "adult", role: "adult" },
    ],
    async ({ teen, adult }) => {
      const publicRead = await adult.client
        .from("profiles")
        .select("id,role,display_name,verification_status,username,avatar_path,bio,availability,preferred_job_categories,approximate_area,goals")
        .eq("id", teen.id)
        .maybeSingle();
      assertQa(!publicRead.error, `directory-safe projection failed: ${publicRead.error?.message}`);
      const forbidden = await adult.client.from("profiles").select("id,dob,city,state,account_status,payment_preference").eq("id", teen.id);
      assertQa(forbidden.error, "private profile columns were selectable by another user");
      assertQa(!JSON.stringify(publicRead.data ?? {}).includes("2011-01-15"), "exact DOB appeared in public profile projection");
      qaLog(scope, "directory reads exclude exact DOB, private location, account state, and payment preference");
    },
  );
}

export async function runAgeEligibility(scope) {
  const client = createClient(supabaseUrl, anonKey, { auth: { persistSession: false } });
  await withQaUsers(scope, [{ key: "adult", role: "adult" }], async ({ adult }) => {
    const cases = [
      ["2016-07-23", "under_13"],
      ["2013-07-21", "teen_13_15"],
      ["2010-02-28", "teen_16_17"],
      ["2008-07-21", "adult_18_plus"],
      ["2008-02-29", "adult_18_plus"],
    ];
    for (const [dob, expectedBand] of cases) {
      const response = await adult.client.rpc("derive_age_eligibility", { p_dob: dob });
      const result = resultOf(response, `age eligibility ${dob}`);
      assertQa(result.age_band === expectedBand, `${dob} produced ${result.age_band}, expected ${expectedBand}`);
    }
    const future = resultOf(await adult.client.rpc("derive_age_eligibility", { p_dob: "2999-01-01" }), "future DOB");
    assertQa(future.ok === false && future.code === "future_dob_rejected", "future DOB was not rejected");
    const anon = await client.rpc("derive_age_eligibility", { p_dob: "2000-01-01" });
    assertQa(anon.error, "anonymous callers can invoke age eligibility RPC");
    qaLog(scope, "server-date age bands, leap date, future rejection, and authenticated-only access passed");
  });
}
