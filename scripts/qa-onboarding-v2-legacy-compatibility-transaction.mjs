// RETIRED (2026-08-28): this was a pre-deployment rehearsal harness that dry-runs
// the compatibility migration's raw SQL inside a rolled-back transaction against
// synthetic users, to validate the migration before it was applied to production.
// It served that purpose and passed. The migration
// (20260828111951_onboarding_v2_legacy_completion_compatibility.sql) is now
// permanently applied to the hosted database, so replaying its `create table`
// statement fails with "already exists" (42P07) in any environment that already
// has the migration -- including a fresh Supabase branch, which replays full
// migration history. This script cannot be re-run and is excluded from the
// ongoing regression matrix. Ongoing legacy-completion compatibility regression
// coverage lives in qa-onboarding-v2-legacy-compatibility.mjs, which runs against
// the live hosted schema and is safe to re-run indefinitely.
import { readdir, readFile } from "node:fs/promises";

import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-onboarding-v2-legacy-compatibility-transaction";
const migrationSuffix = "_onboarding_v2_legacy_completion_compatibility.sql";
const tableName = "private.onboarding_v2_legacy_completion_compatibility";

const migrationNames = (await readdir(new URL("../supabase/migrations/", import.meta.url)))
  .filter((name) => name.endsWith(migrationSuffix));
assertQa(
  migrationNames.length === 1,
  `expected exactly one ${migrationSuffix} migration, found ${migrationNames.length}`,
);
const migrationSql = await readFile(
  new URL(`../supabase/migrations/${migrationNames[0]}`, import.meta.url),
  "utf8",
);

function resultOf(queryResult) {
  return queryResult.rows[0]?.result;
}

async function expectDenied(database, label, statement, values = []) {
  await database.query(`savepoint ${label}`);
  let denied = false;
  try {
    await database.query(statement, values);
  } catch (error) {
    denied = error.code === "42501" || /permission denied|row-level security/i.test(error.message);
    await database.query(`rollback to savepoint ${label}`);
  }
  assertQa(denied, `${label} was not denied`);
}

await withQaUsers(
  scope,
  [
    { key: "historical", role: "teen", identityVerified: false },
    { key: "incomplete", role: "adult", identityVerified: false },
    { key: "future", role: "guardian", identityVerified: false },
  ],
  async ({ historical, incomplete, future }) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query("select set_config('mort.internal_update', 'true', true)");
        await database.query(
          `update public.profiles
           set username = null, availability = null,
               preferred_job_categories = '{}', transportation_methods = '{}',
               verification_status = 'not_started'
           where id = $1`,
          [historical.id],
        );
        await database.query(
          `update public.profiles
           set onboarding_completed = false, display_name = null, username = null,
               dob = null, role = null, availability = null,
               preferred_job_categories = '{}', transportation_methods = '{}'
           where id = $1`,
          [incomplete.id],
        );
        await database.query(
          "update public.profiles set onboarding_completed = false where id = $1",
          [future.id],
        );

        const protectedBefore = (
          await database.query(
            `select role::text, dob::text, verification_status::text
             from public.profiles where id = $1`,
            [historical.id],
          )
        ).rows[0];

        await database.query(migrationSql);

        const snapshotMembership = await database.query(
          `select
             count(*) filter (where user_id = $1)::int as historical,
             count(*) filter (where user_id = $2)::int as incomplete,
             count(*) filter (where user_id = $3)::int as future
           from ${tableName}`,
          [historical.id, incomplete.id, future.id],
        );
        assertQa(snapshotMembership.rows[0].historical === 1, "historical completion was not snapshotted");
        assertQa(snapshotMembership.rows[0].incomplete === 0, "historically incomplete user was grandfathered");
        assertQa(snapshotMembership.rows[0].future === 0, "future user was grandfathered at cutover");

        const grandfathered = resultOf(
          await database.query("select private.evaluate_onboarding_v2($1) as result", [historical.id]),
        );
        assertQa(grandfathered.completed === true, "grandfathered user did not remain complete");
        assertQa(grandfathered.active_step === "complete", "grandfathered user received an onboarding route");
        assertQa(
          JSON.stringify(grandfathered.completed_steps) ===
            JSON.stringify(["account", "work_preferences", "safety_support", "review"]),
          "grandfathered completion did not preserve the four-step contract",
        );
        assertQa(grandfathered.role === protectedBefore.role, "grandfathering changed or elevated role");

        const incompleteProgress = resultOf(
          await database.query("select private.evaluate_onboarding_v2($1) as result", [incomplete.id]),
        );
        assertQa(incompleteProgress.active_step === "account", "incomplete user did not use canonical v2 evaluation");

        const protectedAfter = (
          await database.query(
            `select role::text, dob::text, verification_status::text
             from public.profiles where id = $1`,
            [historical.id],
          )
        ).rows[0];
        assertQa(
          JSON.stringify(protectedAfter) === JSON.stringify(protectedBefore),
          "compatibility migration changed role, DOB, or verification state",
        );

        const legalSeparation = await database.query(
          `select exists (
             select 1
             from public.legal_role_requirements requirement
             where requirement.role = $2::public.user_role
               and requirement.required
               and not exists (
                 select 1
                 from public.legal_acceptances acceptance
                 join public.legal_document_versions version
                   on version.id = acceptance.document_version_id
                 where acceptance.user_id = $1
                   and version.document_id = requirement.document_id
                   and acceptance.active
               )
           ) as has_separate_unmet_legal_requirement`,
          [historical.id, protectedBefore.role],
        );
        assertQa(
          legalSeparation.rows[0].has_separate_unmet_legal_requirement,
          "legal reconsent fixture did not remain independently enforceable",
        );

        await database.query("set local role authenticated");
        await database.query(
          "select set_config('request.jwt.claims', $1, true)",
          [JSON.stringify({ sub: incomplete.id, role: "authenticated" })],
        );
        await expectDenied(
          database,
          "compat_insert_denied",
          `insert into ${tableName}(user_id, source_version) values ($1, 'malicious')`,
          [incomplete.id],
        );
        await expectDenied(
          database,
          "compat_update_denied",
          `update ${tableName} set source_version = 'malicious' where user_id = $1`,
          [historical.id],
        );
        await expectDenied(
          database,
          "compat_delete_denied",
          `delete from ${tableName} where user_id = $1`,
          [historical.id],
        );
        await database.query("reset role");

        await database.query("select set_config('mort.onboarding_completion', 'true', true)");
        await database.query(
          "update public.profiles set onboarding_completed = true where id = $1",
          [future.id],
        );
        const frozen = await database.query(
          `select exists (select 1 from ${tableName} where user_id = $1) as present`,
          [future.id],
        );
        assertQa(!frozen.rows[0].present, "normal future completion expanded the frozen snapshot");

        const duplicate = await database.query(
          `select count(*)::int as count from ${tableName} where user_id = $1`,
          [historical.id],
        );
        assertQa(duplicate.rows[0].count === 1, "snapshot contains duplicate user rows");

        await database.query("delete from auth.users where id = $1", [historical.id]);
        const orphan = await database.query(
          `select exists (select 1 from ${tableName} where user_id = $1) as present`,
          [historical.id],
        );
        assertQa(!orphan.rows[0].present, "account deletion left an orphaned compatibility identifier");

        await database.query("rollback");
        qaLog(scope, "rollback-only snapshot, evaluator, immutability, legal separation, and deletion checks passed");
      } catch (error) {
        await database.query("rollback").catch(() => {});
        throw error;
      }
    });
  },
);
