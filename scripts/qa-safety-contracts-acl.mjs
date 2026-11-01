import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";

const container = `mort-acl-check-${randomUUID().slice(0, 8)}`;
const runDocker = (args, options = {}) =>
  execFileSync("docker", args, {
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
    ...options,
  });

const sql = String.raw`
create role authenticated nologin;
create table public.jobs (id integer, title text, exact_address text);
grant insert (id, title, exact_address), update (title, exact_address), select (id, title)
  on public.jobs to authenticated;

revoke insert, update on public.jobs from authenticated;
do $$
declare
  v_column_grant record;
begin
  for v_column_grant in
    select distinct column_name, privilege_type
    from information_schema.column_privileges
    where table_schema = 'public'
      and table_name = 'jobs'
      and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE')
  loop
    execute format(
      'revoke %s (%I) on table public.jobs from authenticated',
      v_column_grant.privilege_type,
      v_column_grant.column_name
    );
  end loop;
end;
$$;

do $$
begin
  if has_table_privilege('authenticated', 'public.jobs', 'INSERT')
     or has_table_privilege('authenticated', 'public.jobs', 'UPDATE') then
    raise exception 'table-level job write privilege remains';
  end if;
  if has_column_privilege('authenticated', 'public.jobs', 'exact_address', 'INSERT')
     or has_column_privilege('authenticated', 'public.jobs', 'exact_address', 'UPDATE') then
    raise exception 'exact_address write privilege remains';
  end if;
  if has_column_privilege('authenticated', 'public.jobs', 'title', 'INSERT')
     or has_column_privilege('authenticated', 'public.jobs', 'title', 'UPDATE') then
    raise exception 'other job column write privilege remains';
  end if;
  if not has_column_privilege('authenticated', 'public.jobs', 'id', 'SELECT')
     or not has_column_privilege('authenticated', 'public.jobs', 'title', 'SELECT') then
    raise exception 'existing safe column SELECT grant was removed';
  end if;
  if has_column_privilege('authenticated', 'public.jobs', 'exact_address', 'SELECT')
     or has_table_privilege('authenticated', 'public.jobs', 'SELECT') then
    raise exception 'exact or table-wide SELECT privilege was added';
  end if;
end;
$$;
select 'column ACL contract: PASS';
`;

let started = false;
try {
  runDocker([
    "run",
    "--rm",
    "-d",
    "--name",
    container,
    "-e",
    "POSTGRES_HOST_AUTH_METHOD=trust",
    "postgres:17-alpine",
  ]);
  started = true;

  let ready = false;
  for (let attempt = 0; attempt < 30; attempt += 1) {
    try {
      runDocker(["exec", container, "pg_isready", "-U", "postgres", "-d", "postgres"]);
      ready = true;
      break;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
  if (!ready) throw new Error("Disposable PostgreSQL did not become ready.");

  const output = runDocker(
    ["exec", "-i", container, "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"],
    { input: sql },
  );
  if (!output.includes("column ACL contract: PASS")) {
    throw new Error("PostgreSQL did not report a passing ACL assertion.");
  }
  console.log("[qa-safety-contracts-acl] PASS (disposable PostgreSQL 17)");
} finally {
  if (started) {
    try {
      runDocker(["rm", "-f", container]);
    } catch {
      // `--rm` may already have removed the isolated test container.
    }
  }
}
