# MORT email guard local implementation checkpoints

This directory operates only the UUID-labelled synthetic MORT fixture. It does
not load repository secrets, run hosted migrations, contact IONOS, or modify
preserved Android releases. Auth remains Supabase's responsibility.

The subsystem is **incomplete and disabled by default**. Do not enable hosted
hooks or flip the private control flag based on these checkpoints. There are
no production guard HTTP entrypoints or delivery worker yet. The full private
proof/token-hook/cutover/restore/retention and requirement-matrix gates remain.

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
deno test --frozen --config supabase/functions/auth-email-guard.deno.json supabase/functions/_shared/auth_email_guard/ supabase/functions/_shared/secure_codes_test.ts
node --test web/auth/password-policy.test.mjs
```

The security/state suites require the two reviewed guard migrations installed
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
Public HTTP admission, password grants, final provider/token hooks, coherent
cutover/restore and full source-matrix coverage are still unfinished. No hosted
hook or worker endpoint is activated; these are partial implementation gates.

No global Docker teardown, fixture credential output, real email/purchase,
production rollout, or schema reset is part of these commands. Any assertion,
transport, identity, or cleanup failure is a failing checkpoint.
