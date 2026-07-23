import pg from "pg";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const projectRef = "rakjydmgwwgtdislanbt";
const password = process.env.SUPABASE_DB_PASSWORD;

if (!password) {
  throw new Error("Set SUPABASE_DB_PASSWORD before creating the remote schema snapshot.");
}

const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

const queries = {
  database: `
    select current_database() as database_name,
           current_user as connected_role,
           current_setting('server_version') as server_version
  `,
  relations: `
    select n.nspname as schema_name,
           c.relname as relation_name,
           c.relkind as relation_kind,
           c.relrowsecurity as row_level_security,
           pg_get_userbyid(c.relowner) as owner
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and c.relkind in ('r', 'p', 'v', 'm')
    order by n.nspname, c.relname
  `,
  columns: `
    select table_schema,
           table_name,
           ordinal_position,
           column_name,
           data_type,
           udt_schema,
           udt_name,
           is_nullable,
           column_default
    from information_schema.columns
    where table_schema in ('public', 'private', 'storage')
    order by table_schema, table_name, ordinal_position
  `,
  constraints: `
    select n.nspname as schema_name,
           c.relname as table_name,
           con.conname as constraint_name,
           con.contype as constraint_type,
           pg_get_constraintdef(con.oid, true) as definition
    from pg_constraint con
    join pg_class c on c.oid = con.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
    order by n.nspname, c.relname, con.conname
  `,
  indexes: `
    select schemaname as schema_name,
           tablename as table_name,
           indexname as index_name,
           indexdef as definition
    from pg_indexes
    where schemaname in ('public', 'private', 'storage')
    order by schemaname, tablename, indexname
  `,
  functions: `
    select n.nspname as schema_name,
           p.proname as function_name,
           pg_get_function_identity_arguments(p.oid) as arguments,
           pg_get_functiondef(p.oid) as definition
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
    order by p.proname, arguments
  `,
  triggers: `
    select n.nspname as schema_name,
           c.relname as table_name,
           t.tgname as trigger_name,
           pg_get_triggerdef(t.oid, true) as definition
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and not t.tgisinternal
    order by n.nspname, c.relname, t.tgname
  `,
  policies: `
    select schemaname,
           tablename,
           policyname,
           permissive,
           roles,
           cmd,
           qual,
           with_check
    from pg_policies
    where schemaname in ('public', 'private', 'storage')
    order by schemaname, tablename, policyname
  `,
  tableGrants: `
    select table_schema,
           table_name,
           grantee,
           privilege_type,
           is_grantable
    from information_schema.table_privileges
    where table_schema in ('public', 'private', 'storage')
      and grantee in ('anon', 'authenticated', 'service_role')
    order by table_schema, table_name, grantee, privilege_type
  `,
  migrations: `
    select version, name, statements
    from supabase_migrations.schema_migrations
    order by version
  `,
  storageBuckets: `
    select id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at
    from storage.buckets
    order by id
  `,
  storageObjectCounts: `
    select bucket_id, count(*)::int as object_count
    from storage.objects
    group by bucket_id
    order by bucket_id
  `,
  featureRowCounts: `
    select jsonb_build_object(
      'profiles', (select count(*)::int from public.profiles),
      'teen_profiles', (select count(*)::int from public.teen_profiles),
      'guardian_connections', (select count(*)::int from public.guardian_connections),
      'jobs', (select count(*)::int from public.jobs),
      'applications', (select count(*)::int from public.applications),
      'notifications', (select count(*)::int from public.notifications)
    ) as counts
  `,
};

await client.connect();
const snapshot = {
  projectRef,
  generatedAt: new Date().toISOString(),
  containsUserRows: false,
};

try {
  for (const [name, sql] of Object.entries(queries)) {
    const result = await client.query(sql);
    snapshot[name] = result.rows;
  }
} finally {
  await client.end();
}

const repoRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const backupDir = join(repoRoot, "backups");
mkdirSync(backupDir, { recursive: true });
const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const outputPath = join(
  backupDir,
  `remote-feature-schema-${projectRef}-${timestamp}.json`,
);
writeFileSync(outputPath, `${JSON.stringify(snapshot, null, 2)}\n`, "utf8");

console.log(`[backup-feature-schema] Project ref: ${projectRef}`);
console.log(`[backup-feature-schema] Snapshot: ${outputPath}`);
console.log(
  `[backup-feature-schema] Relations=${snapshot.relations.length}, policies=${snapshot.policies.length}, functions=${snapshot.functions.length}, migrations=${snapshot.migrations.length}`,
);
