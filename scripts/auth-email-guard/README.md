# MORT email guard local implementation checkpoints

This directory operates only the UUID-labelled synthetic MORT fixture. It does
not load repository secrets, run hosted migrations, contact IONOS, or modify
preserved Android releases. Auth remains Supabase's responsibility.

The subsystem is **disabled by default**. There are no production guard HTTP
entrypoints or hosted delivery worker. The controller permits only an explicit
private provider rehearsal; it rejects full activation. A real provider Send
Email hook and trusted request-to-hook binding are not installed. No fixture
PASS authorizes hosted activation.

## Reproducible checks

Use Node 22.18 or newer, Deno, and Docker Desktop's Linux engine from the repo:

```powershell
node --test scripts/auth-email-guard/fixture.test.mjs
node scripts/auth-email-guard/run.mjs --suite health
node scripts/auth-email-guard/run.mjs --suite dependency
$env:MORT_GUARD_PROBE='1'
node scripts/auth-email-guard/run.mjs --suite provider
Remove-Item Env:MORT_GUARD_PROBE
node scripts/auth-email-guard/run.mjs --suite security
node scripts/auth-email-guard/run.mjs --suite state
node scripts/auth-email-guard/run.mjs --suite issuance
node scripts/auth-email-guard/run.mjs --suite grant
node scripts/auth-email-guard/run.mjs --suite delivery
node scripts/auth-email-guard/run.mjs --suite load
node scripts/auth-email-guard/run.mjs --suite bypass
node scripts/auth-email-guard/run.mjs --suite hook-boundary
node scripts/auth-email-guard/run.mjs --suite smtp-fault
node scripts/auth-email-guard/run.mjs --suite cutover
node scripts/auth-email-guard/run.mjs --suite retention
node scripts/auth-email-guard/run.mjs --suite log-audit
node --test scripts/auth-email-guard/control.test.mjs scripts/auth-email-guard/coverage.test.mjs scripts/auth-email-guard/evidence.test.mjs
deno test --frozen --allow-env=ETHEREAL_API,ETHEREAL_WEB,ETHEREAL_API_KEY,ETHEREAL_CACHE --config supabase/functions/auth-email-guard.deno.json supabase/functions/_shared/auth_email_guard/ supabase/functions/_shared/secure_codes_test.ts
deno test --frozen --config supabase/functions/auth-email-guard.deno.json supabase/functions/mort-auth-email-hook/ supabase/functions/mort-auth-email-guard/
node --test web/auth/password-policy.test.mjs
node --test web/auth/challenge/controller.test.mjs web/auth/challenge/transport.test.mjs web/auth/challenge/build.test.mjs
# Set MORT_GUARD_BROWSER_MODULES to an installed Playwright package root when it
# is supplied by the desktop runtime rather than this repository.
node --test web/auth/challenge/browser.test.mjs
```

The security/state suites require the reviewed guard migrations installed
in the synthetic fixture's database. The runner does not apply migrations
automatically or pretend a missing schema is a successful denial.

Resource manifest: Auth 55421, DB 55422, TLS SMTP 55425, Mailpit HTTP 55424;
reserved guard HTTP 55426. All published ports bind exactly to 127.0.0.1.
Normal MORT's 54321–54323 services and unrelated Loop resources are separate.
Pinned Auth image is v2.197.0; confirmations are required, phone/anonymous
providers are disabled. Fake credentials/certificates live only in the ignored
`.superpowers` fixture directory with private ACLs. Compose receives an empty
env file and an allowlisted process environment. Existing resources are checked
before startup, including UUID, image, project, mounted volume and port bindings.

The local Keycloak adapter verifies a fixture-owned OIDC issuer with actual
RSA signatures and audience checks. It is never enabled in hosted MORT and uses
no Google/Apple credentials. This proves a stock-provider linking/cleanup path,
not a real Google/Apple end-to-end login or the final guard's OAuth compatibility.
Unverified OAuth can create a separate pending identity even on denial; cleanup
therefore resolves only the current run's generated synthetic mailbox addresses.

The consume primitive checks committed provider accounts, active generations,
delivery eligibility and authoritative time after locks. Wrong code/link/current/
grace guesses debit the addressed family only; the fifth failure exhausts it.
Success inserts one verifier-bound, independently timed 300-second capability
and consumes the family in one transaction. The separate `issuance` suite tests
rolling quota/queue/lease/cooldown/promotion transitions. `delivery` tests signed
hook admission through encrypted queue to certificate-validated SMTP capture.
Its deadline variation pauses only the owned capture, binds the reserved
loopback SMTP port to a progress-drip peer, observes socket teardown before
process exit, and restores the original container in `finally`.
Current-address redemption and envelope generation binding have regressions.
The actual ephemeral HTTP Continue/password pipeline uses committed private
state and supported Admin APIs. Admission is source 2/item 1/global 64, generic
denial 350 ms, store budget 250 ms; actual lock contention returns non-charged
Busy. No forwarded-header identity is accepted. The provider mutation origin
constraint requires a persisted, target-user Admin audit row from the same
transaction; marker metadata alone cannot authorize public password writes.
Audit persistence/transaction semantics are mandatory compatibility gates.
The actual fixture token-hook methods observed are password, oauth, otp and
token_refresh. The provider magic-link request was observed as otp, not an
assumed magiclink label. Real GET/hash/code signup/recovery and provider-created
PKCE exchanges have named negative tests and legitimate controls. Hosted
Google/Apple and existing PostgREST/Storage/Realtime JWT transports remain gates.

