// Read-only database security catalog dump for a remote Supabase project.
// Usage:
//   MORT_AUDIT_PROJECT_REF=<ref> SUPABASE_DB_PASSWORD=<pw> [SUPABASE_ACCESS_TOKEN=<token>] \
//   node scripts/audit-db-security-remote.mjs <output-dir>
// Never prints credentials. Read-only queries only.

import pg from "pg";
import { mkdirSync, writeFileSync } from "node:fs";

const projectRef = process.env.MORT_AUDIT_PROJECT_REF;
const dbPassword = process.env.SUPABASE_DB_PASSWORD;
const accessToken = process.env.SUPABASE_ACCESS_TOKEN || "";
const outDir = process.argv[2] || `audit-output/${projectRef}`;

if (!projectRef) throw new Error("MORT_AUDIT_PROJECT_REF is required.");
if (!dbPassword) throw new Error("SUPABASE_DB_PASSWORD is required.");

mkdirSync(outDir, { recursive: true });

const client = new pg.Client({
  // Session pooler (IPv4-reachable) — the direct endpoint is IPv6-only.
  host: "aws-0-us-east-2.pooler.supabase.com",
  port: 5432,
  database: "postgres",
  user: `postgres.${projectRef}`,
  password: dbPassword,
  ssl: { rejectUnauthorized: false },
});

async function dump(name, sql) {
  const result = await client.query(sql);
  writeFileSync(`${outDir}/${name}.json`, JSON.stringify(result.rows, null, 2));
  return result.rows;
}

