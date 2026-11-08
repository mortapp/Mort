# Guardian application-reader API QA

This is an authenticated PostgREST harness for `public.get_my_job_applications(uuid)`. It complements the production-baseline pgTAP suite; it does not replace it. It does not create or mutate accounts, Guardian relationships, applications, consent, verification, or staff access.

## Current evidence (2026-11-07)

Read-only inspection of isolated project `ckcxakhxqlkhppsxxjhv` found **0 Auth users, profiles, Guardian links, applications, jobs, and Storage objects**. Therefore no authenticated API persona or real application fixture currently exists, and no Guardian-reader PostgREST result is verified. No authenticated API request was attempted because there is no legitimate application fixture to authorize against. The local harness unit tests use an injected in-memory HTTP stub; they test the harness only and are not Supabase integration tests.

On 2026-11-07, a separate rollback-only **local SQL** run passed 49/49 pgTAP assertions against a fresh PostgreSQL 17 replay of the 73 verified production migrations. It checks the proposed row-scope fix, applicant/poster nested status responses, supported teen Guardian unlink, revoked-Guardian denial, and the status RPC's security mode/grants. The exact baseline fingerprint was unchanged after rollback. This is not an authenticated PostgREST test and does not change the isolated project or production. The passing changes are still uncommitted in the local worktree; remote PR #71 remains at `6a9d40ddc8919900547b4b0033b01575e386791a`, whose CI covers 35 pgTAP assertions.

Commit `4f34f54d6511b1420a84c65aafbc7db90f794de4` was pushed to PR #71. Its exact-head CI run [42132160046](https://github.com/mortapp/Mort/actions/runs/42132160046) completed successfully: seven jobs passed and `stripe-hosted-regression` plus `stripe-provider-e2e` were skipped by workflow conditions. The run verified 73/73 production migration sources and passed the updated 35-assertion Guardian-reader pgTAP suite against a clean local replay; the baseline fingerprint was unchanged (`170011|73|20261102113314|94a1b987774f994019ba6269b9abeb16|true`). It also reports 615 Flutter tests passed and 2 skipped, Deno 26 passed with 0 failures, and an Android device-test APK (not a Play-signed AAB). The prior exact-head run [42124858126](https://github.com/mortapp/Mort/actions/runs/42124858126) for commit `3d376d2d90b4048f50fd566d3a28b5f44ce45c52` ran the earlier 33-assertion version. The 35-test runner locally mirrors only the hosted `service_role` function-EXECUTE and direct-table-SELECT ACLs inside its rollback transaction; it adds no privilege to `anon` or `authenticated`. Separately, `node --test scripts/qa-guardian-application-reader-api.test.mjs` passed 17/17 locally; those tests use injected HTTP stubs and do not verify hosted API behavior.

The pgTAP suite's underage fixture has profile role `pending`, so its no-rows assertion is not itself an underage-Guardian reader test. Separately, the suite attempts to assign that underage profile the `guardian` role and expects SQLSTATE `23514` with `MORT_MINOR_ROLE_REQUIRED`; this verifies the schema rejects the invalid state without bypassing its trigger or constraint. It also checks that the reader's 18+ predicate appears in the account gate, row selection, and ID disclosure. The reader cannot be invoked as an underage Guardian through a valid database state, so that impossible-state result is not claimed as an RPC test.

The reviewed production function has no broad `is_admin` row-access bypass: its row scope is the applicant, job poster, or eligible linked Guardian. The pgTAP suite checks that `service_role` retains function `EXECUTE` and direct `job_applications` SELECT; it does not impersonate a staff reviewer or service-role caller. It also asserts that the reader definition has no broad `private.is_admin()` bypass. The API harness includes an administrator case, but that case is not a hosted result until an authorized reviewer fixture is provisioned.

Read-only inspection of production on 2026-11-05 confirmed `job_applications` has RLS enabled; `anon` and `authenticated` lack direct table `SELECT`, and `service_role` retains it. `get_my_job_applications(uuid)` is `SECURITY DEFINER`, has an empty `search_path`, grants execute to `authenticated` but not `anon`, and is `STABLE`. The current production function still has an authorization mismatch: the outer row predicate admits a Guardian on an active link with both consent timestamps, while the sensitive-ID `CASE` additionally requires Guardian role, active account, adult DOB, and confirmed Auth email. Thus an ineligible but still linked/consenting Guardian can receive the application row with the Guardian ID masked. The focused PR #71 migration is proposed and covered by local baseline pgTAP; it has not been applied to production. Do not represent this mismatch as fixed until the migration is approved/deployed and authenticated isolated API assertions pass.

The harness accepts partial fixture sets so independently available cases can run. Missing role/application cases and the expired-session case are reported as `SKIP` with a reason; they are never counted as passed. The CLI returns exit code 2 whenever any case is skipped, so partial coverage cannot look like a clean pass. It uses only the public anon/publishable key and password grant for accounts provisioned through normal workflows. It rejects service-role and secret keys, a production target, the deleted target, localhost, and conflicting generic production project configuration. It logs case name, HTTP status, row count, and skip reason only; it suppresses emails, passwords, tokens, UUIDs, and response bodies.

