# Account-deletion worker deployment runbook

**Status:** Hosted QA worker v8 is deployed and its Vault authentication/scheduler are verified. Production deployment remains prepared only and has not been executed.

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

Expected package test result: `account-deletion package, lease, and bounded-I/O assertions passed`.

Where the Supabase CLI is available, perform a dry package/deploy validation first if supported by the installed CLI version. The deployment unit must include both `index.ts` and the package-local `observability.ts`; it must not depend on `../_shared/observability.ts`.

## QA deployment and hosted verification (authorization required)

An owner-controlled QA operator must provide, through a protected shell or secret manager only:

- `SUPABASE_ACCESS_TOKEN` with deployment permission for QA
- `SUPABASE_SERVICE_ROLE_KEY` for the QA project
- `SUPABASE_DB_PASSWORD` for the QA project
- A QA Vault secret named `account_deletion_worker_secret`, created by the approved QA migration. The harness retrieves it through the service-role-only `service_get_account_deletion_worker_secret()` RPC; do not put the secret in environment variables or files.

After verifying that the CLI is authenticated for the QA project, the authorized operator may deploy only to QA:

```bash
pnpm exec supabase functions deploy account-deletion-processor \
  --project-ref ckcxakhxqlkhppsxxjhv \
  --no-verify-jwt \
  --use-api
```

Set the worker secret only through the authorized QA secret-management path; do not put it in this repository or command history. The configuration probe must be performed in a disposable QA deployment/configuration state and must confirm:

- missing Supabase service configuration returns HTTP `503` with `deletion_worker_not_configured`;
- missing or invalid Vault secret returns HTTP `503` with `deletion_worker_unavailable`;
- Vault lookup is server-side and service-role-only; no claim or destructive operation occurs before the caller secret is authenticated;
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
3. Production `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are present through the platform's protected configuration path.
4. The production Vault contains `account_deletion_worker_secret`; the service-role-only lookup RPC returns a 64-character or longer value. The Edge Function and scheduler both read the same Vault value; no duplicate Edge Function environment secret is used.
5. The production database contains the required service RPCs and retention constraints, and the approved retention matrix is in force.
6. The scheduler reads the Vault secret at runtime and targets only the production worker endpoint.
7. The on-call owner and rollback approver are identified.
8. A maintenance/rollback decision has been documented; no real deletion test is to be performed in production.

Do not execute this command in the current task.

## Rollback and verification

Edge Function rollback must use the Supabase Dashboard or CLI version rollback mechanism supported by the installed CLI and the project's deployment history. Do not overwrite the source with an unreviewed historical copy. The rollback record must include the prior function version, approver, timestamp, reason, and post-rollback endpoint checks.

Post-deployment checks are non-destructive only:

```bash
curl -i -X POST "https://<authorized-project-ref>.supabase.co/functions/v1/account-deletion-processor" \
  -H 'content-type: application/json' \
  --data '{}'
```

For a correctly configured deployment, an invocation without the worker secret must return HTTP `401`; a missing Vault secret returns HTTP `503` with `deletion_worker_unavailable`; missing Supabase service configuration returns HTTP `503` with `deletion_worker_not_configured`. Never send a real user ID or production deletion request as a smoke test.

## Current evidence

- Earlier package regression and replica acceptance on PR #125 passed.
- Hosted QA worker v8 is deployed. Wrong-secret authentication returned HTTP 401; correct Vault-backed authentication with an empty queue returned HTTP 200 and `processed: 0`.
- QA Vault lookup is service_role-only; anon execution was denied. The QA cron job ran successfully and received HTTP 200.
- Existing QA request states remained unchanged, no synthetic rows remained after the checks, and no real accounts were deleted.
- The integrated Vault-source package assertions are being rerun in CI on the current reconciliation PR.
- Production deployment, production Vault secret creation, production scheduler activation, and production account deletion: **not executed**.


## Live production and hosted-QA recheck — 2026-11-24

The hosted QA deployment and production project were rechecked after the Vault-backed worker change.

### Current deployment and secret state

| Item | Production | Hosted QA |
|---|---|---|
| Supabase project | `jxbnrkasktbhtiujkhay` | `ckcxakhxqlkhppsxxjhv` |
| `account-deletion-processor` | ACTIVE, version 1 (older source) | ACTIVE, version 8 (Vault-backed source) |
| Deletion worker secret | No deletion-specific Vault secret | `account_deletion_worker_secret` stored in Vault |
| Secret lookup RPC | Absent | `service_get_account_deletion_worker_secret()`, service_role only |
| Deletion scheduler | No deletion cron job | `account-deletion-processor-qa`, every 5 minutes |
| Deletion request schema and RPCs | Absent | Present |

The QA worker obtains its high-entropy credential through the service-role-only Vault RPC. The Edge Function and scheduler read the same Vault value at runtime; the old `ACCOUNT_DELETION_WORKER_SECRET` Edge Function environment variable is not required.

### QA verification — 2026-11-24

- Vault secret lookup returned a 64-character secret to service_role; anon execution was denied.
- Worker request with an incorrect secret returned HTTP 401.
- Worker request with the correct Vault-backed secret and an empty queue returned HTTP 200 with `processed: 0`.
- The five-minute QA cron job ran successfully; its HTTP request returned 200 with no timeout or error.
- Existing QA request counts remained unchanged: `cancelled=1`, `completed=1`, `retention_review=1`.
- No synthetic request rows remained after the checks, and no real account was deleted.

This verifies Vault authentication and scheduled invocation. It does not replace a fresh, disposable-account end-to-end deletion run against worker v8 before production promotion.

### Production extension and scheduler state

Production has `pg_cron`, `pg_net`, `pgcrypto`, and `supabase_vault` installed, and the cron catalog is available. However, there is **no account-deletion cron job**, no deletion-specific Vault secret, no `account_deletion_requests` table, and none of the seven required worker RPCs. Installing the extensions alone does not make the deletion service operational.

### QA harness target safety

The default-branch QA harness has not yet been updated to the Vault-backed, QA-pinned version in PR #135. **Do not run the default-branch harness.** Use the branch version only after reviewing it and supplying the QA service-role key and database password through a protected environment. It retrieves the worker secret from Vault using the service-role-only RPC and does not require a copied worker-secret environment variable.

The QA worker v8 deployment, Vault lookup, HTTP authorization checks, and QA scheduler installation were performed. Production deployment, production secret creation, production scheduler activation, and production account deletion were not performed.

### Deletion contract parity — confirmed production blocker

A direct read-only check of the exact database objects referenced by the deployed production worker returned:

| Contract object | Production | Hosted QA |
|---|---|---|
| `public.account_deletion_requests` | **Absent** | Present |
| `public.service_claim_account_deletion_request(uuid)` | **Absent** | Present |
| `public.service_complete_account_deletion_request(uuid, uuid, text)` | **Absent** | Present |
| `public.service_fail_account_deletion_request(uuid, uuid, text)` | **Absent** | Present |

The production worker source calls these RPCs. After worker authorization, its first claim call cannot resolve in the current production database. This is stronger than an unverified scheduler gap: the deployed worker and production database do not share the required deletion contract.

The QA project has the request table and the corresponding service RPCs, plus the related retention, lease, receipt, and storage-listing functions. Production has none of the deletion-named database functions in the inspected `public`/`private` schemas.

**Verdict: production account deletion is NOT operational.** Do not invoke the production worker. Do not deploy only the newer Edge Function source; the database contract and scheduler must be promoted and validated together. Promotion requires a source-level migration review, QA end-to-end tests, retention/legal approval, and separate explicit production authorization.