Standalone guarded pages are generated only with explicit local-fixture
configuration. Default-disabled generation writes nothing and preserves the
existing recovery flow. Browser tests use a disposable Chromium profile and
an owned local HTTP response stub to exercise scanner, reload/back, memory
binding, status colors and real network containment. Provider transactions are
tested separately by the actual delivery/grant suites. Main site integration,
hosted origin/service-worker scope, ingress binding and full source-matrix
coverage remain gates. No hosted hook or worker endpoint is activated.

The bounded real HTTP load probe uses two separately authenticated synthetic
ingress contexts, never spoofed forwarded headers. It caps test concurrency
at 20, total requests at 500 and wall time at 60 seconds. It pairs source-A
saturation/flood with source-B success, verifies Busy charges no guess, the
five-failure ceiling, bounded generic-denial timing and post-load legitimate
consume. This is one local availability experiment, not distributed-abuse or
complete matrix certification.

No global Docker teardown, fixture credential output, real email/purchase,
production rollout, or schema reset is part of these commands. Any assertion,
transport, identity, or cleanup failure is a failing checkpoint.

## Cutover, rollback and real backup restore

`control.mjs` exposes `planControl`, `applyLocalControl`, `backupFixture`,
`restoreFixture` and `discardBackup`. Planning is a dry run. Mutation requires
`localFixture:true, apply:true`; activate/restore additionally requires
`privateProviderRehearsal:true`. Plans declare `fullGuardActivationReady:false`.
The identity and every operated Docker resource are checked. These APIs do not
accept arbitrary Docker projects, ports, databases or backup directories.

An exclusive operation lock protects provider stop/transition/resume. Restore
uses actual binary pg_dump/pg_restore, verifies the private dump hash and UUID,
then advances an fsynced monotonic journal **outside the restored database**.
Provider ingress remains stopped until old authority is retired and the new
generation commits. A corrupt dump, missing/corrupt initialized journal,
concurrent writer or DB/journal mismatch fails closed. Never copy an old journal
alongside a database restore, automatically remove a stale operation lock, or
boot the provider first. A crashed writer requires operator inspection of the
owned operation, journal and database; availability is withheld until an explicit
fenced reconciliation. The fixture test exercises that refusal and reconciliation.
Production needs an independently durable journal/key-manager runbook.

The SQL transition captures verified baseline accounts before waiting on Auth
mutations. Pending or concurrently confirmed accounts cannot inherit proof.
It retires challenge families/items/capabilities/grants, clears encrypted work,
rotates generations and imposes a new refresh-session epoch. Tests preserve
verified password login while rejecting restored used/expired challenges,
reserved Admin writes and old refresh sessions. Rollback has lower assurance:
it restores the previous provider password flow, retires guard authority and
records a fresh generation. It is not proof of a complete hosted hook rollback.
Database restore also restores the snapshot's password state; this rehearsal
does not claim to preserve post-snapshot passwords or revoke already-issued JWTs
on transports absent from the fixture. Dumps stay in the private ignored ACL
directory and each test deletes its own dump and integrity sidecar in finally.

## Automatic retention

`startRetention` starts a non-overlapping local worker (60-second default).
Database-authoritative sweeps use bounded lock/statement deadlines, immediately
erase expired encrypted envelopes and fence expired capabilities/grants. Terminal
challenge/permission/hook metadata is removed after 24 hours; quota metadata after
two hours preserves the rolling-hour abuse window. Active proof/generation data
is retained; orphan data is removed when no authority depends on it. Cleanup
cannot refund current quotas, grant proof, or authorize delayed provider writes.
The automatic timer, actual delayed Admin write denial and orphan purge execute
in the retention suite. No hosted schedule is installed by these migrations.

## Requirement evidence

`requirements.json` preserves all 519 source records. `sources/matrix.md` pins the
191 current cases. Both digests, IDs and counts are checked. `cases.mjs` lists
the exact assertions for each current case and original operational MD-115–120.
The certifier captures assertion identities only **after execution succeeds**,
including source line and execution count; it never captures assertion operands.
Historical results are not inherited. Missing assertions produce NOT_RUN;
unavailable integrations remain BLOCKED; approved absent peek features are
OWNER_SCOPED_OUT. Review the named assertions and their scope, not only totals.
Each integration suite records before/after state digests and the context digest
is the final cleanup snapshot; concurrency 20 is the invocation
maximum from the load suite, not a claim that every case ran with 20 clients.

```powershell
node scripts/auth-email-guard/certify.mjs
# Explicitly permit exit 0 for successful executable local gates only:
node scripts/auth-email-guard/certify.mjs --allow-external-gates
```

The second command still emits `fullGuardCertified:false`. The first exits 2
while integration gates remain, or 1 on assertion/log/cleanup failure. Output is
sanitized JSON for import into managed security evidence storage. It is not a
release artifact. Guard-source cleanliness is reported separately from preserved
unrelated work. HEAD, status and source hashes are checked again before export;
changes during a run invalidate its evidence. Each suite audits only owned
Auth/DB/SMTP logs. Fixture GoTrue
logs use fatal level because its lower-level auth events include full addresses;
provider transaction-origin audit records remain enabled and private. No hosted
logging setting has changed. Hosted traces/error reporters need their own audit.
