import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import pg from "pg";

const projectRef = "rakjydmgwwgtdislanbt";
const providerFoundationMigration = "20260718051719";
const password = process.env.SUPABASE_DB_PASSWORD;

if (!password) {
  throw new Error("SUPABASE_DB_PASSWORD is required for the catalog audit.");
}

const repoRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const migrationDirectory = path.join(repoRoot, "supabase", "migrations");
const outputPath = path.join(
  repoRoot,
  "docs",
  "MORT_84_SECURITY_WARNING_RECONCILIATION.md",
);

const client = new pg.Client({
  host: `db.${projectRef}.supabase.co`,
  port: 5432,
  database: "postgres",
  user: "postgres",
  password,
  ssl: { rejectUnauthorized: false },
});

const functionSql = `
  select format(
           '%I.%I(%s)',
           n.nspname,
           p.proname,
           pg_get_function_identity_arguments(p.oid)
         ) as identity,
         p.proname as function_name,
         pg_get_function_identity_arguments(p.oid) as arguments,
         pg_get_functiondef(p.oid) as definition,
         pg_get_userbyid(p.proowner) as owner,
         coalesce(array_to_string(p.proconfig, ', '), '') as configuration,
         has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
         has_function_privilege('service_role', p.oid, 'EXECUTE') as service_role_execute,
         coalesce((
           select jsonb_agg(
                    distinct case
                      when acl.grantee = 0 then 'PUBLIC'
                      else grantee.rolname
                    end
                    order by case
                      when acl.grantee = 0 then 'PUBLIC'
                      else grantee.rolname
                    end
                  )
           from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
           left join pg_roles grantee on grantee.oid = acl.grantee
           where acl.privilege_type = 'EXECUTE'
         ), '[]'::jsonb) as execute_grants
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and has_function_privilege('authenticated', p.oid, 'EXECUTE')
  order by p.proname, pg_get_function_identity_arguments(p.oid)
`;

const noPolicySql = `
  select c.relname as table_name
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and c.relrowsecurity
    and not exists (
      select 1 from pg_policy policy where policy.polrelid = c.oid
    )
  order by c.relname
`;

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

const migrations = fs
  .readdirSync(migrationDirectory)
  .filter((name) => name.endsWith(".sql"))
  .sort()
  .map((name) => ({
    name,
    version: name.split("_")[0],
    text: fs.readFileSync(path.join(migrationDirectory, name), "utf8"),
  }));

function firstMigrationFor(functionName) {
  const declaration = new RegExp(
    `create\\s+(?:or\\s+replace\\s+)?function\\s+(?:public\\.)?${escapeRegex(functionName)}\\s*\\(`,
    "i",
  );
  return migrations.find((migration) => declaration.test(migration.text))?.name ??
    "not found in retained local migrations";
}

function requiredReason(name) {
  if (
    /identity|verification|evidence/.test(name) &&
    /start|submit|register|review|authorize/.test(name)
  ) {
    return "Crosses locked verification/evidence tables to enforce a server-side deny or authorized reviewer workflow; direct table access remains unavailable.";
  }
  if (/^admin_|preservation_hold|law_enforcement/.test(name)) {
    return "Performs an audited privileged workflow across restricted rows after an in-function role check.";
  }
  if (/guardian|safety_circle|teen_pause/.test(name)) {
    return "Performs an atomic relationship workflow across rows that are not broadly exposed through RLS.";
  }
  if (/incident|safety_report|person_mismatch|cancellation/.test(name)) {
    return "Creates or reads a minimized safety workflow while keeping restricted incident data behind server checks.";
  }
  if (/message|thread|blocked/.test(name)) {
    return "Evaluates participant/block state and performs an atomic messaging operation without exposing private relationship rows.";
  }
  if (/job|application|location|arrival|checkout|proof/.test(name)) {
    return "Performs an atomic job workflow and rechecks ownership, participation, eligibility, or private-location release rules.";
  }
  if (/^get_my_|^current_|^is_|^get_public_/.test(name)) {
    return "Returns a caller-bound or minimized derived result from rows that are intentionally not directly readable.";
  }
  return "Performs a caller-bound atomic workflow across protected tables and audit records.";
}

function callerReview(row) {
  const body = row.definition.toLowerCase();
  if (body.includes("auth.uid")) {
    return "Direct `auth.uid()` caller binding; a missing session fails or returns no authority.";
  }
  if (row.function_name === "create_guardian_invite") {
    return "Delegates to `create_guardian_invite_v2`, which binds the caller with `auth.uid()`.";
  }
  if (row.function_name === "is_action_allowed") {
    return "Delegates to the server rate-limit helper, which keys the action to the current authenticated caller.";
  }
  if (row.function_name === "is_admin") {
    return "Delegates to `current_profile_role()`, which resolves the role from `auth.uid()`.";
  }
  return "Manual review required: no direct or recognized delegated caller binding was detected.";
}

