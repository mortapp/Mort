import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";

import {
  anonKey,
  assertQa,
  qaLog,
  serviceClient,
  supabaseUrl,
  withDatabase,
} from "./feature-qa-helpers.mjs";

const scope = "qa-play-reviewer-isolation";
const reservedEmail = "play-review@mortapp.test";
const aliasEmail = `play-review+ordinary-${randomUUID()}@mortapp.test`;
let aliasUserId = null;

try {
  await withDatabase(async (database) => {
    const reservation = await database.query(
      `
        select
          exists (
            select 1
            from pg_trigger
            where tgname = 'auth_users_reject_play_reviewer_identity'
              and tgenabled <> 'D'
          ) as trigger_enabled,
          has_function_privilege(
            'anon',
            'public.reject_reserved_play_reviewer_identity()',
            'execute'
          ) as anon_can_execute,
          has_function_privilege(
            'authenticated',
            'public.reject_reserved_play_reviewer_identity()',
            'execute'
          ) as authenticated_can_execute,
          (
            select count(*)::integer
            from auth.users
            where lower(btrim(email)) = $1
          ) as reserved_users
      `,
      [reservedEmail],
    );
    const row = reservation.rows[0];
    assertQa(row.trigger_enabled, "reserved identifier trigger is not enabled");
    assertQa(!row.anon_can_execute, "anon can execute the reservation trigger function");
    assertQa(!row.authenticated_can_execute, "authenticated can execute the reservation trigger function");
    assertQa(row.reserved_users === 0, "a production Auth user already owns the reviewer identifier");
    qaLog(scope, "server reservation trigger is enabled and has no public execute grant");
  });

  const reservedAttempt = await serviceClient.auth.admin.createUser({
    email: reservedEmail,
    password: `Qa!${randomUUID()}aA9`,
    email_confirm: true,
  });
  if (reservedAttempt.data.user) {
    await serviceClient.auth.admin.deleteUser(reservedAttempt.data.user.id);
  }
  assertQa(reservedAttempt.error && !reservedAttempt.data.user, "reserved identifier created a production Auth user");
  qaLog(scope, "Auth Admin creation of the exact reviewer identifier is denied");

  const aliasAttempt = await serviceClient.auth.admin.createUser({
    email: aliasEmail,
    password: `Qa!${randomUUID()}aA9`,
    email_confirm: true,
    user_metadata: { qa_scope: scope },
  });
  assertQa(!aliasAttempt.error && aliasAttempt.data.user, `ordinary alias user creation failed: ${aliasAttempt.error?.message}`);
  aliasUserId = aliasAttempt.data.user.id;
  qaLog(scope, "ordinary email/password Auth remains available outside the exact reservation");

  const anonymous = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const anonymousSession = await anonymous.auth.getSession();
  assertQa(!anonymousSession.data.session, "anonymous reviewer QA unexpectedly obtained a Supabase session");

  for (const table of ["profiles", "messages", "proof_uploads"]) {
    const read = await anonymous.from(table).select("id").limit(5);
    assertQa(read.error || (read.data?.length ?? 0) === 0, `anonymous access exposed production ${table}`);
  }
  qaLog(scope, "anonymous access cannot read profiles, messages, or proof evidence");

  const applicationId = randomUUID();
  const startPin = await anonymous.rpc("confirm_job_start_pin", {
    p_application_id: applicationId,
    p_pin: "123456",
    p_person_matches_profile: true,
    p_client_request_id: randomUUID(),
  });
  const finishPin = await anonymous.rpc("confirm_job_finish_pin", {
    p_application_id: applicationId,
    p_pin: "654321",
    p_client_request_id: randomUUID(),
  });
  assertQa(startPin.error, "demo START PIN reached the production confirmation function anonymously");
  assertQa(finishPin.error, "demo COMPLETION PIN reached the production confirmation function anonymously");
  qaLog(scope, "demo PINs are denied by production job-verification endpoints");

  const adminMutation = await anonymous.rpc("admin_update_runtime_feature_controls", {
    p_maintenance_mode: true,
    p_ai_provider_disabled: true,
    p_payments_disabled: true,
    p_new_job_publishing_disabled: true,
    p_public_marketplace_closed: true,
    p_reason: "Reviewer isolation denial QA only.",
  });
  assertQa(adminMutation.error, "anonymous reviewer QA reached a destructive admin function");
  qaLog(scope, "destructive production administration is denied without a real authorized session");
} finally {
  if (aliasUserId) {
    const cleanup = await serviceClient.auth.admin.deleteUser(aliasUserId);
    if (cleanup.error) throw cleanup.error;
  }
}
