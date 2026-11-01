import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const applicationMigration = await readFile(
  "supabase/migrations/20261101120000_atomic_application_and_guardian_resend_contract.sql",
  "utf8",
);
const locationMigration = await readFile(
  "supabase/migrations/20261101123000_private_location_and_block_message_contract.sql",
  "utf8",
);
const schemaPreflightSql = await readFile(
  "supabase/tests/safety_contract_schema_preflight.sql",
  "utf8",
);
const schemaPreflightRunner = await readFile(
  "scripts/qa-safety-contract-schema-preflight.mjs",
  "utf8",
);

function includes(source, needle, label) {
  assert.ok(source.includes(needle), `missing ${label}: ${needle}`);
}
function excludes(source, needle, label) {
  assert.ok(!source.includes(needle), `unsafe ${label}: ${needle}`);
}

// Application submission must use an execution-time eligibility read and a
// complete lower-level locked recheck, not only a client-facing preflight.
includes(applicationMigration, "volatile", "volatile eligibility function");
includes(applicationMigration, "from public.jobs job\n  where job.id = p_job_id\n  for update", "locked application helper");
includes(applicationMigration, "create or replace function public.mort_submit_job_application", "lower-level application helper");

// Guardian resend must be link-scoped and must not call the broad revoke path.
includes(applicationMigration, "where link.id = p_link_id", "link-scoped Guardian lookup");
includes(applicationMigration, "where guardian_link_id = p_link_id and consumed_at is null", "link-scoped code consumption");
includes(applicationMigration, "v_rate_key := pg_catalog.hashtextextended(v_user_id::text, 0)", "per-teen Guardian resend rate lock");
includes(applicationMigration, "perform pg_catalog.pg_advisory_xact_lock(v_rate_key)", "serialized Guardian resend rate check");
includes(applicationMigration, "guardian_invite_code_missing", "missing Guardian code denial");
excludes(applicationMigration, "update public.guardian_links set status = 'revoked'", "bulk Guardian revocation");

// Location reads must fail closed for absent rows and bind confirmation to the
// exact location version that was saved.
includes(locationMigration, "coalesce(v_allowed, false) is not true", "NULL-safe location denial");
includes(locationMigration, "v_assignment.id is not null", "required assignment row");
includes(locationMigration, "v_agreement.id is not null", "required agreement row");
includes(locationMigration, "v_agreement.location_version = v_location.location_version", "location-version binding");
includes(locationMigration, "private.refresh_job_safety_agreement(v_application_id)", "live reconfirmation helper");
excludes(locationMigration, "status = 'pending'", "invalid safety-agreement status");

// Client writes must not reach jobs.exact_address or the private table, and
// the migration must not widen jobs reads to every RLS-visible column.
includes(locationMigration, "revoke insert, update on public.jobs from authenticated", "direct jobs write revoke");
includes(locationMigration, "from information_schema.column_privileges", "legacy column-level write grant cleanup");
includes(locationMigration, "privilege_type in ('INSERT', 'UPDATE')", "column write privilege filter");
includes(locationMigration, "revoke %s (%I) on table public.jobs from authenticated", "per-column write revoke");
excludes(locationMigration, "grant select on public.jobs to authenticated", "broad jobs table SELECT grant");
includes(locationMigration, "create table private.job_private_locations", "location table stays outside exposed schemas");
includes(locationMigration, "revoke all on private.job_private_locations from public, anon, authenticated", "private-table privilege revoke");

// Block, unblock, message, and conversation closure must share deterministic
// serialization primitives.
assert.equal((locationMigration.match(/pg_advisory_xact_lock/g) ?? []).length >= 3, true);
includes(locationMigration, "order by member.user_id", "deterministic participant lock order");
includes(locationMigration, "from public.conversations conversation\n  where conversation.id = p_conversation_id\n  for update", "conversation-row lock");
includes(locationMigration, "create or replace function public.unblock_user_v2", "locked unblock RPC");

// The read-only schema preflight must match the hosted Guardian foreign key
// name and require an explicit isolated staging project allowlist.
includes(schemaPreflightSql, "('public.guardian_links', 'teen_user_id')", "hosted Guardian teen column");
excludes(schemaPreflightSql, "('public.guardian_links', 'teen_id')", "legacy Guardian teen column");
includes(schemaPreflightRunner, "MORT_QA_ALLOWED_PROJECT_REF", "explicit isolated staging project ref");
includes(schemaPreflightRunner, "const expectedHost = `db.${allowedStagingRef}.supabase.co`", "staging database host binding");
includes(schemaPreflightRunner, "fileURLToPath", "Windows-compatible SQL file path");
includes(schemaPreflightRunner, "psqlEnvironment.PGPASSWORD", "database password kept out of process arguments");
includes(schemaPreflightRunner, "if (target === 'staging') psqlEnvironment.PGSSLMODE = 'require'", "TLS enforced for staging database");

for (const source of [applicationMigration, locationMigration]) {
  excludes(source, "public.is_profile_active(", "nonexistent hosted helper");
  excludes(source, "public.current_profile_role(", "nonexistent hosted helper");
  excludes(source, "public.check_rate_limit(", "nonexistent hosted helper");
  excludes(source, "public.record_rate_limit_event(", "nonexistent hosted helper");
}

console.log("[qa-safety-contracts-static] PASS");
