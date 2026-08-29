// Canonical regression for the account-deletion FK disposition matrix
// (docs/ACCOUNT_DELETION_FK_MATRIX.md). Two layers:
//
// 1. A schema-wide safety net (every foreign key pointing at
//    public.profiles/auth.users, not just the 87 originally broken ones):
//    fail on any RESTRICT/NO ACTION (the exact defect class this migration
//    fixes -- Postgres's silent default for an omitted ON DELETE clause),
//    and fail on any SET NULL relation whose column is still NOT NULL
//    (would throw at runtime the moment a row needs nulling). This is what
//    stops a future `new_table.user_id references profiles(id)` migration
//    from silently reintroducing the bug, regardless of whether anyone
//    remembers to add it to the list below.
// 2. An exact-match regression for the 87 formerly-blocking relationships
//    this session individually classified, plus critical pre-existing
//    relationships whose cascade semantics were audited along the way --
//    catches someone changing one of *those specific*
//    dispositions without updating docs/ACCOUNT_DELETION_FK_MATRIX.md.
//
// Layer 1 alone would pass for any newly-added CASCADE/SET NULL FK even if
// nobody thought about whether that's the right disposition for it -- that's
// intentional. Requiring every one of ~300 pre-existing, already-safe
// relationships in this schema to carry an individual class letter here
// would make this file an unmaintainable copy of the whole schema; layer 1's
// blanket RESTRICT/nullability checks already give the actual safety
// guarantee (deletion cannot silently become blocked, and SET NULL relations
// cannot silently become deletion-breaking) for all of them.
//
// Runs against local (set SUPABASE_DB_URL, e.g.
// postgresql://postgres:postgres@127.0.0.1:54322/postgres) or hosted (set
// SUPABASE_DB_PASSWORD; connects to db.rakjydmgwwgtdislanbt.supabase.co).
import pg from "pg";

const projectRef = "rakjydmgwwgtdislanbt";

function fail(message) {
  console.error(`FK contract failed: ${message}`);
}

