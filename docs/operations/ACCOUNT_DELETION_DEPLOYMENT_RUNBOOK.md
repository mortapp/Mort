# Account-deletion worker deployment runbook

**Status:** Prepared only; no hosted deployment was executed from this session.

**Worker:** `account-deletion-processor`

**Source package:** `supabase/functions/account-deletion-processor/`

**Reviewed commit:** `c4fad55` (`hardening: package account deletion worker and inventory definer functions`)

## Safety boundaries

This worker can delete Auth identities, profile data, and owned Storage objects. Deployment and invocation require separate owner authorization. Never run the QA harness against production, and never use the retired project `rakjydmgwwgtdislanbt`.

- Isolated hosted QA project: `ckcxakhxqlkhppsxxjhv`
- Production project: `jxbnrkasktbhtiujkhay` (deployment intentionally not executed)
- The QA harness creates and deletes synthetic fixtures and requires server-only secrets.
- Do not print, commit, or paste service-role keys, database passwords, or worker secrets.
- Do not use synthetic JWT claims or real identity documents/private data.

## Source/package preflight

Run from the repository root at the reviewed commit:

```bash
git status --short
git rev-parse HEAD
node scripts/qa-account-deletion-package.test.mjs
git diff --check
```

Expected package test result: `account-deletion package tests: 6/6 passed`.

Where the Supabase CLI is available, perform a dry package/deploy validation first if supported by the installed CLI version. The deployment unit must include both `index.ts` and the package-local `observability.ts`; it must not depend on `../_shared/observability.ts`.

## QA deployment and hosted verification (authorization required)

An owner-controlled QA operator must provide, through a protected shell or secret manager only:

- `SUPABASE_ACCESS_TOKEN` with deployment permission for QA
- `SUPABASE_SERVICE_ROLE_KEY` for the QA project
- `SUPABASE_DB_PASSWORD` for the QA project
- `ACCOUNT_DELETION_WORKER_SECRET` configured identically in the QA Edge Function and the QA harness

After verifying that the CLI is authenticated for the QA project, the authorized operator may deploy only to QA:

```bash
pnpm exec supabase functions deploy account-deletion-processor \
  --project-ref ckcxakhxqlkhppsxxjhv \
  --no-verify-jwt \
  --use-api
```

Set the worker secret only through the authorized QA secret-management path; do not put it in this repository or command history. The configuration probe must be performed in a disposable QA deployment/configuration state and must confirm:

- missing or incomplete worker configuration returns HTTP `503` with `deletion_worker_not_configured`;
- the response occurs before secret comparison and before database access;
- a request without `x-mort-deletion-secret` returns HTTP `401`;
- the authorized synthetic fixture run completes Auth deletion, profile cleanup, owned Storage cleanup, and request finalization;
- cleanup is confirmed even if the test fails.

With the required server-only values present, the hosted harness is:

```bash
node scripts/qa-account-deletion-processor.mjs
```

Record the exact deployment version, commit, response codes, worker response codes, fixture request ID, cleanup result, and timestamps in the consolidated readiness report. A hosted result must not be inferred from local, replica, or package tests.

## Production deployment package (prepared, not executed)

Production deployment requires a separate written release authorization after QA evidence and review are complete. The production project ref is explicitly pinned below to prevent accidental use of the retired project:

```bash
pnpm exec supabase functions deploy account-deletion-processor \
  --project-ref jxbnrkasktbhtiujkhay \
  --no-verify-jwt \
  --use-api
```

Before an authorized production deployment, verify all of the following in the release record:

1. The exact source commit is the reviewed and approved commit, with a clean working tree.
2. QA deployment and authorized synthetic E2E evidence are attached.
3. Production `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `ACCOUNT_DELETION_WORKER_SECRET` are present through the platform's protected configuration path.
4. The worker secret has been rotated or confirmed according to the owner-approved incident/release procedure.
5. The production database contains the required service RPCs and retention constraints.
6. The on-call owner and rollback approver are identified.
7. A maintenance/rollback decision has been documented; no real deletion test is to be performed in production.

Do not execute this command in the current task.

## Rollback and verification

Edge Function rollback must use the Supabase Dashboard or CLI version rollback mechanism supported by the installed CLI and the project's deployment history. Do not overwrite the source with an unreviewed historical copy. The rollback record must include the prior function version, approver, timestamp, reason, and post-rollback endpoint checks.

Post-deployment checks are non-destructive only:

```bash
curl -i -X POST "https://<authorized-project-ref>.supabase.co/functions/v1/account-deletion-processor" \
  -H 'content-type: application/json' \
  --data '{}'
```

For a correctly configured deployment, an invocation without the worker secret must return HTTP `401`; an intentionally unconfigured isolated QA probe returns HTTP `503` with `deletion_worker_not_configured`. Never send a real user ID or production deletion request as a smoke test.

## Current evidence

- Local package regression: `node scripts/qa-account-deletion-package.test.mjs` — 6/6 passed.
- PR #125 CI run `45061830844` — passed; replica acceptance job `137329243501` — passed.
- Hosted QA deployment and authorized hosted worker E2E: **not verified** because owner-controlled QA credentials and deployment authorization are unavailable in this session.
- Production deployment: **not executed**.


## Live production and hosted-QA recheck — 2026-11-23

Read-only checks found the following state:

| Item | Production | Hosted QA |
|---|---|---|
| `account-deletion-processor` | ACTIVE, version 1 | ACTIVE, version 2 |
| Function source SHA-256 | `ff4e25dbc8f29789cb136c3b42bed2f080fee8506353176f4f57c3ca73356963` | `80cc24fc5a185b84ab6ba5d731828c43b174a0463a3780b2519c54297e18d8f9` |
| Worker source | Older package | Newer lease/timeout/identity-confirmation package |

The production version currently throws during module initialization if any required worker secret is missing. The PR #125 package change instead keeps the handler alive and returns a fail-closed HTTP 503 configuration response before secret comparison or database access. The hosted-QA version has additional lease checks, bounded network timeouts, stricter claim validation, Auth-identity confirmation, and storage-listing progress checks that are not present in the inspected production version.

**Do not assume the QA worker is the production worker.** Do not invoke either worker as a smoke test with a real user or production request.

### Scheduler evidence

The production catalog has no `cron` schema and no `pg_cron` or `pg_net` extension. Repository search found no account-deletion scheduled workflow or Vercel cron declaration. This does not rule out an external scheduler outside the connected repositories, but no automatic invocation mechanism is currently evidenced. The owner must identify and configure an approved scheduler before the deletion service can be called operational.

### QA harness target safety

The default-branch `scripts/qa-account-deletion-processor.mjs` still contains a hard-coded production project reference. The PR #125 branch changes that harness to the isolated QA project and adds a hard stop against both production and the retired project. **Do not run the default-branch harness.** Run only the PR #125 QA-pinned copy after reviewing the branch and supplying the required QA-only secrets through a protected environment.

No worker deployment, invocation, secret retrieval, scheduled job creation, or production change was performed during this recheck.