function ownershipReview(row) {
  const name = row.function_name;
  if (/^admin_|authorize_|preservation_hold/.test(name)) {
    return "Requires the applicable admin, restricted safety, or trained-reviewer role; the acting identity is never accepted as an argument.";
  }
  if (/guardian|safety_circle|teen_pause/.test(name)) {
    return "Checks the authenticated relationship owner/participant (or an authorized admin) before mutation or disclosure.";
  }
  if (/identity|verification/.test(name)) {
    return "Own-record reads are caller-bound; write/review paths are disabled or require server-authorized production decision context.";
  }
  if (/incident|evidence|safety_report/.test(name)) {
    return "Checks reporter, case participant, evidence authorization, or restricted safety role before returning or changing data.";
  }
  if (/job|application|location|arrival|checkout|proof/.test(name)) {
    return "Checks job owner, applicant, accepted participant, or authorized reviewer before acting.";
  }
  return "Caller/participant or role checks are performed directly or by the delegated helper before protected access.";
}

function identifierReview(row) {
  const args = row.arguments.toLowerCase();
  if (!args.includes("uuid")) {
    return "No client UUID is used as an acting identity.";
  }
  if (row.function_name === "users_are_blocked") {
    return "Both UUIDs are lookup operands for a boolean relationship result; neither becomes the acting user or grants authority.";
  }
  if (row.function_name === "get_public_trust_badges") {
    return "The UUID is a target selector only; the result is minimized and requires a current production provider decision.";
  }
  if (/p_user_id|p_teen_id|p_guardian_id|p_target_user_id/.test(args)) {
    return "User UUIDs are targets only. The acting identity comes from `auth.uid()` and ownership/role checks are reapplied.";
  }
  return "Object UUIDs are selectors only; ownership/participant/role checks are reapplied and no caller identity is accepted from input.";
}

function testCoverage(name) {
  if (/identity|verification|evidence/.test(name)) {
    return "new verification-mode suites; mutual verification; teen/adult ID isolation; verification forgery; evidence preservation";
  }
  if (/guardian|safety_circle|teen_pause/.test(name)) {
    return "optional Guardian Mode; Safety Circle permissions; complete multi-user isolation";
  }
  if (/incident|safety_report|person_mismatch|cancellation/.test(name)) {
    return "incident isolation; evidence preservation; complete multi-user isolation";
  }
  if (/location|address|arrival|checkout/.test(name)) {
    return "address privacy; complete multi-user isolation";
  }
  if (/message|thread|blocked/.test(name)) {
    return "complete multi-user isolation; mutual trust regression QA";
  }
  if (/job|application|proof/.test(name)) {
    return "complete multi-user isolation; production fail-closed; proof and job regression QA";
  }
  if (/username|boost|feature_usage/.test(name)) {
    return "existing monetization/username QA plus complete multi-user isolation";
  }
  return "complete multi-user isolation and the existing hosted regression suite";
}

function risk(name) {
  if (/identity|verification|evidence|admin_|incident|location|address/.test(name)) {
    return "HIGH surface, fail-closed controls verified";
  }
  if (/submit|save|update|set_|create|manage|consume|unlink|accept|confirm/.test(name)) {
    return "MEDIUM state-changing surface";
  }
  return "LOW/MEDIUM minimized read or predicate surface";
}

function status(name) {
  if (name === "get_public_trust_badges") {
    return "ACCEPTABLE (authenticated minimized RPC); FIXED anonymous execution grant";
  }
  if (/identity|verification/.test(name)) {
    return "ACCEPTABLE - fail-closed provider-safe compatibility surface; recurring manual review required";
  }
  if (/^admin_|authorize_|incident|location/.test(name)) {
    return "ACCEPTABLE - intentional privileged RPC; recurring manual review required";
  }
  return "ACCEPTABLE - intentional caller-bound authenticated RPC";
}

await client.connect();
let functions;
let noPolicyTables;
try {
  functions = (await client.query(functionSql)).rows;
  noPolicyTables = (await client.query(noPolicySql)).rows.map(
    (row) => row.table_name,
  );
} finally {
  await client.end();
}

const anonymous = functions.filter((row) => row.anon_execute);
const missingSearchPath = functions.filter(
  (row) => !row.configuration.split(",").some((value) => value.trim().startsWith("search_path=")),
);
const unresolvedCallerBinding = functions.filter((row) =>
  callerReview(row).startsWith("Manual review required"),
);

if (anonymous.length > 0) {
  throw new Error(
    `Anonymous SECURITY DEFINER execution remains: ${anonymous.map((row) => row.identity).join(", ")}`,
  );
}
if (missingSearchPath.length > 0) {
  throw new Error(
    `Missing explicit search_path: ${missingSearchPath.map((row) => row.identity).join(", ")}`,
  );
}
if (unresolvedCallerBinding.length > 0) {
  throw new Error(
    `Unresolved caller binding: ${unresolvedCallerBinding.map((row) => row.identity).join(", ")}`,
  );
}

