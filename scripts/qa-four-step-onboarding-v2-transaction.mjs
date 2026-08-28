import { readFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";

import {
  assertQa,
  qaLog,
  withDatabase,
  withQaUsers,
} from "./feature-qa-helpers.mjs";

const scope = "qa-four-step-onboarding-v2-transaction";
const migrationSql = await readFile(
  new URL("../supabase/migrations/20260828023033_four_step_onboarding_v2.sql", import.meta.url),
  "utf8",
);

function resultOf(queryResult) {
  return queryResult.rows[0]?.result;
}

await withQaUsers(
  scope,
  [{ key: "teen", role: "teen", identityVerified: false }],
  async ({ teen }) => {
    await withDatabase(async (database) => {
      await database.query("begin");
      try {
        await database.query(migrationSql);
        await database.query("select set_config('mort.internal_update', 'true', true)");
        for (const table of [
          "private.onboarding_v2_requests",
          "private.onboarding_v2_safety",
          "public.legal_acceptance_audit_events",
          "public.legal_acceptances",
          "public.onboarding_progress_events",
          "public.onboarding_acknowledgements",
          "public.onboarding_progress",
        ]) {
          await database.query(`delete from ${table} where user_id = $1`, [teen.id]);
        }
        await database.query(
          `update public.profiles
           set role = null, display_name = null, username = null, dob = null,
               city = null, state = null, onboarding_completed = false,
               availability = null, preferred_job_categories = '{}',
               transportation_methods = '{}', guardian_setup_status = 'not_started',
               updated_at = now()
           where id = $1`,
          [teen.id],
        );
        await database.query(
          "select set_config('request.jwt.claims', $1, true)",
          [JSON.stringify({ sub: teen.id, role: "authenticated" })],
        );

        const initial = resultOf(
          await database.query(
            "select public.get_my_onboarding_progress_v2() as result",
          ),
        );
        assertQa(initial.active_step === "account", "transactional user did not start at account");
        assertQa(
          JSON.stringify(initial.primary_steps) ===
            JSON.stringify(["account", "work_preferences", "safety_support", "review"]),
          "transactional primary-step contract changed",
        );

        const accountPayload = {
          role: "teen",
          display_name: "QA Four Step Teen",
          username: `qa_v2_tx_${Date.now().toString(36)}`.slice(0, 24),
          dob: "2010-05-10",
          city: "Indianapolis",
          state: "IN",
          location_setup_mode: "city_state",
          adult_account_type: null,
          business_name: null,
          approximate_area: "Indianapolis, IN",
        };
        const accountRequestId = randomUUID();
        const account = resultOf(
          await database.query(
            "select public.save_my_onboarding_account_v2($1::jsonb, $2::uuid, 1) as result",
            [accountPayload, accountRequestId],
          ),
        );
        assertQa(account.ok && account.active_step === "work_preferences", "account save did not advance");
        const replay = resultOf(
          await database.query(
            "select public.save_my_onboarding_account_v2($1::jsonb, $2::uuid, 1) as result",
            [accountPayload, accountRequestId],
          ),
        );
        assertQa(replay.ok && replay.replayed, "same-payload account replay was not idempotent");
        const mismatch = resultOf(
          await database.query(
            "select public.save_my_onboarding_account_v2($1::jsonb, $2::uuid, 1) as result",
            [{ ...accountPayload, display_name: "Different QA Teen" }, accountRequestId],
          ),
        );
        assertQa(
          mismatch.code === "onboarding_request_payload_mismatch",
          "mismatched replay was accepted",
        );

        const beforeWorkCompletion = resultOf(
          await database.query(
            "select public.complete_my_onboarding_v2($1::jsonb, $2::uuid, 1, $3) as result",
            [{ legal_version_ids: [] }, randomUUID(), account.revision],
          ),
        );
        assertQa(
          beforeWorkCompletion.code === "onboarding_work_preferences_required",
          "completion trusted a progress hint instead of canonical work data",
        );

        const work = resultOf(
          await database.query(
            "select public.save_my_onboarding_work_v2($1::jsonb, $2::uuid, 1, $3) as result",
            [
              {
                availability: "Weekday evenings",
                preferred_job_categories: ["Yard work"],
                transportation_methods: ["walking"],
                max_travel_distance_miles: null,
                max_travel_minutes: null,
                walking_distance_only: false,
                guardian_transportation_possible: false,
              },
              randomUUID(),
              account.revision,
            ],
          ),
        );
        assertQa(work.ok && work.active_step === "safety_support", "work save did not advance");

        const safety = resultOf(
          await database.query(
            "select public.save_my_onboarding_safety_v2($1::jsonb, $2::uuid, 1, $3) as result",
            [
              { notification_intent: "ask_later", guardian_choice: "skip" },
              randomUUID(),
              work.revision,
            ],
          ),
        );
        assertQa(safety.ok && safety.active_step === "review", "safety save did not advance");

        let directUpdateDenied = false;
        await database.query("savepoint direct_completion_update");
        try {
          await database.query(
            "update public.profiles set onboarding_completed = true where id = $1",
            [teen.id],
          );
        } catch (error) {
          directUpdateDenied = error.message.includes("onboarding_completion_rpc_required");
          await database.query("rollback to savepoint direct_completion_update");
        }
        assertQa(directUpdateDenied, "direct completion UPDATE was accepted");

        let directUpsertDenied = false;
        await database.query("savepoint direct_completion_upsert");
        try {
          await database.query(
            `insert into public.profiles
             select * from public.profiles where id = $1
             on conflict (id) do update set onboarding_completed = true`,
            [teen.id],
          );
        } catch (error) {
          directUpsertDenied = error.message.includes("onboarding_completion_rpc_required");
          await database.query("rollback to savepoint direct_completion_upsert");
        }
        assertQa(directUpsertDenied, "direct completion UPSERT was accepted");

        let malformedDenied = false;
        await database.query("savepoint malformed_completion");
        try {
          await database.query(
            "select set_config('mort.onboarding_completion', 'malformed', true)",
          );
          await database.query(
            "update public.profiles set onboarding_completed = true where id = $1",
            [teen.id],
          );
        } catch (error) {
          malformedDenied = error.message.includes("onboarding_completion_rpc_required");
          await database.query("rollback to savepoint malformed_completion");
        }
        assertQa(malformedDenied, "malformed completion session was accepted");

        const legal = resultOf(
          await database.query("select public.get_my_legal_requirements() as result"),
        );
        const versionIds = (legal.requirements ?? [])
          .filter((requirement) => requirement.required && !requirement.acceptance_id)
          .map((requirement) => requirement.version_id);
        const completion = resultOf(
          await database.query(
            "select public.complete_my_onboarding_v2($1::jsonb, $2::uuid, 1, $3) as result",
            [
              {
                legal_version_ids: versionIds,
                teen_summary_viewed: true,
                signature: "QA Four Step Teen",
                platform: "qa_node",
                app_version: "rollback-contract",
              },
              randomUUID(),
              safety.revision,
            ],
          ),
        );
        const unavailablePolicies = await database.query(
          `with current_versions as (
             select distinct on (version.document_id) version.document_id
             from public.legal_document_versions version
             join public.legal_documents document on document.id = version.document_id
             where document.publication_status = 'published'
               and version.publication_status = 'published'
               and version.effective_at <= now()
             order by version.document_id, version.effective_at desc, version.created_at desc
           )
           select document.document_key
           from public.legal_role_requirements requirement
           join public.legal_documents document on document.id = requirement.document_id
           left join current_versions current_version on current_version.document_id = document.id
           where requirement.role = 'teen'
             and requirement.age_band in ('all', 'teen_16_17')
             and requirement.required
             and current_version.document_id is null
           order by requirement.priority`,
        );
        if (unavailablePolicies.rowCount > 0) {
          assertQa(
            !completion.ok && completion.code === "published_legal_acceptance_required",
            "completion bypassed unavailable required public policy versions",
          );
          qaLog(
            scope,
            `completion remained closed because ${unavailablePolicies.rowCount} required policy versions are not published`,
          );
        } else {
          assertQa(completion.ok && completion.completed, `valid completion failed: ${completion.code}`);
          assertQa(completion.active_step === "complete", "completion did not return terminal state");
        }

        await database.query("rollback");
        qaLog(scope, "rollback-only canonical projection, replay, guard, legal, and completion checks passed");
      } catch (error) {
        await database.query("rollback").catch(() => {});
        throw error;
      }
    });
  },
);
