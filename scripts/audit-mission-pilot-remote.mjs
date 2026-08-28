import pg from "pg";

const projectRef = "rakjydmgwwgtdislanbt";
const password = process.env.SUPABASE_DB_PASSWORD;

if (!password) throw new Error("SUPABASE_DB_PASSWORD is required.");

const missionTables = [
  "partner_staff",
  "partner_permissions",
  "partner_attestations",
  "pilot_enrollments",
  "pilot_participant_acknowledgements",
  "pilot_job_reviews",
  "document_review_cases",
  "document_review_assignments",
  "document_review_decisions",
  "document_review_appeals",
  "discreet_mode_preferences",
  "trusted_devices",
  "support_circles",
  "support_circle_members",
  "support_circle_permissions",
  "support_circle_alert_events",
  "work_earning_entries",
  "independence_goals",
  "future_independence_plans",
  "future_independence_tasks",
  "skill_passport_entries",
  "work_reference_requests",
  "resource_directory_entries",
  "private_resource_bookmarks",
  "resource_directory_reports",
];

const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

await client.connect();
try {
  const policy = await one(`
    select pilot_mode_enabled,
           unrestricted_public_access_enabled,
           real_document_collection_enabled,
           guardian_mode_optional,
           maximum_document_signed_url_seconds
    from private.current_pilot_policy()
  `);
  const readiness = await one(`
    select count(*)::int required,
           count(*) filter (where passed)::int passed
    from private.document_operational_readiness_gates
  `);
  const tables = await client.query(
    `
      select c.relname as table_name,
             c.relrowsecurity as rls_enabled,
             count(policy.policyname)::int as policy_count,
             has_table_privilege('anon', c.oid, 'SELECT') as anon_select,
             has_table_privilege('anon', c.oid, 'INSERT') as anon_insert,
             has_table_privilege('anon', c.oid, 'UPDATE') as anon_update,
             has_table_privilege('anon', c.oid, 'DELETE') as anon_delete
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      left join pg_policies policy
        on policy.schemaname = n.nspname and policy.tablename = c.relname
      where n.nspname = 'public' and c.relname = any($1::text[])
      group by c.oid, c.relname, c.relrowsecurity
      order by c.relname
    `,
    [missionTables],
  );
  const bucket = await one(`
    select id, public, file_size_limit, allowed_mime_types,
           (select count(*)::int from storage.objects object_record where object_record.bucket_id = bucket.id) object_count
    from storage.buckets bucket
    where id = 'mort-document-vault'
  `);
  const vaultPolicies = await one(`
    select count(*)::int policy_count
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and (coalesce(qual, '') ilike '%mort-document-vault%'
        or coalesce(with_check, '') ilike '%mort-document-vault%')
  `);
  const functions = await client.query(`
    select p.proname as function_name,
           p.prosecdef as security_definer,
           coalesce(array_to_string(p.proconfig, ','), '') as configuration,
           has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
           has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(array[
        'get_closed_pilot_eligibility',
        'get_document_collection_readiness',
        'request_document_vault_access',
        'consume_document_vault_access_grant',
        'get_mission_pilot_dashboard',
        'get_private_work_summary'
      ])
    order by p.proname
  `);
  const privacy = await one(`
    select
      count(*) filter (where column_name in (
        'housing_status', 'homeless_status', 'shelter_name',
        'abuse_status', 'foster_status'
      ))::int as prohibited_public_columns,
      count(*) filter (
        where table_name = 'profiles' and column_name = 'location_setup_mode'
      )::int as location_mode_columns
    from information_schema.columns
    where table_schema = 'public'
  `);
  const qaResidue = await one(`
    select count(*)::int qa_user_count,
           count(*) filter (where created_at > now() - interval '30 minutes')::int recent_qa_user_count,
           min(created_at) as earliest_qa_user_created_at,
           max(created_at) as latest_qa_user_created_at
    from auth.users
    where email like '%@mort.test'
  `);
  const documentRows = await one(`
    select count(*) filter (where contains_real_person_data)::int real_person_case_count
    from public.document_review_cases
  `);

  const summary = {
    projectRef,
    policy,
    readiness,
    missionTableCount: tables.rows.length,
    missionTablesMissingRls: tables.rows.filter((row) => !row.rls_enabled).length,
    missionTablesWithAnonPrivileges: tables.rows.filter(
      (row) => row.anon_select || row.anon_insert || row.anon_update || row.anon_delete,
    ).length,
    missionTablesWithoutPolicies: tables.rows
      .filter((row) => row.policy_count === 0)
      .map((row) => row.table_name),
    bucket,
    vaultStoragePolicyCount: vaultPolicies.policy_count,
    functions: functions.rows,
    privacy,
    qaResidue,
    documentRows,
  };
  console.log(JSON.stringify(summary, null, 2));
} finally {
  await client.end();
}

async function one(sql) {
  const result = await client.query(sql);
  return result.rows[0] ?? {};
}
