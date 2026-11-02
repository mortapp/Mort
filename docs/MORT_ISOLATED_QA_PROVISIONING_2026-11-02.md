# MORT isolated QA provisioning — 2026-11-02

## Scope and safety

This runbook is for Supabase isolated project `ckcxakhxqlkhppsxxjhv` only. Its
current URL must be verified as `https://ckcxakhxqlkhppsxxjhv.supabase.co` before
every run. Production `jxbnrkasktbhtiujkhay` remains read-only; the deleted
project `rakjydmgwwgtdislanbt` must never be contacted. Do not use production
user data, production credentials, direct table writes to simulate user
workflows, trigger/RLS bypasses, fabricated legal approvals, fabricated
verification evidence, or self-provisioned staff identities. Do not turn on
publishing, payments, real document collection, or AI.

This runbook describes prerequisites and supported steps. It does not assert
that any account, fixture, provider integration, staff member, or legal approval
has been created. Current isolated inspection found zero Auth users, profiles,
legal documents, verification cases, applications, Guardian links, staff
identities, and staff memberships. No Edge Functions or verification provider
integration is configured. The project is PostgreSQL 17, but its migration
history is not the production baseline: it has 82 entries, including ten QA
specific migrations, and lacks production version
`20261102113314_guardian_id_response_mask_production`. Do not treat it as an
exact production clone or apply proposals whose source guards do not match.
The exact migration/hash comparison and reconciliation plan are in
`MORT_SUPABASE_MIGRATION_DRIFT_2026-11-02.md`. The existing isolated project has
six Storage buckets and zero objects; preserve those bucket definitions and all
ten QA migrations. Do not reset or replay the baseline over this project.

## Prerequisites that require an owner decision or external setup

| Area | Required before positive tests | Current state / responsible party |
|---|---|---|
| Legal | Counsel-approved, test-appropriate document text and publication authorization; publish effective versions and role/age requirements in isolated QA using the approved legal publication process. Accounts must accept those published versions through normal onboarding. | No legal documents or role requirements exist in isolated QA. Counsel/owner must approve; no text or approval may be invented. |
| Age verification | Select an approved age-evidence policy/provider; obtain a legitimate sandbox organization, credentials and callback signing configuration; exercise a supported provider result. | No MORT provider integration, Edge Function, provider result, or credentials are configured. Yoti documents a sandbox with mocked outcomes and requires a verified organization and credentials. Persona offers test/simulation environments; its suitability for MORT age and school evidence must be confirmed. These are candidates, not configured providers. |
| Identity verification | Select and approve an identity provider/policy; obtain its sandbox account and signing credentials; integrate and validate signed case-matched results. | No provider credentials or integration. Yoti documents mock IDV data; Veriff documents a test integration; Persona documents simulated integration tests. None proves live identity verification or is connected to MORT. |
| School ID | Counsel/product must define acceptable school evidence and retention; provider must confirm that its sandbox and product can validate that evidence type. | No school-ID provider or configured path. Generic document simulation is not evidence that school IDs are verified. No documents may be uploaded until explicitly approved. |
| School email | A synthetic user must control a confirmed mailbox at a domain already approved in the isolated school-domain registry; retain domain provenance and use the normal verification flow. | Isolated catalog has two active, verified school-domain entries; their names are intentionally not disclosed here. No QA mailbox/account exists. An owner must confirm authorized test-mailbox access. A controlled education test domain is an option only if Google/domain eligibility and verification are approved. |
| Staff/reviewer | An operator authorized by MORT must designate the first reviewer; complete required safeguarding/privacy/security/fraud/policy training; provision staff identity and department-scoped membership via an approved owner-operated process with MFA and audit. | No staff identity/membership or provisioning RPC exists. Staff tables deny authenticated/service-role DML; the existing audit RPC requires an already-active staff membership. Bootstrap is therefore an operational owner/authorized-administrator prerequisite, not a self-service test action. Do not insert rows or weaken checks to bootstrap. |
| Synthetic accounts | Confirmed email accounts, unique credentials, DOB/role-appropriate normal onboarding, effective legal acceptance, supported verification, and role activation. Use a secure synthetic mailbox/test domain and unique test passwords. | No Auth users or credentials exist. No account was created. Auth confirmation and verification providers must be available first. |
| Isolated project parity | Reconcile the isolated migration baseline and apply reviewed changes only in a disposable/isolated target after confirming exact source hashes and recovery path. | Isolated has 82 migrations vs production's reconciled 73 and has QA-only schema. Three functions in proposal 901 have different source MD5s, so its exact-source guard must reject it there. No proposal was applied. |

### Provider sandbox reference points

These are official provider documentation, not recommendations or an assertion
that MORT has selected them. Based on their published capabilities:

