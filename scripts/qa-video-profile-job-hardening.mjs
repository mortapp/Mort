import { randomBytes, randomUUID } from "node:crypto";

import { createClient } from "@supabase/supabase-js";

import {
  anonKey,
  assertQa,
  cleanupQaRestrictedData,
  qaLog,
  saveJob,
  serviceClient,
  supabaseUrl,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-video-profile-job-hardening";

function assertRpcResponse(response, label) {
  assertQa(!response.error, `${label} transport failed: ${response.error?.message}`);
  assertQa(response.data && typeof response.data === "object", `${label} returned no object`);
  return response.data;
}

async function runAtomicProfileQa() {
  const suffix = `${Date.now().toString(36)}-${randomBytes(4).toString("hex")}`;
  const email = `qa-video-profile-${suffix}@mort.test`;
  const password = randomBytes(30).toString("base64url");
  let userId;
  let client;

  try {
    const created = await serviceClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: "QA Video Profile" },
    });
    assertQa(!created.error && created.data.user, `QA profile user creation failed: ${created.error?.message}`);
    userId = created.data.user.id;
    client = createClient(supabaseUrl, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const signedIn = await client.auth.signInWithPassword({ email, password });
    assertQa(!signedIn.error && signedIn.data.user?.id === userId, "QA profile user could not sign in");

    const dob = "2011-01-15";
    const age = assertRpcResponse(
      await client.rpc("save_my_onboarding_age", {
        p_dob: dob,
        p_client_request_id: randomUUID(),
      }),
      "save onboarding age",
    );
    assertQa(age.ok === true, `onboarding age failed: ${age.code}`);
    const role = assertRpcResponse(
      await client.rpc("save_my_onboarding_role", {
        p_role: "teen",
        p_client_request_id: randomUUID(),
      }),
      "save onboarding role",
    );
    assertQa(role.ok === true, `onboarding role failed: ${role.code}`);

    const requestId = randomUUID();
    const username = `qa_video_${randomBytes(7)
      .toString("hex")
      .replace(/[0-9]/g, "g")}`;
    const payload = {
      role: "teen",
      display_name: "QA Atomic Teen",
      username,
      dob,
      city: "Indianapolis",
      state: "IN",
      location_setup_mode: "city_state",
      bio: "Atomic profile save QA.",
      availability: "Weekend daylight hours",
      preferred_job_categories: ["organization", "lawn care"],
      approximate_area: "Central Indianapolis",
      goals: "Build safe local work experience.",
      adult_account_type: "individual",
      business_name: "",
    };
    const saved = assertRpcResponse(
      await client.rpc("save_my_profile_setup_v2", {
        p_payload: payload,
        p_client_request_id: requestId,
        p_edit_existing: false,
      }),
      "atomic profile setup",
    );
    assertQa(saved.ok === true, `atomic profile setup failed: ${saved.code}`);
    assertQa(saved.profile?.id === userId && saved.profile?.role === "teen", "atomic setup returned another or wrong-role profile");
    assertQa(saved.profile?.username === username, "atomic setup did not persist the username");

    const replay = assertRpcResponse(
      await client.rpc("save_my_profile_setup_v2", {
        p_payload: payload,
        p_client_request_id: requestId,
        p_edit_existing: false,
      }),
      "atomic profile replay",
    );
    assertQa(replay.ok === true && replay.replayed === true, "atomic profile replay was not idempotent");

    const mismatch = assertRpcResponse(
      await client.rpc("save_my_profile_setup_v2", {
        p_payload: { ...payload, bio: "Changed payload must not reuse an ID." },
        p_client_request_id: requestId,
        p_edit_existing: false,
      }),
      "profile payload mismatch",
    );
    assertQa(
      mismatch.ok === false && mismatch.code === "profile_setup_request_payload_mismatch",
      "profile request ID accepted a changed payload",
    );

    const edit = assertRpcResponse(
      await client.rpc("save_my_profile_setup_v2", {
        p_payload: { ...payload, display_name: "QA Atomic Teen Edited" },
        p_client_request_id: randomUUID(),
        p_edit_existing: true,
      }),
      "atomic profile edit",
    );
    assertQa(edit.ok === true && edit.profile?.display_name === "QA Atomic Teen Edited", "completed profile edit did not persist atomically");

    const forgedRole = assertRpcResponse(
      await client.rpc("save_my_profile_setup_v2", {
        p_payload: {
          ...payload,
          role: "adult",
          dob: "1990-01-15",
          adult_account_type: "individual",
        },
        p_client_request_id: randomUUID(),
        p_edit_existing: true,
      }),
      "immutable role attempt",
    );
    assertQa(
      forgedRole.ok === false && forgedRole.code === "role_immutable" && forgedRole.field === "role",
      "completed profile role mutation was not rejected with a coded field",
    );

    const ownProfile = await client.rpc("get_my_profile");
    assertQa(!ownProfile.error && ownProfile.data?.[0]?.role === "teen", "role mutation changed the saved profile");
    qaLog(scope, "atomic setup/edit, replay, payload mismatch, and immutable role checks passed");
  } finally {
    await client?.auth.signOut().catch(() => {});
    if (userId) {
      await cleanupQaRestrictedData([userId]).catch(() => {});
      const removed = await serviceClient.auth.admin.deleteUser(userId, false);
      if (removed.error && removed.error.code !== "user_not_found") {
        throw new Error(`QA profile cleanup failed: ${removed.error.message}`);
      }
    }
  }
}