await client.connect();
try {
  writeFileSync(`${outDir}/meta.json`, JSON.stringify({
    project_ref: projectRef,
    generated_at: new Date().toISOString(),
    database: (await client.query("select current_database() d, current_user u, version() v")).rows[0],
  }, null, 2));

  // --- Functions: definition, security definer flag, owner, search_path config ---
  await dump("functions", `
    select n.nspname as schema_name,
           p.proname as function_name,
           pg_get_function_identity_arguments(p.oid) as identity_args,
           p.prokind as kind,
           p.prosecdef as security_definer,
           p.provolatile as volatility,
           pg_get_userbyid(p.proowner) as owner,
           coalesce((select array_agg(c) from unnest(p.proconfig) c where c like 'search_path%'), null) as search_path_config,
           pg_get_functiondef(p.oid) as definition
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
    order by n.nspname, p.proname, identity_args
  `);

  // --- Function privileges (who can EXECUTE) ---
  await dump("function_privileges", `
    select n.nspname as schema_name,
           p.proname as function_name,
           pg_get_function_identity_arguments(p.oid) as identity_args,
           coalesce(nullif(a.grantee, 0)::regrole::text, 'PUBLIC') as grantee,
           a.privilege_type
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    left join aclexplode(p.proacl) a on true
    where n.nspname in ('public', 'private')
    order by n.nspname, p.proname, identity_args, grantee
  `);

  // --- Tables: RLS status, live policies ---
  await dump("tables", `
    select n.nspname as schema_name,
           c.relname as table_name,
           c.relkind as kind,
           c.relrowsecurity as rls_enabled,
           (select count(*) from pg_policies pol
             where pol.schemaname = n.nspname and pol.tablename = c.relname) as live_policy_count,
           pg_get_userbyid(c.relowner) as owner
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and c.relkind in ('r', 'p')
    order by n.nspname, c.relname
  `);

  await dump("policies", `
    select schemaname, tablename, policyname, cmd, roles,
           qual, with_check, permissive
    from pg_policies
    where schemaname in ('public', 'private', 'storage')
    order by schemaname, tablename, policyname
  `);

  // --- Table privileges for API roles ---
  await dump("table_privileges", `
    select table_schema, table_name, privilege_type, string_agg(distinct grantee, ',') as grantees
    from information_schema.table_privileges
    where table_schema in ('public', 'private', 'storage')
      and grantee in ('authenticated', 'anon', 'service_role', 'public', 'postgres')
    group by table_schema, table_name, privilege_type
    order by table_schema, table_name, privilege_type
  `);

  // --- Storage buckets + policies ---
  await dump("storage_buckets", `
    select id, name, public, file_size_limit, allowed_mime_types, owner_id
    from storage.buckets
    order by name
  `);
  await dump("storage_policies", `
    select schemaname, tablename, policyname, cmd, roles, qual, with_check, permissive
    from pg_policies
    where schemaname = 'storage'
    order by tablename, policyname
  `);

  // --- Staff / admin / moderator assignments ---
  await dump("staff_role_assignments", `
    select ur.user_id, ur.role, ur.granted_at, ur.granted_by, u.email
    from private.user_roles ur
    left join auth.users u on u.id = ur.user_id
    order by ur.role, ur.granted_at
  `);
  try {
    await dump("admin_role_assignments", `
      select * from public.admin_role_assignments
      order by assigned_at
    `);
  } catch {
    // Table not present on this project — private.user_roles is authoritative.
  }

  // --- Auth users summary (owner audit surface; includes staff/verifiers) ---
  await dump("auth_users", `
    select u.id, u.email, u.role as auth_role, u.banned_until, u.created_at, u.last_sign_in_at,
           u.raw_app_meta_data->>'provider' as provider,
           u.raw_user_meta_data->>'role' as meta_role
    from auth.users u
    order by u.created_at
  `);

  // --- Triggers referencing security-definer surface (quick view) ---
  await dump("triggers", `
    select n.nspname as schema_name, c.relname as table_name, t.tgname as trigger_name,
           p.proname as function_name, t.tgenabled as enabled
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where not t.tgisinternal and n.nspname in ('public', 'private')
    order by n.nspname, c.relname, t.tgname
  `);

  // --- Views with security_invoker status ---
  await dump("views", `
    select n.nspname as schema_name, c.relname as view_name,
           (c.relreplident = 'n') as placeholder,
           coalesce((
             select option_value from pg_options_to_table(c.reloptions)
             where option_name = 'security_invoker' limit 1), 'off') as security_invoker
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private') and c.relkind in ('v', 'm')
    order by n.nspname, c.relname
  `);

  // --- Helper: which public functions check identity (rough heuristic mirror of advisor) ---
  await dump("public_functions_exec_summary", `
    select n.nspname as schema_name, p.proname as function_name,
           pg_get_function_identity_arguments(p.oid) as identity_args,
           p.prosecdef as security_definer,
           (p.proconfig is not null and array_to_string(p.proconfig, ',') like '%search_path%') as has_search_path,
           (p.proacl is null or exists (select 1 from aclexplode(p.proacl) a
                    where a.grantee = 'authenticated'::regrole::oid)) as executable_by_authenticated_default,
           (strpos(pg_get_functiondef(p.oid), 'auth.uid(') > 0
             or strpos(pg_get_functiondef(p.oid), 'auth.role(') > 0
             or strpos(pg_get_functiondef(p.oid), 'request.jwt.claims') > 0) as mentions_identity_check
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
    order by p.proname, identity_args
  `);
} finally {
  await client.end();
}

// --- Management API advisors (optional; token must cover this project) ---
if (accessToken) {
  const advisors = {};
  for (const kind of ["security", "performance"]) {
    try {
      const response = await fetch(
        `https://api.supabase.com/v1/projects/${projectRef}/advisors/${kind}`,
        { headers: { Authorization: `Bearer ${accessToken}` } },
      );
      if (response.ok) {
        const payload = await response.json();
        const findings = Array.isArray(payload) ? payload : payload?.[0]?.advisors ?? [];
        advisors[kind] = findings;
      } else {
        advisors[kind] = { error: `HTTP ${response.status}` };
      }
    } catch (error) {
      advisors[kind] = { error: String(error) };
    }
  }
  writeFileSync(`${outDir}/advisors.json`, JSON.stringify(advisors, null, 2));
}

console.log(JSON.stringify({ project_ref: projectRef, output_dir: outDir, status: "COMPLETE" }));
