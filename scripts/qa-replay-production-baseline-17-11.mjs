#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';
import { readFile, readdir } from 'node:fs/promises';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const approvedContainers = new Set([
  'mort-pg1711-reviewfresh-mort20261102',
  'mort-pg1711-finalreview-20261102',
]);
const containerArg = process.argv.indexOf('--container');
const container = containerArg >= 0
  ? process.argv[containerArg + 1]
  : 'mort-pg1711-reviewfresh-mort20261102';
assert.ok(approvedContainers.has(container), 'refusing any target except an explicitly named disposable local container');

const repoRoot = fileURLToPath(new URL('../', import.meta.url));
const migrationDir = join(repoRoot, 'supabase-production', 'migrations');
const files = (await readdir(migrationDir)).filter((file) => /^\d{14}_.+\.sql$/.test(file)).sort();
assert.equal(files.length, 73, `expected 73 production migration files, got ${files.length}`);
assert.match(files[0], /^20261026194801_/);
assert.match(files.at(-1), /^20261102113314_/);

function dockerPsql(user, sqlBytes) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', ['exec', '-i', container, 'psql', '-U', user, '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], {
      stdio: ['pipe', 'inherit', 'inherit'],
      windowsHide: true,
    });
    child.once('error', reject);
    child.once('close', (code) => code === 0 ? resolve() : reject(new Error(`docker psql exited with code ${code}`)));
    child.stdin.end(sqlBytes);
  });
}

function dockerQuery(query) {
  return execFileSync('docker', ['exec', container, 'psql', '-U', 'postgres', '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1', '-c', query], { encoding: 'utf8' }).trim();
}

assert.equal(dockerQuery('show server_version_num'), '170011', 'requires PostgreSQL 17.11');
const emptyPreflight = `DO $guard$ DECLARE has_rows boolean := false; BEGIN
  IF current_database() <> 'postgres' THEN RAISE EXCEPTION 'unexpected database'; END IF;
  IF to_regclass('public.qa_production_migration_replay') IS NOT NULL THEN
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.qa_production_migration_replay)' INTO has_rows;
  END IF;
  IF has_rows OR EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','S','f') AND c.relname <> 'qa_production_migration_replay') THEN
    RAISE EXCEPTION 'refusing non-empty database or prior MORT/proposal artifacts';
  END IF;
END $guard$;`;
await dockerPsql('postgres', Buffer.from(emptyPreflight, 'utf8'));

const platformBootstrap = `GRANT CREATE ON SCHEMA storage TO postgres;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS email_confirmed_at timestamptz;`;
await dockerPsql('supabase_admin', Buffer.from(platformBootstrap, 'utf8'));

const localTestScaffold = `CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE TABLE IF NOT EXISTS public.qa_production_migration_replay (
  version text PRIMARY KEY, name text NOT NULL,
  source_sha256 text NOT NULL CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
  applied_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE storage.buckets (
  id text PRIMARY KEY, name text NOT NULL, public boolean NOT NULL DEFAULT false,
  file_size_limit bigint, allowed_mime_types text[]
);
CREATE TABLE storage.objects (
  id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  bucket_id text NOT NULL REFERENCES storage.buckets(id), name text NOT NULL,
  owner_id text, metadata jsonb, created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(), UNIQUE(bucket_id,name)
);
ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION storage.foldername(name text)
RETURNS text[] LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = ''
AS $function$ SELECT string_to_array(trim(both '/' from name), '/') $function$;`;
await dockerPsql('postgres', Buffer.from(localTestScaffold, 'utf8'));

for (const file of files) {
  const match = /^(\d{14})_(.+)\.sql$/.exec(file);
  assert.ok(match, `invalid migration filename ${file}`);
  const [, version, name] = match;
  const path = join(migrationDir, file);
  const sqlBytes = await readFile(path);
  const sha256 = createHash('sha256').update(sqlBytes).digest('hex');
  console.log(`REPLAY ${version} ${name}`);
  await dockerPsql('postgres', sqlBytes);
  await dockerPsql('postgres', Buffer.from(
    `INSERT INTO public.qa_production_migration_replay(version,name,source_sha256) VALUES ('${version}','${name}','${sha256}');`,
    'utf8',
  ));
}

const replay = dockerQuery("SELECT count(*)||'|'||min(version)||'|'||max(version)||'|'||count(DISTINCT source_sha256) FROM public.qa_production_migration_replay");
assert.equal(replay, '73|20261026194801|20261102113314|73');
console.log(`FRESH_PRODUCTION_BASELINE_REPLAY=PASS ${replay} PostgreSQL=170011 source_bytes=exact`);