async function runJobBoundaryQa() {
  await withQaUsers(scope, [{ key: "adult", role: "adult" }], async ({ adult }) => {
    const invalidDuration = await adult.client.rpc("save_job_draft_or_publish", {
      p_job_id: null,
      p_client_request_id: randomUUID(),
      p_payload: { estimated_duration_minutes: 5, workers_needed: 1 },
      p_publish: true,
    });
    const durationResult = assertRpcResponse(invalidDuration, "invalid duration");
    assertQa(
      durationResult.ok === false &&
        durationResult.code === "invalid_job_duration" &&
        durationResult.field === "estimated_duration_minutes",
      "invalid duration did not return the coded field error",
    );

    const invalidZip = await saveJob(
      adult.client,
      { zip_code: "not-a-zip", client_request_id: randomUUID() },
      true,
    );
    assertQa(
      invalidZip.result.ok === false && invalidZip.result.code === "invalid_job_zip" && invalidZip.result.field === "zip_code",
      "invalid ZIP did not return the coded field error",
    );

    const missingProofInstructions = await saveJob(
      adult.client,
      {
        proof_expected: true,
        special_instructions: "short",
        client_request_id: randomUUID(),
      },
      true,
    );
    assertQa(
      missingProofInstructions.result.ok === false &&
        missingProofInstructions.result.code === "job_proof_instructions_required",
      "proof expectation did not require clear instructions",
    );

    const draft = await saveJob(adult.client, { client_request_id: randomUUID() }, false);
    assertQa(
      draft.result.ok === true && draft.result.publication_state === "draft" && draft.result.job?.status === "draft",
      "server draft did not return draft publication state",
    );
    const published = await saveJob(
      adult.client,
      { job_id: draft.result.job.id, client_request_id: randomUUID() },
      true,
    );
    assertQa(published.result.ok === true, `valid job save failed: ${published.result.code}`);
    const job = published.result.job;
    const expectedState = job.status === "open" && job.applications_open
      ? "open"
      : job.status === "pending_review"
        ? "pending_review"
        : "not_open";
    assertQa(published.result.publication_state === expectedState, "publication state did not match authoritative job state");
    if (expectedState === "pending_review") {
      assertQa(job.applications_open === false, "pending-review job accepted applications");
    }
    qaLog(scope, `coded job validation and truthful ${expectedState} publication state passed`);
  });
}

async function runAnonymousBoundaryQa() {
  const anonymous = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const profile = await anonymous.rpc("save_my_profile_setup_v2", {
    p_payload: {},
    p_client_request_id: randomUUID(),
    p_edit_existing: false,
  });
  const job = await anonymous.rpc("save_job_draft_or_publish", {
    p_job_id: null,
    p_client_request_id: randomUUID(),
    p_payload: {},
    p_publish: false,
  });
  assertQa(profile.error, "anonymous caller could execute profile setup");
  assertQa(job.error, "anonymous caller could execute job save");
  qaLog(scope, "anonymous execution remains denied for both hardened RPCs");
}

await runAtomicProfileQa();
await runJobBoundaryQa();
await runAnonymousBoundaryQa();
qaLog(scope, "all hosted profile/job hardening checks passed with QA cleanup");