// key: "schema.table.column" (schema always included, even "public", so
// this matches the query below regardless of search_path quirks in
// ::regclass::text casting). class: 'A' = CASCADE, 'B'/'D' = SET NULL.
// See docs/ACCOUNT_DELETION_FK_MATRIX.md for the full per-row rationale.
const CLASSIFIED = {
  "public.account_ban_appeals.user_id": "B",
  "public.account_ban_appeals.assigned_reviewer_id": "B",
  "public.admin_role_assignments.user_id": "A",
  "public.appearance_review_assignments.assigned_by": "B",
  "public.appearance_review_assignments.reviewer_id": "B",
  "public.appearance_review_cases.subject_user_id": "B",
  "public.appearance_review_decisions.reviewer_id": "B",
  "public.completion_evidence_records.submitted_by": "B",
  "public.document_capture_sessions.subject_user_id": "B",
  "public.document_review_assignments.assigned_by": "B",
  "public.document_review_assignments.reviewer_id": "B",
  "public.document_review_decisions.reviewer_id": "B",
  "public.document_web_reuse_requests.subject_user_id": "B",
  "public.identity_verification_evidence.user_id": "B",
  "public.incident_actions.actor_id": "B",
  "public.incident_assignments.assigned_by": "B",
  "public.incident_assignments.assigned_to": "B",
  "public.incident_contact_attempts.actor_id": "B",
  "public.incident_outcomes.decided_by": "B",
  "public.incident_preservation_orders.ordered_by": "B",
  "public.job_arrival_handshakes.finish_confirmed_by": "B",
  "public.job_arrival_handshakes.finish_requested_by": "B",
  "public.job_arrival_handshakes.start_confirmed_by": "B",
  "public.job_completion_assertions.asserted_by": "B",
  "public.job_contract_acceptances.user_id": "B",
  "public.job_contract_change_acceptances.user_id": "B",
  "public.job_contract_change_requests.requested_by": "B",
  "public.job_contract_versions.created_by": "B",
  "public.job_contracts.adult_id": "B",
  "public.job_contracts.teen_id": "B",
  "public.job_execution_cancellations.actor_id": "B",
  "public.job_payment_obligations.obligated_poster_id": "B",
  "public.job_payment_obligations.worker_id": "B",
  "public.jobs.poster_id": "B",
  "public.applications.teen_id": "B",
  "public.guardian_connection_audit_events.teen_id": "B",
  "public.guardian_connections.guardian_id": "A",
  "public.guardian_connections.teen_id": "A",
  "public.legal_acceptance_audit_events.user_id": "B",
  "public.legal_acceptances.user_id": "B",
  "public.legal_declines.user_id": "B",
  "public.legal_reacceptance_requirements.user_id": "B",
  "public.live_presence_challenges.subject_user_id": "B",
  "public.message_safety_evidence.sender_id": "B",
  "public.partner_invite_codes.created_by": "B",
  "public.partner_memberships.user_id": "A",
  "public.partner_permissions.granted_by": "B",
  "public.partner_staff.user_id": "A",
  "public.payment_confirmation_records.confirmed_by": "B",
  "public.payment_dispute_appeals.appellant_id": "B",
  "public.payment_dispute_appeals.reviewed_by": "B",
  "public.payment_dispute_assignments.assigned_by": "B",
  "public.payment_dispute_assignments.reviewer_id": "B",
  "public.payment_dispute_decisions.reviewer_id": "B",
  "public.payment_dispute_evidence.submitted_by": "B",
  "public.payment_dispute_statements.author_id": "B",
  "public.payment_dispute_timeline.actor_id": "B",
  "public.payment_disputes.opened_by": "B",
  "public.payment_disputes.poster_id": "B",
  "public.payment_disputes.worker_id": "B",
  "public.payment_evidence_export_events.requested_by": "B",
  "public.poster_payment_restrictions.imposed_by": "B",
  "public.poster_payment_restrictions.lifted_by": "B",
  "public.poster_payment_restrictions.poster_id": "B",
  "private.document_vault_access_grants.reviewer_id": "B",
  "private.first_party_trust_control.enabled_by": "B",
  "private.identity_verification_webhook_events.user_id": "B",
  "private.stripe_account_onboarding_sessions.user_id": "B",
  "private.stripe_connected_accounts.user_id": "D",
  "private.stripe_customers.user_id": "D",
  "private.stripe_financial_role_assignments.assigned_by": "B",
  "private.stripe_financial_role_assignments.user_id": "A",
  "private.stripe_job_payment_attempts.initiated_by": "B",
  "private.stripe_job_payment_intents.adult_id": "D",
  "private.stripe_job_payment_intents.teen_id": "D",
  "private.stripe_payment_resolutions.financial_operator_id": "B",
  "private.stripe_payment_resolutions.reviewer_id": "B",
  "private.support_staff_assignments.assigned_by": "B",
  "private.support_staff_assignments.user_id": "A",
  "public.safety_cancellations.actor_id": "B",
  "public.support_attachments.owner_id": "B",
  "public.support_evidence_attachments.owner_id": "B",
  "public.support_internal_notes.author_id": "B",
  "public.support_ticket_appeals.requester_id": "B",
  "public.team_access_audit_events.user_id": "B",
  "public.team_confidentiality_acknowledgements.user_id": "B",
  "public.team_conflict_disclosures.reviewed_by": "B",
  "public.team_conflict_disclosures.user_id": "B",
  "public.team_device_compliance.reviewed_by": "B",
  "public.team_device_compliance.user_id": "B",
  "public.team_role_assignments.approved_by": "B",
  "public.team_role_assignments.revoked_by": "B",
  "public.team_role_assignments.user_id": "A",
  "public.team_training_completions.approved_by": "B",
  "public.team_training_completions.user_id": "B",
  "public.teen_abandonment_reports.decided_by": "B",
  "public.teen_abandonment_reports.reported_by_adult_id": "B",
  "public.teen_abandonment_reports.teen_id": "B",
  "public.account_deletion_requests.user_id": "B",
};

