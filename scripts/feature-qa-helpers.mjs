import { randomBytes, randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";
import pg from "pg";

export const projectRef = "rakjydmgwwgtdislanbt";
export const supabaseUrl = `https://${projectRef}.supabase.co`;

export const anonKey = required("EXPO_PUBLIC_SUPABASE_ANON_KEY");
const serviceRoleKey = required("SUPABASE_SERVICE_ROLE_KEY");
const dbPassword = required("SUPABASE_DB_PASSWORD");

if (process.env.EXPO_PUBLIC_SUPABASE_URL !== supabaseUrl) {
  throw new Error(`EXPO_PUBLIC_SUPABASE_URL must target ${supabaseUrl}.`);
}

export const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

function required(name) {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export function assertQa(condition, message) {
  if (!condition) throw new Error(message);
}

export function qaLog(scope, message) {
  console.log(`[${scope}] PASS: ${message}`);
}

export async function withDatabase(run) {
  const database = new pg.Client({
    host: `db.${projectRef}.supabase.co`,
    port: 5432,
    database: "postgres",
    user: "postgres",
    password: dbPassword,
    ssl: { rejectUnauthorized: false },
  });
  await database.connect();
  try {
    return await run(database);
  } finally {
    await database.end();
  }
}

export async function removeQaModerationEvent(resourceId, userId) {
  const database = new pg.Client({
    host: `db.${projectRef}.supabase.co`,
    port: 5432,
    database: "postgres",
    user: "postgres",
    password: dbPassword,
    ssl: { rejectUnauthorized: false },
  });
  await database.connect();
  try {
    const result = await database.query(
      `
        delete from public.ai_moderation_events
        where resource_type = 'job_draft'
          and resource_id = $1
          and user_id = $2
      `,
      [resourceId, userId],
    );
    if (result.rowCount !== 1) {
      throw new Error(`Expected to remove one QA moderation event; removed ${result.rowCount}.`);
    }
  } finally {
    await database.end();
  }
}

export async function cleanupQaRestrictedData(userIds) {
  if (!Array.isArray(userIds) || userIds.length === 0) return;
  await withDatabase(async (database) => {
    await database.query("begin");
    try {
      await database.query("select set_config('mort.internal_update', 'true', true)");
      await database.query(
        `
          create temporary table qa_restricted_incidents (
            id uuid primary key
          ) on commit drop
        `,
      );
      await database.query(
        `
          create temporary table qa_legal_trust_contracts (
            id uuid primary key
          ) on commit drop
        `,
      );
      await database.query(
        `
          create temporary table qa_support_tickets (
            id uuid primary key
          ) on commit drop
        `,
      );
      await database.query(
        `
          insert into qa_support_tickets (id)
          select id from public.support_tickets
          where requester_id = any($1::uuid[])
        `,
        [userIds],
      );
      await database.query(
        `
          insert into qa_legal_trust_contracts (id)
          select contract.id
          from public.job_contracts contract
          where contract.teen_id = any($1::uuid[])
             or contract.adult_id = any($1::uuid[])
        `,
        [userIds],
      );
      await database.query(
        `
          create temporary table qa_legal_trust_disputes (
            id uuid primary key
          ) on commit drop
        `,
      );
      await database.query(
        `
          insert into qa_legal_trust_disputes (id)
          select dispute.id
          from public.payment_disputes dispute
          where dispute.contract_id in (select id from qa_legal_trust_contracts)
             or dispute.worker_id = any($1::uuid[])
             or dispute.poster_id = any($1::uuid[])
        `,
        [userIds],
      );
      await database.query(
        `
          insert into qa_restricted_incidents (id)
          select distinct incident.id
          from public.safety_incidents incident
          where incident.reporter_id = any($1::uuid[])
             or incident.subject_user_id = any($1::uuid[])
             or exists (
               select 1
               from public.incident_participants participant
               where participant.incident_id = incident.id
                 and participant.user_id = any($1::uuid[])
             )
        `,
        [userIds],
      );
      await database.query(
        `
          delete from public.verification_audit_events
          where verification_id in (
            select id from public.identity_verifications
            where user_id = any($1::uuid[])
          )
        `,
        [userIds],
      );
      await database.query(
        `
          delete from public.identity_verification_evidence
          where verification_id in (
            select id from public.identity_verifications
            where user_id = any($1::uuid[])
          )
        `,
        [userIds],
      );
      await database.query(
        "delete from public.message_safety_evidence where sender_id = any($1::uuid[])",
        [userIds],
      );
      await database.query(
        "delete from public.payment_evidence_export_events where dispute_id in (select id from qa_legal_trust_disputes)",
      );
      await database.query(
        `delete from public.support_evidence_access_events
         where evidence_id in (
           select id from public.support_evidence_attachments
           where owner_id = any($1::uuid[])
              or ticket_id in (select id from qa_support_tickets)
         )`,
        [userIds],
      );
      await database.query(
        `delete from public.support_evidence_attachments
         where owner_id = any($1::uuid[])
            or ticket_id in (select id from qa_support_tickets)`,
        [userIds],
      );
      await database.query(
        "delete from public.support_ticket_audit_events where ticket_id in (select id from qa_support_tickets)",
      );
      await database.query(
        "delete from public.support_ticket_messages where ticket_id in (select id from qa_support_tickets)",
      );
      await database.query(
        "delete from public.support_tickets where id in (select id from qa_support_tickets)",
      );
      await database.query(
        "delete from public.poster_payment_restrictions where dispute_id in (select id from qa_legal_trust_disputes)",
      );
      await database.query(
        "delete from public.payment_dispute_decisions where dispute_id in (select id from qa_legal_trust_disputes)",
      );
      await database.query(
        "delete from public.payment_dispute_timeline where dispute_id in (select id from qa_legal_trust_disputes)",
      );
      await database.query(
        "delete from public.payment_dispute_evidence where dispute_id in (select id from qa_legal_trust_disputes)",
      );
      await database.query(
        "delete from public.payment_dispute_assignments where dispute_id in (select id from qa_legal_trust_disputes)",
      );
      await database.query(
        "delete from public.payment_disputes where id in (select id from qa_legal_trust_disputes)",
      );
      await database.query(
        `delete from public.payment_confirmation_records
         where obligation_id in (
           select obligation.id from public.job_payment_obligations obligation
           where obligation.contract_id in (select id from qa_legal_trust_contracts)
         )`,
      );
      await database.query(
        "delete from public.completion_evidence_records where contract_id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        "delete from public.job_completion_assertions where contract_id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        `update public.job_payment_obligations
         set superseded_by_obligation_id = null
         where contract_id in (select id from qa_legal_trust_contracts)`,
      );
      await database.query(
        "delete from public.job_payment_obligations where contract_id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        `update public.job_contract_change_requests
         set created_version_id = null
         where contract_id in (select id from qa_legal_trust_contracts)`,
      );
      await database.query(
        `update public.job_contract_versions
         set source_change_request_id = null
         where contract_id in (select id from qa_legal_trust_contracts)`,
      );
      await database.query(
        `delete from public.job_contract_change_acceptances
         where change_request_id in (
           select request.id from public.job_contract_change_requests request
           where request.contract_id in (select id from qa_legal_trust_contracts)
         )`,
      );
      await database.query(
        "delete from public.job_contract_change_requests where contract_id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        "delete from public.job_contract_acceptances where contract_id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        "update public.job_contracts set active_version_id = null where id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        "delete from public.job_contract_versions where contract_id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        "delete from public.job_contracts where id in (select id from qa_legal_trust_contracts)",
      );
      await database.query(
        `delete from public.legal_acceptance_audit_events
         where user_id = any($1::uuid[])`,
        [userIds],
      );
      await database.query(
        `delete from public.legal_reacceptance_requirements
         where user_id = any($1::uuid[])`,
        [userIds],
      );
      await database.query("delete from public.legal_acceptances where user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.legal_declines where user_id = any($1::uuid[])", [userIds]);
      await database.query(
        `delete from public.appearance_review_decisions
         where appearance_case_id in (
           select appearance.id from public.appearance_review_cases appearance
           where appearance.subject_user_id = any($1::uuid[])
         ) or reviewer_id = any($1::uuid[])`,
        [userIds],
      );
      await database.query(
        `delete from public.appearance_review_assignments
         where appearance_case_id in (
           select appearance.id from public.appearance_review_cases appearance
           where appearance.subject_user_id = any($1::uuid[])
         ) or reviewer_id = any($1::uuid[])`,
        [userIds],
      );
      await database.query("delete from public.appearance_review_cases where subject_user_id = any($1::uuid[])", [userIds]);
      await database.query(
        `delete from public.document_web_reuse_results
         where request_id in (
           select request.id from public.document_web_reuse_requests request
           where request.subject_user_id = any($1::uuid[])
         )`,
        [userIds],
      );
      await database.query("delete from public.document_web_reuse_requests where subject_user_id = any($1::uuid[])", [userIds]);
      await database.query(
        `delete from public.document_capture_quality_results
         where capture_session_id in (
           select session.id from public.document_capture_sessions session
           where session.subject_user_id = any($1::uuid[])
         )`,
        [userIds],
      );
      await database.query("delete from public.document_capture_sessions where subject_user_id = any($1::uuid[])", [userIds]);
      await database.query(
        `delete from public.live_presence_results
         where challenge_id in (
           select challenge.id from public.live_presence_challenges challenge
           where challenge.subject_user_id = any($1::uuid[])
         )`,
        [userIds],
      );
      await database.query("delete from public.live_presence_challenges where subject_user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.team_access_audit_events where user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.team_role_assignments where user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.team_training_completions where user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.team_confidentiality_acknowledgements where user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.team_conflict_disclosures where user_id = any($1::uuid[])", [userIds]);
      await database.query("delete from public.team_device_compliance where user_id = any($1::uuid[])", [userIds]);
      for (const table of [
        "incident_actions",
        "incident_appeals",
        "incident_contact_attempts",
        "incident_evidence",
        "incident_law_enforcement_requests",
        "incident_outcomes",
        "incident_preservation_orders",
        "incident_timeline_events",
      ]) {
        await database.query(
          `delete from public.${table} where incident_id in (select id from qa_restricted_incidents)`,
        );
      }
      await database.query(
        "delete from public.safety_incidents where id in (select id from qa_restricted_incidents)",
      );
      await database.query(
        "delete from public.safety_cancellations where actor_id = any($1::uuid[])",
        [userIds],
      );
      await database.query("commit");
    } catch (error) {
      await database.query("rollback").catch(() => {});
      throw error;
    }
  });
}

export async function withQaUsers(scope, definitions, run) {
  const suffix = `${Date.now().toString(36)}-${randomBytes(4).toString("hex")}`;
  const password = randomBytes(30).toString("base64url");
  const created = [];
  const users = {};

  try {
    for (const definition of definitions) {
      const email = `qa-feature-${definition.key}-${suffix}@mort.test`;
      const { data, error } = await serviceClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { display_name: `QA ${definition.key}` },
      });
      if (error || !data.user) {
        throw new Error(`Could not create ${definition.key} QA user: ${error?.message}`);
      }
      created.push({ id: data.user.id, role: definition.role });
      users[definition.key] = {
        id: data.user.id,
        email,
        password,
        role: definition.role,
        isTest: definition.isTest !== false,
      };
    }

    const database = new pg.Client({
      host: `db.${projectRef}.supabase.co`,
      port: 5432,
      database: "postgres",
      user: "postgres",
      password: dbPassword,
      ssl: { rejectUnauthorized: false },
    });
    await database.connect();
    try {
      await database.query("begin");
      await database.query("select set_config('mort.internal_update', 'true', true)");
      for (const definition of definitions) {
        const user = users[definition.key];
        const teen = definition.role === "teen";
        const marketplaceRole = definition.role === "teen" || definition.role === "adult" || definition.identityVerified === true;
        const identityStatus = definition.identityStatus ?? (definition.identityVerified === false ? "unverified" : "verified");
        const identityVerified = marketplaceRole && identityStatus === "verified";
        await database.query(
          `
            update public.profiles
            set role = $2::public.user_role,
                display_name = $3,
                username = $4,
                dob = $5::date,
                city = 'Indianapolis',
                state = 'IN',
                onboarding_completed = true,
                account_status = 'active',
                verification_status = $6::public.verification_status,
                payment_preference = 'cash',
                guardian_setup_status = case when $2 = 'teen' then 'skipped' else guardian_setup_status end,
                is_test_account = $7,
                updated_at = now()
            where id = $1
          `,
          [
            user.id,
            definition.role,
            `QA ${definition.key}`,
            `qa_${definition.key}_${suffix.replaceAll("-", "_")}`.slice(0, 40),
            teen ? "2011-01-15" : "1990-01-15",
            identityVerified ? "approved" : "not_started",
            user.isTest,
          ],
        );
        if (definition.role === "teen") {
          await database.query(
            `
              insert into public.teen_profiles (
                user_id, guardian_approval_required, paused_by_guardian
              ) values ($1, false, false)
              on conflict (user_id) do update
              set guardian_approval_required = false,
                  paused_by_guardian = false,
                  pause_reason = null
            `,
            [user.id],
          );
        } else if (definition.role === "adult") {
          await database.query(
            "insert into public.adult_profiles (user_id) values ($1) on conflict (user_id) do nothing",
            [user.id],
          );
        } else if (definition.role === "guardian") {
          await database.query(
            "insert into public.guardian_profiles (user_id) values ($1) on conflict (user_id) do nothing",
            [user.id],
          );
        }
        if (marketplaceRole && identityStatus !== "unverified") {
          await database.query(
            `
              insert into public.identity_verifications (
                user_id, account_role, evidence_route, provider,
                provider_reference, environment, decision_source, status,
                verification_level, age_band, identity_match_result,
                liveness_result, email_verification_result,
                address_validation_result, enhanced_screening_status,
                submitted_at, reviewed_at, verified_at, expires_at, risk_flags
              ) values (
                $1, $2::public.user_role, 'legacy_approved_record',
                'mort_isolated_qa', 'qa-' || gen_random_uuid()::text,
                'sandbox', 'sandbox_simulation', $3::public.identity_verification_state,
                $4, $5, $6, $7, 'verified', $8, 'not_enabled',
                now(), case when $3 in ('verified', 'verification_rejected', 'verification_suspended') then now() else null end,
                case when $3 = 'verified' then now() else null end,
                case when $3 = 'verified' then now() + interval '30 days'
                     when $3 = 'verification_expired' then now() - interval '1 minute'
                     else null end,
                jsonb_build_object(
                  'isolated_qa', true,
                  'scope', $9::text,
                  'documents_collected', false,
                  'production_eligible', false
                )
              )
            `,
            [
              user.id,
              definition.role,
              identityStatus,
              identityVerified ? (teen ? 2 : 3) : 0,
              teen ? "teen_13_17" : "adult_18_plus",
              identityVerified ? "matched" : "not_checked",
              identityVerified ? "passed" : "not_checked",
              identityVerified && !teen ? "validated_private" : "not_required",
              scope,
            ],
          );
        }
      }
      await database.query("commit");
    } catch (error) {
      await database.query("rollback").catch(() => {});
      throw error;
    } finally {
      await database.end();
    }

    for (const definition of definitions) {
      const client = createClient(supabaseUrl, anonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const { data, error } = await client.auth.signInWithPassword({
        email: users[definition.key].email,
        password,
      });
      if (error || data.user?.id !== users[definition.key].id) {
        throw new Error(`Could not sign in ${definition.key} QA user: ${error?.message}`);
      }
      users[definition.key].client = client;
    }

    qaLog(scope, `created and authenticated ${definitions.length} isolated QA users`);
    await run(users);
  } finally {
    if (created.length > 0) {
      try {
        await cleanupQaRestrictedData(created.map((user) => user.id));
      } catch (error) {
        console.error(`[${scope}] restricted cleanup warning: ${error.message}`);
      }
    }
    const cleanupOrder = [...created].sort((left, right) => {
      const priority = { teen: 0, guardian: 1, adult: 2, admin: 3 };
      return (priority[left.role] ?? 9) - (priority[right.role] ?? 9);
    });
    for (const user of cleanupOrder) {
      const { error } = await serviceClient.auth.admin.deleteUser(user.id, false);
      if (error) {
        console.error(`[${scope}] cleanup warning: ${error.message}`);
      }
    }
    if (created.length > 0) {
      qaLog(scope, "removed only the QA users created by this run");
    }
  }
}

export async function saveJob(client, overrides = {}, publish = true) {
  const clientRequestId = overrides.client_request_id ?? randomUUID();
  const payload = {
    title: "QA Feature Library Organizing",
    summary: "Organize labeled books at a staffed public library.",
    description:
      "Sort labeled books onto marked shelves during daytime hours with an adult staff member present.",
    category: "organization",
    estimated_duration_minutes: 90,
    workers_needed: 1,
    experience_level: "any",
    skills_needed: ["organization"],
    equipment_provided: "Labels and cart",
    equipment_worker_brings: "Closed-toe shoes",
    physical_requirements: ["standing"],
    proof_expected: false,
    special_instructions: "Check in with the front desk on arrival.",
    schedule_type: "flexible",
    starts_at: null,
    ends_at: null,
    deadline_at: null,
    recurring: false,
    recurrence_rule: null,
    timezone: "America/Indianapolis",
    urgency: "normal",
    location_text: "Downtown library area",
    city: "Indianapolis",
    state: "IN",
    neighborhood: "Downtown",
    zip_code: "46204",
    travel_radius_miles: 5,
    work_environment: "indoor",
    location_type: "public",
    pay_amount_cents: 1800,
    payment_type: "fixed",
    payment_method: "cash",
    payment_timing: "after_completion",
    tip_allowed: false,
    teen_min_age: 13,
    teen_max_age: 17,
    adult_supervision_present: true,
    verification_requirement: "none",
    requires_guardian_approval: false,
    safety_notes: "Stay in public staff areas.",
    ...overrides,
  };
  delete payload.client_request_id;
  delete payload.job_id;

  const { data, error } = await client.rpc("save_job_draft_or_publish", {
    p_job_id: overrides.job_id ?? null,
    p_client_request_id: clientRequestId,
    p_payload: payload,
    p_publish: publish,
  });
  if (error) throw new Error(`save_job_draft_or_publish failed: ${error.message}`);
  return { result: data, clientRequestId, payload };
}

export async function confirmSafetyAgreement(teenClient, adultClient, applicationId) {
  const agreement = await teenClient
    .from("job_safety_agreements")
    .select("agreement_version")
    .eq("application_id", applicationId)
    .single();
  if (agreement.error || !agreement.data) {
    throw new Error(`Could not load mutual Safety Agreement: ${agreement.error?.message}`);
  }

  const teenConfirmation = await teenClient.rpc("confirm_job_safety_agreement", {
    p_application_id: applicationId,
    p_agreement_version: agreement.data.agreement_version,
  });
  if (teenConfirmation.error || teenConfirmation.data?.ok !== true) {
    throw new Error(
      `Teen Safety Agreement confirmation failed: ${teenConfirmation.error?.message ?? teenConfirmation.data?.code}`,
    );
  }

  const adultConfirmation = await adultClient.rpc("confirm_job_safety_agreement", {
    p_application_id: applicationId,
    p_agreement_version: agreement.data.agreement_version,
  });
  if (
    adultConfirmation.error ||
    adultConfirmation.data?.ok !== true ||
    adultConfirmation.data?.status !== "confirmed"
  ) {
    throw new Error(
      `Adult Safety Agreement confirmation failed: ${adultConfirmation.error?.message ?? adultConfirmation.data?.code}`,
    );
  }
  return adultConfirmation.data;
}