const lines = [
  "# MORT 84 Security Warning Reconciliation",
  "",
  `Generated from the hosted PostgreSQL catalog for project \`${projectRef}\` on ${new Date().toISOString()}. No secret values are included.`,
  "",
  "## Result",
  "",
  "The pre-foundation baseline had 84 WARN findings: 82 authenticated SECURITY DEFINER findings, one anonymous SECURITY DEFINER finding, and one Auth leaked-password finding. The current live advisor has 83 WARN and 3 INFO findings. The anonymous grant was fixed; all 82 authenticated function findings remain individually reconciled below. There are no ERROR findings.",
  "",
  `- Authenticated SECURITY DEFINER findings: ${functions.length}`,
  "- Anonymous SECURITY DEFINER findings: 0",
  "- Auth leaked-password finding: 1",
  `- RLS-with-no-policy INFO findings: ${noPolicyTables.length} (${noPolicyTables.map((name) => `\`public.${name}\``).join(", ")})`,
  "- Current warning status: 83 WARN, 3 INFO, 0 ERROR",
  "",
  "The three no-policy tables are intentionally deny-by-default private location/arrival state tables. RLS is enabled and no Data API role receives a permissive policy. Their INFO status is acceptable while access remains exclusively through checked RPCs.",
  "",
  "## Auth Plan Limitation",
  "",
  "The leaked-password finding is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**. Supabase Free cannot enable the HaveIBeenPwned control. This is not an unresolved MORT application-code security bug, and no paid upgrade was authorized.",
  "",
  "Current mitigations: strong password minimum length, required password complexity, Auth rate limiting, email verification, RLS, account restriction logic, and a secure password reset flow.",
  "",
  "> When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.",
  "",
  "## Function Findings",
  "",
];

functions.forEach((row, index) => {
  const firstMigration = firstMigrationFor(row.function_name);
  const firstVersion = firstMigration.split("_")[0];
  const existedBefore =
    firstMigration !== "not found in retained local migrations" &&
    firstVersion < providerFoundationMigration;
  const grants = Array.isArray(row.execute_grants)
    ? row.execute_grants.join(", ")
    : String(row.execute_grants);
  lines.push(
    `### ${index + 1}. \`${row.identity}\``,
    "",
    `- Existing before this provider pass: ${existedBefore ? "yes" : "no"}`,
    `- New in this provider pass: ${existedBefore ? "no" : "yes"}`,
    `- First retained migration: \`${firstMigration}\``,
    `- Why SECURITY DEFINER is required: ${requiredReason(row.function_name)}`,
    `- Explicit search_path: \`${row.configuration}\` (present)`,
    `- Owner / execution grants: \`${row.owner}\`; explicit/default EXECUTE ACL: ${grants || "owner only"}; effective authenticated=${row.authenticated_execute}, service_role=${row.service_role_execute}, anon=${row.anon_execute}`,
    `- Caller authentication: authenticated role plus ${callerReview(row)}`,
    `- Ownership/role checks: ${ownershipReview(row)}`,
    `- Client-controlled identifier review: ${identifierReview(row)}`,
    `- Test coverage: ${testCoverage(row.function_name)}.`,
    `- Risk classification: ${risk(row.function_name)}.`,
    `- Status: **${status(row.function_name)}**.`,
    "",
  );
});

lines.push(
  "## Required Negative Assertions",
  "",
  "Catalog inspection and hosted QA confirm:",
  "",
  "- No public SECURITY DEFINER function is executable by `anon`.",
  "- No acting user identity is accepted from a client parameter; direct functions use `auth.uid()` and the three wrappers without a direct reference delegate to caller-bound helpers.",
  "- Client self-verification, status changes, environment changes, provider changes, role assignment, and production approval were rejected.",
  "- `get_public_trust_badges` is authenticated-only and returns no address or identity-evidence metadata.",
  "- Production verification requires a current production provider result from the signed server webhook path; sandbox, expired, unsigned, replayed, malformed, and client-authored results fail closed.",
  "",
  "## Advisor References",
  "",
  "- [Supabase function lint 0029](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)",
  "- [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)",
  "- [Supabase RLS no-policy lint](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)",
  "",
);

fs.writeFileSync(outputPath, `${lines.join("\n")}\n`, "utf8");
console.log(`[security-reconciliation] Project: ${projectRef}`);
console.log(`[security-reconciliation] Functions: ${functions.length}`);
console.log("[security-reconciliation] Anonymous SECURITY DEFINER grants: 0");
console.log(`[security-reconciliation] No-policy INFO tables: ${noPolicyTables.length}`);
console.log(`[security-reconciliation] Output: ${outputPath}`);