const CLASS_TO_ON_DELETE = { A: "CASCADE", B: "SET NULL", D: "SET NULL" };

async function main() {
  const connectionString =
    process.env.SUPABASE_DB_URL ??
    (() => {
      const password = process.env.SUPABASE_DB_PASSWORD;
      if (!password) {
        fail("Set SUPABASE_DB_URL (local) or SUPABASE_DB_PASSWORD (hosted).");
        process.exit(1);
      }
      return `postgresql://postgres:${encodeURIComponent(password)}@db.${projectRef}.supabase.co:5432/postgres`;
    })();

  const database = new pg.Client({
    connectionString,
    ssl: connectionString.includes("supabase.co") ? { rejectUnauthorized: false } : undefined,
  });
  await database.connect();
  try {
    const result = await database.query(`
      select
        n.nspname as schema_name,
        con.conrelid::regclass::text as unqualified_table,
        a.attname as column_name,
        case con.confdeltype
          when 'c' then 'CASCADE' when 'n' then 'SET NULL'
          when 'r' then 'RESTRICT' when 'a' then 'NO ACTION' when 'd' then 'SET DEFAULT'
        end as on_delete,
        not a.attnotnull as nullable
      from pg_constraint con
      join pg_attribute a on a.attrelid = con.conrelid and a.attnum = any(con.conkey)
      join pg_class c on c.oid = con.conrelid
      join pg_namespace n on n.oid = c.relnamespace
      where con.contype = 'f'
        and con.confrelid in ('public.profiles'::regclass, 'auth.users'::regclass)
      order by schema_name, unqualified_table, column_name
    `);

    let failures = 0;
    const seenClassified = new Set();

    for (const row of result.rows) {
      const bareTable = row.unqualified_table.includes(".")
        ? row.unqualified_table.split(".").pop()
        : row.unqualified_table;
      const key = `${row.schema_name}.${bareTable}.${row.column_name}`;
      const label = `${row.schema_name}.${bareTable}.${row.column_name}`;

      // Layer 1: schema-wide safety net, applies to every relation.
      if (row.on_delete === "RESTRICT" || row.on_delete === "NO ACTION") {
        fail(`${label} is ${row.on_delete} -- this is exactly the defect class this migration exists to fix. Classify it in docs/ACCOUNT_DELETION_FK_MATRIX.md and add it to CLASSIFIED below.`);
        failures += 1;
        continue;
      }
      if (row.on_delete === "SET NULL" && !row.nullable) {
        fail(`${label} is SET NULL but the column is still NOT NULL -- deletion would throw at runtime the first time this needs to null out.`);
        failures += 1;
        continue;
      }

      // Layer 2: exact-match regression for relationships this session
      // deliberately classified.
      const classification = CLASSIFIED[key];
      if (classification) {
        seenClassified.add(key);
        const expectedOnDelete = CLASS_TO_ON_DELETE[classification];
        if (row.on_delete !== expectedOnDelete) {
          fail(`${label} is classified ${classification} (expects ${expectedOnDelete}) but the live schema has ${row.on_delete} -- drifted from docs/ACCOUNT_DELETION_FK_MATRIX.md.`);
          failures += 1;
        }
      }
    }

    for (const key of Object.keys(CLASSIFIED)) {
      if (!seenClassified.has(key)) {
        fail(`${key} is classified in this script but no longer exists in the live schema (or is no longer SET NULL/CASCADE) -- stale entry, remove it here and from the matrix doc.`);
        failures += 1;
      }
    }

    if (failures === 0) {
      console.log(`[qa-account-deletion-fk-contract] PASS: ${result.rows.length} user-linked foreign keys checked, 0 RESTRICT/NO ACTION, 0 SET-NULL-but-NOT-NULL contradictions, ${seenClassified.size}/${Object.keys(CLASSIFIED).length} explicitly classified relationships match the matrix.`);
    } else {
      process.exitCode = 1;
    }
  } finally {
    await database.end();
  }
}

await main();