- [Yoti Age Verification sandbox](https://developers.yoti.com/age-verification/sandbox-introduction) supports mocked outcomes only; the integration guide requires a verified Yoti organization/service and sandbox signing credentials.
- [Yoti Identity Verification sandbox](https://developers.yoti.com/identity-verification/sandbox) supports mock data and simulated approve/reject outcomes. Yoti's [onboarding page](https://developers.yoti.com/identity-verification/production-keys) says the free sandbox can be used before account approval. [Yoti supported documents](https://developers.yoti.com/identity-verification/supported-documents) lists government identity documents; it does not establish school-ID acceptance.
- [Persona environments](https://docs.withpersona.com/environments) support simulated pass/fail without real verification. Persona says information extraction and verification technology testing requires contacting them; this does not establish a school-ID workflow.
- [Veriff test integration](https://devdocs.veriff.com/docs/how-to-create-an-integration)
- [Veriff supported identity document types](https://devdocs.veriff.com/v1/docs/supported-document-types) lists passport, ID card, driver's license, residence permit and visa for IDV; school ID is not listed. Veriff test decisions are manually triggered and are not actual Veriff verification outcomes.
- [Google Workspace for Education test domain](https://knowledge.workspace.google.com/admin/getting-started/editions/create-a-test-domain-with-google-workspace-for-education?rd=1&visit_id=639178287111378853-1944727267)

No provider is selected for MORT. Yoti's published age and IDV sandboxes are
documented candidates for exercising their separate integration result paths
with mock outcomes; neither proves a real verification. Age sandbox onboarding
requires a verified organization/service; its IDV sandbox is documented as
available before organization approval, with sandbox keys. Persona and Veriff
can simulate result handling, with the limitations above. None of the selected/current MORT
providers is confirmed to verify school IDs; the published Yoti/Veriff document
lists do not include school ID, so MORT must get written provider confirmation
before adopting one for that case type. No sandbox credentials or provider
integration are configured. A mocked outcome must never be labeled as an actual
verified identity, age, or school enrollment in production.

## Supported account and fixture sequence

Once prerequisites are explicitly fulfilled, create the fixtures in this order
using the normal Auth, onboarding, legal, provider, Guardian, and application
workflows. Capture IDs from supported RPC responses or owner-authorized
read-only fixture inspection; never fabricate evidence or insert application
rows directly.

1. Create and confirm distinct synthetic applicant, poster, connected Guardian,
   revoked Guardian, unrelated-user, and administrator Auth accounts.
2. Complete the applicable role onboarding and accept current published legal
   versions for each account.
3. Obtain provider-backed, case-appropriate test results for required age,
   identity, school-ID, and school-email tracks. Route review through the
   authorized, trained reviewer. Rejections and unavailable provider states
   remain failures; do not force a successful status.
4. Connect the Guardian using the teen's `create_guardian_invite_v2`, the
   Guardian's `accept_guardian_invite`, and both parties' current
   `mort_set_guardian_consent` actions. Create the revoked-Guardian role by
   completing the valid link first and then calling the supported revocation or
   unlink workflow. Verify revocation took effect before testing.
5. Create a synthetic eligible job/application through a reviewed isolated QA
   fixture workflow that respects the isolated release controls. No production
   publishing toggle or production data may be touched. Ensure the linked
   Guardian and consent state are bound to the expected application.
6. Have an authorized operator provision the administrator only through an
   approved staff onboarding process. Verify MFA, required training, department
   scope, permissions, and audit trail before using it.
7. Set the harness values below in an approved local secret store or isolated
   CI secrets. Do not commit `.env` files or print environment values.
8. Run the Guardian API harness and inspect its exit status and complete
   non-secret output. Run separate authenticated sessions for each race test;
   a shared connection or advisory-lock-only check is not a workflow race test.

If one prerequisite is unavailable, stop only the dependent positive test and
run the independent negative tests. Do not weaken safeguards to get a green
result.

## Harness inputs and commands

`scripts/qa-guardian-id-rpc-privacy.mjs` requires:

```text
QA_SUPABASE_URL
QA_SUPABASE_ANON_KEY
QA_SUPABASE_SERVICE_ROLE_KEY     # isolated server-side only; never a client key
QA_APPLICATION_ID
QA_GUARDIAN_ID
QA_APPLICANT_EMAIL / QA_APPLICANT_PASSWORD
QA_POSTER_EMAIL / QA_POSTER_PASSWORD
QA_CONNECTED_GUARDIAN_EMAIL / QA_CONNECTED_GUARDIAN_PASSWORD
QA_REVOKED_GUARDIAN_EMAIL / QA_REVOKED_GUARDIAN_PASSWORD
QA_UNRELATED_EMAIL / QA_UNRELATED_PASSWORD
QA_ADMIN_EMAIL / QA_ADMIN_PASSWORD
```

Use distinct synthetic accounts. The service-role credential must stay in a
server-only secret store and be used only for the harness's authorized
administrative comparison. Never pass it to a Flutter/web client or include it
in shell tracing, CI logs, screenshots, SQL files, source control, or chat.

After configuring the approved isolated secret context:

```powershell
node scripts/qa-guardian-id-rpc-privacy.mjs
node scripts/qa-isolated-anonymous-safety-rpcs.mjs
```

The first command verifies applicant, poster, connected and revoked Guardian,
unrelated user, administrator scope, nested status-update response, direct
table denial and service-role behavior. The second command is anonymous-only.
Neither command alone is a substitute for two-session workflow concurrency
tests.

## Actual execution on 2026-11-02

The exact Guardian harness was run against the isolated project using its
publishable key and no accounts/fixtures. It returned:

```text
PASS anonymous: get_my_job_applications RPC denied (42501)
PASS anonymous: nested status-update RPC denied (42501)
PASS anonymous: direct application table read denied (42501)
[qa-guardian-id-rpc-privacy] BLOCKED role matrix before account login: missing isolated QA setup: QA_APPLICATION_ID, QA_GUARDIAN_ID, QA_APPLICANT_EMAIL, QA_APPLICANT_PASSWORD, QA_POSTER_EMAIL, QA_POSTER_PASSWORD, QA_UNRELATED_EMAIL, QA_UNRELATED_PASSWORD, QA_CONNECTED_GUARDIAN_EMAIL, QA_CONNECTED_GUARDIAN_PASSWORD, QA_REVOKED_GUARDIAN_EMAIL, QA_REVOKED_GUARDIAN_PASSWORD, QA_ADMIN_EMAIL, QA_ADMIN_PASSWORD
[qa-guardian-id-rpc-privacy] BLOCKED service-role preservation check: QA_SUPABASE_SERVICE_ROLE_KEY is not configured
```

The anonymous safety-RPC script was executed against the same isolated project:

```text
[qa-isolated-anonymous-safety-rpcs] PASS get_my_job_applications: anonymous request denied (42501)
[qa-isolated-anonymous-safety-rpcs] PASS get_job_application_eligibility: anonymous request denied (42501)
[qa-isolated-anonymous-safety-rpcs] PASS update_my_job_application_status: anonymous request denied (42501)
[qa-isolated-anonymous-safety-rpcs] PASS mort_accept_job_application: anonymous request denied (42501)
[qa-isolated-anonymous-safety-rpcs] PASS schedule_active_job_checkin: anonymous request denied (42501)
[qa-isolated-anonymous-safety-rpcs] PASS complete_active_job_checkin: anonymous request denied (42501)
[qa-isolated-anonymous-safety-rpcs] PASS job_applications direct SELECT denied (42501)
```

No authenticated role assertion, positive Guardian-ID assertion, nested
status-update payload inspection, service-role assertion, or actual workflow
concurrency test ran. The reasons are the missing prerequisites above, not a
test pass. The project catalog inspection and anonymous API requests were
read-only. Production was not contacted for these tests or changed.

## Workflow concurrency matrix still required

These tests require two independent authenticated clients, valid synthetic
fixtures, and the listed state. Capture both RPC responses, committed state,
and expected audit/notification effects after each race.

| Race | Required fixture/session state | Required assertion |
|---|---|---|
| Submission vs block | Eligible teen applicant and poster; concurrently submit application and block same participant pair | Shared lock serializes; if block commits first submission is denied; no blocked application, duplicate, or orphan audit/notification is created. |
| Acceptance vs block | Pending application; poster accepts while applicant/poster pair block is submitted | Exactly one serialization order; block-first yields no assignment/conversation; accept-first may finish only before the subsequent block; no partial side effects. |
| Verification revoke/stale vs submit | Verified synthetic teen and provider-backed current evidence; reviewer revokes/updates case while teen submits | The locked current state decides; stale/expired/revoked state denies after serialization; stale snapshot cannot authorize. |
| Verification revoke/stale vs accept | Pending app and verified teen; reviewer changes case while poster accepts | Same current-state gate applies at acceptance; no assignment if verification is stale/revoked. |
| Check-in completion vs retry | Active synthetic assignment, scheduled check-in, two teen sessions with same completion request ID | One transition and one audit/notification side effect; retry is an idempotent stable response; conflicting key/payload denied. |
| Reversed pair locking | Two authenticated sessions request opposite-direction block/message/application actions for the same two users | Deterministic participant ordering avoids a deadlock; outcomes obey committed block state and no unauthorized message/assignment. |

## Staff reviewer provisioning blocker

Do not bootstrap the first reviewer through SQL or self-issued staff claims.
Current catalog evidence shows zero private staff identities/memberships and no
staff provisioning RPC. Staff tables have no INSERT/UPDATE grant for
`authenticated` or `service_role`; the audit RPC requires an already active
staff identity. `private.staff_has_permission` enforces active membership,
department/role permission, JWT AAL2, recent authentication, and mandatory
training. An MORT-authorized owner/administrator must define and execute a
reviewed break-glass/first-reviewer provisioning operation, record the
authorization and audit evidence, and separately approve the person's scoped
role. Until then, provider-positive verification and admin-role tests remain
blocked.