## External prerequisites for legitimate fixtures

Do not fabricate identities, legal acceptance, verification evidence, Guardian links/consent, or staff identities. Before account provisioning, obtain and record:

1. **Legal/product approval:** counsel or the designated legal owner confirms which currently approved Terms, Privacy Notice, minor/Guardian disclosures, retention rules, and QA consent language apply to synthetic teen/Guardian testing. Test accounts must accept the approved documents through normal onboarding; operators must not insert acceptance records.
2. **Account/email setup:** an authorized QA operator has permission to create synthetic accounts in the isolated project, and the configured email confirmation path can deliver to controlled test inboxes. Use no real minors or real identity documents.
3. **Verification provider:** if the workflow requires age or identity approval before creating an eligible teen/application, use only the approved provider's sandbox and documented test evidence/events. Confirm the provider and sandbox credentials with MORT's provider owner. No provider or successful evidence is assumed by this guide.
4. **Guardian workflow:** create the teen and adult Guardian via normal signup, send the real in-app invitation, and complete the required consent steps in the supported flow. To test revocation, use the supported revoke control after the connected baseline case and record the resulting fixture state. Do not create links or timestamps directly in SQL.
5. **Staff authorization:** an organization owner/security owner provisions an authorized reviewer/admin through the supported staff-assignment process, records approval and audit evidence, and removes the role after the QA window. Do not set staff flags manually or reuse a developer identity.
6. **Synthetic application:** create the teen application and poster-owned application using the supported application workflow. Preserve their UUIDs in the protected fixture file.

Wrong-role-linked Guardian or active-link/missing-consent states may be impossible through supported workflows by design. Do not weaken constraints to create them. The migration's adversarial pgTAP tests cover controlled database-state testing; the authenticated API harness reports those personas skipped unless an approved supported workflow can legitimately produce the fixture.

## Protected fixture file

Store the JSON outside the repository in a user-only protected directory, for example `%USERPROFILE%\OneDrive\Documents\Mort QA Secrets\guardian-api-fixture.json`. Do not attach it to a PR, print it, or commit it. Restrict its ACL to the QA operator. The fixture contains passwords and must be deleted securely when the QA window ends.

Schema version 1 (values below are placeholders, not credentials):

```json
{
  "schemaVersion": 1,
  "projectRef": "ckcxakhxqlkhppsxxjhv",
  "users": {
    "teenA": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "teenB": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "linkedGuardian": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "unlinkedGuardian": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "revokedGuardian": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "suspendedGuardian": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "missingTeenConsentGuardian": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "missingGuardianConsentGuardian": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "wrongRoleAdult": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "poster": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" },
    "administrator": { "email": "<controlled-test-inbox>", "password": "<secret>", "userId": "<uuid>" }
  },
  "applications": {
    "teenA": "<synthetic-application-uuid>",
    "teenB": "<synthetic-application-uuid>",
    "poster": "<poster-owned-application-uuid>"
  },
  "expiredSessionToken": "<optional-expired-authenticated-jwt>"
}
```

Fields for unavailable roles are omitted; a case requiring that persona is explicitly skipped. The optional expired JWT must have an expired `exp`, role `authenticated`, and UUID `sub`. Never put a service-role key or service token in the fixture.

## Run procedure

Use a fresh PowerShell process so generic production settings do not leak into the QA process. Set these process-scoped variables only after prerequisites and fixtures exist:

```powershell
$env:MORT_QA_TARGET = 'ckcxakhxqlkhppsxxjhv'
$env:MORT_QA_PROJECT_REF = 'ckcxakhxqlkhppsxxjhv'
$env:MORT_QA_SUPABASE_URL = 'https://ckcxakhxqlkhppsxxjhv.supabase.co'
$env:MORT_QA_ANON_KEY = '<isolated-project anon/publishable key>'
$env:MORT_QA_GUARDIAN_FIXTURE_FILE = '<absolute path outside repository>'
node scripts/qa-guardian-application-reader-api.mjs
```

Do not set `SUPABASE_SERVICE_ROLE_KEY`, `MORT_QA_SERVICE_ROLE_KEY`, or `MORT_QA_ALLOW_SERVICE_ROLE`. The harness rejects them, and never uses service-role access. If `MORT_SUPABASE_PROJECT_REF` is inherited with a non-QA value, start a clean process rather than changing user-level secret settings.

The intended post-fix application-reader contract is participant-only: teen applicant, the job's poster, and a currently eligible/consenting linked Guardian are evaluated by their own exact cases. A poster's Guardian ID must be null. An eligible applicant/Guardian retains the intended Guardian ID. Unrelated, revoked, suspended, wrong-role, missing-consent, anonymous, and expired-session callers must receive an explicit denial or an empty successful result **with no application rows**. A masked Guardian ID alone is not denial. Administrator access follows no special bypass in this RPC and is expected to return no application rows unless the administrator is also a participant.

Every API result is scoped to the isolated ref. Record the printed aggregate and per-case HTTP/row result in the readiness checklist. A skipped case is an external prerequisite, not a pass. Sign-out is attempted for each authenticated session. This script does not mutate hosted data.
