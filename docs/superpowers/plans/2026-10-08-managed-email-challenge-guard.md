# MORT Managed Email Challenge Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task in this session. `AGENTS.md` requires a single agent. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and prove a server-enforced, ten-minute, five-failure email confirmation/recovery guard in an isolated local MORT fixture, leaving hosted Auth unchanged.

**Architecture:** Supabase remains the account/password/session authority. A signed Send Email hook creates private challenge families and an encrypted delivery outbox; a Continue endpoint atomically consumes a family and issues a verifier-bound capability. Supported Admin APIs perform credential changes subject to a private grant checked inside the provider write transaction; a custom access-token hook checks address proof.

**Tech Stack:** PostgreSQL 17, pinned GoTrue `v2.197.0`, Deno/Web Crypto, Node 22+ builtin tests, existing Supabase JS/pg, Flutter/Dart, standalone browser ES modules. Verified local adapter pins: `standardwebhooks@1.1.1`, `nodemailer@10.0.15`, `pg@8.22.0`. Deno's dependency-age policy rejected the originally proposed fresh Nodemailer 10.0.16; the established 10.0.15 release passed actual certificate-validated fixture STARTTLS without weakening that policy. Registry/advisory observations are dependency inputs, not a security certification.

**Spec:** [Approved specification](../specs/2026-10-08-managed-email-five-attempt-guard-final-draft.md), including section 13A. Owner approved the specification and limits in chat on 2026-10-08, then approved execution together with `MORT_Implementation_Plan_Review.md`. The amendments below resolve that review before execution. Guard completion requires new runtime evidence.

## Approved review amendment (2026-10-08)

1. **Tasks 1/5/7/10/12:** replace the 5.5-second/20-slot denial schedule with a 350 ms generic-denial deadline, a 250 ms total redemption-store budget, per trusted source admission 2, per canonical challenge admission 1 and global admission 64. Contention/overload returns `Busy = {ok:false,message:'MORT is busy. Try again shortly.',retryAfterSeconds:1}` with HTTP 429, consumes no failure/send quota and preserves the page's link/verifier for retry. Store timeout rolls back any uncommitted failure; uncertain committed outcomes require state reconciliation, never a second capability. The page announces **Checking…** while awaiting Continue. Uniformity and legitimate access under a single-source flood require measured tests.
2. **Tasks 5/6/9/12/14:** preserve approved 5/5/40 hourly limits, adding **5 actual dispatch attempts per trusted source per rolling hour**, and at most **3 new families per source per rolling hour**. On reaching 20 global attempts emit one secret-free threshold alert per rolling-hour alert window. A local-only owner control can adjust caps after dry-run review, with old/new integer values and audit event only; no client adjustment. A distinct busy/rate-limit result must never instruct users to burn email quotas. Test recovery by source B after source A exhausts its sub-limit. Distributed abuse and recipient-targeted quota exhaustion remain availability limits, not solved identity problems.
3. **Tasks 4/7/10/11:** one password policy for new signup, confirmation and recovery: 12–128 UTF-16 code units, uppercase, lowercase, digit and symbol. Preserve older-password sign-in. Add shared boundary fixtures comparing Flutter and web/server acceptance; align copy and upper-bound validation rather than weaken a configured provider requirement.
4. **Tasks 1/2/6/14:** `TrustedSource` is a server-verified ingress identity, never a browser header or hook user metadata. The fixture derives it from its owned proxy's socket and separately authenticated synthetic contexts. Hosted activation needs a documented authoritative client-address source, stripping/overwriting of forwarded headers, and a verified one-use binding from request admission to the signed email hook. Supabase's Send Email payload does not automatically prove caller IP. If that binding cannot be demonstrated, source quotas are not production-certified and activation remains blocked; no guessed `X-Forwarded-For` trust.
5. **Task 6:** claiming before signup commit defers until the account is visible or the 30-second issuance lease expires. Deferred work consumes no dispatch quota and cannot permanently retire a valid pending signup early. Provider rollback expires the item without sending.
6. **Task 2:** verify package versions exist, registry integrity and advisory results before loading them; perform a frozen lockfile check. Test the real Deno SMTP adapter. If incompatible, record a ruling and use a dedicated private Node delivery worker with the identical bounded interface; never an insecure transport fallback.
7. **Task 12:** derive source counts from immutable source bytes and preserved inventories, pin source SHA-256 and unique/consecutive matrix IDs, and reject truncation/hash drift. The previously reported 519/191 counts are baseline observations, not hard-coded evidence substitutes.
8. **Task 1:** define executable `FixtureConfig`, `FixtureIdentity`, `FixtureHandle` contracts in fixture types; assert actual observed identity rather than trusting descriptive labels.

These amendments supersede contradictory wording in the original task steps below. They are covered by the user's approval of the supplied review and instruction to finish; no additional design approval is pending. Hosted activation stays separately gated.

## Execution checkpoints (2026-10-08)

- The user later explicitly authorized one subagent for the separate object authorization audit and a push to the feature branch. This is the only delegation exception; the email guard remains single-agent. Four validated ownership gaps were fixed and the scoped checkpoint pushed at `8d3783a3dc84173a9c2e7de51e2a5f125cd441cf`. No merge/production rollout.
- Task 1 partial: exact generated-credential Auth/DB/TLS-capture fixture and 21 identity/target units pass. PostgREST/Storage/Realtime/guard components are not yet present. Docker Desktop's internal-only bridge prevented loopback publishing; the scoped fixture uses a dedicated labelled bridge and exact loopback bindings instead. This does not prove egress isolation.
- Task 2 partial: direct confirmation denial, Admin replacement+confirmation, actual delayed-write expiry/stale-marker fencing, token cleanup/refresh revocation, and real verified OAuth linking/password cleanup probes pass. The custom-provider route refused the local issuer under SSRF policy; the supported built-in Keycloak adapter is now bound only to the fixture's local issuer and fake client configuration. It verifies real RSA signatures/audience, and allows the actual stock-provider cleanup positive control without disabling SSRF or enabling arbitrary issuers. Unverified claims cannot confirm/sign into the original pending account. A provider denial can still create a separate pending identity, so cleanup resolves only the current run's owned generated mailboxes. No live Google/Apple OAuth end-to-end claim. Complete PKCE/OTP/access-token-hook and existing-JWT transport cases remain unrun.
- Task 3 actual CLI migration: `supabase/migrations/20261008052707_mort_email_challenge_guard.sql`. Default-off private eleven-table RLS foundation passed fixture privilege checks and was applied through local CLI with the separate authorization migration. No auth hook, provider trigger or guard HTTP route is activated. Retention/deletion/runtime service-owner gates remain incomplete.
- Task 4 cryptography/parser/redaction units and AES-GCM outbox-binding unit pass (13 total Deno tests including existing school-code units). Duplicate escaped/nested keys, invalid UTF-8, canonical credentials and strict bounded inputs are tested. Password boundary fixtures match Dart/browser/server; focused Flutter and website tests pass. Actual signed hook/SMTP dispatch worker is not implemented by these units.
- Task 5 partial runtime: consume plus CLI-created delivery lifecycle and generation-binding helpers pass actual fixture integration. Shared failures, concurrent one-use consume, current address binding, fixed deadlines, rolling account/source/recipient/global quotas, twenty-item concurrent queue cap, two concurrent leases, replay idempotency, acknowledgment-anchored cooldown/grace and expired/ambiguous outcomes have positive/negative controls. Private store adapter is fixture-only. This is not complete source-matrix or public gateway certification.
- Task 6 partial runtime: signed raw-byte Standard Webhooks/freshness/bounded parsing and generation-bound AES-GCM admission pass 3 new Deno tests. Actual Deno private-store-to-TLS-SMTP capture succeeds; wrong-key successor is rejected without SMTP quota and retains the old usable item. A progress-drip SMTP peer proves the hard deadline destroys the owned socket before process exit; removing explicit destruction fails the probe, restoring it passes. Only the UUID-owned capture is paused/restored for this local test. No hosted ingress binding, installed provider hook or public worker endpoint is certified.
- Authoritative execution evidence is saved through managed Codex Security storage in `hardening/auth-email-guard-execution-progress-20261008.md`. This checkpoint does not inherit PASS status for the 191/519 source matrix entries.
- Tasks 7/8 partial runtime: default-off CLI migrations add capability reservation, serialized generations/grants, actual provider mutation fencing, private reconciliation and address-proof token hook. Real provider tests cover direct-link/OTP denial, public password borrowing, stale Admin bodies against newer grants, post-lock expiry, current confirmed password/refresh and verified fixture OAuth positives. A reproduced public-write borrowing defect required a deferred provider-owned same-transaction Admin audit-origin constraint; persisted audit/transaction semantics are now a mandatory activation gate. Actual observed token method labels: password, oauth, otp, token_refresh. Live provider breadth and old-JWT transport gates remain.
- Actual ephemeral HTTP signed-hook/encrypted-outbox/TLS capture/Continue/password/Admin/sign-in pipeline passes. A real database lock returns Busy without incrementing failures. Gateway unit regression proves malformed-query denial cannot bypass source/global admission. Nine normal local backend regression suites passed with their existing target checks and the guard disabled; no hosted customer data was used.
- Task 10 partial: standalone default-disabled builder, memory-only browser controller/fixture transport and black/gray confirmation/recovery pages are implemented. Actual disposable Chromium with an owned local response stub proves zero scanner redemption, explicit human POST, verifier binding, green/red text/icons, cleared password fields, no web storage/third-party traffic/secret URL/referrer, reload/back non-replay and restrictive runtime headers. Provider commit behavior is separately proven by the real fixture HTTP suite. Main site integration and hosted origin audit remain gates; no browser result is a hosted deployment or device claim.
- Task 12 bounded local HTTP load probe passes: maximum 20 concurrent/500 total/60-second ceiling, separately authenticated synthetic sources, source-B success during source-A saturation, zero-charged Busy, shared failure ceiling, generic-denial timing and legitimate post-load consume. Full individual 191/519 traceability and distributed/provider breadth remain unfinished; the experiment does not inherit statuses for matrix rows.

## Global Constraints

- Local `mort-mobile` only; synthetic accounts, fake credentials and local SMTP capture. No hosted writes, real emails, public traffic, Loop, emulator, Play build, upload, merge or payment activation.
- Preserve every +115/+116 artifact and its evidence. Planning baseline HEAD: `76e4d865dbb0c4abd2f1d164149b1915ea02b22b`. Existing dirty Flutter/backend/website work must survive; it is not part of a clean guard candidate automatically.
- Additive migrations only; create filenames through the installed Supabase CLI. Never rewrite applied migration history or write provider password/hash/token columns directly.
- Codes: 8 digits using cryptographic rejection sampling. Links, capabilities and browser verifiers: 32 independently random bytes each, canonical unpadded base64url (43 characters). Locators: canonical lowercase UUIDs, never authority alone.
- Family: 600 seconds, 5 failures shared by all items/representations; 60-second grace and promotion-anchored cooldown; at most 2 eligible items. Capability: independent 300-second lease, one use, immutable verifier binding.
- Per rolling hour: 5 new families/account/purpose; 5 actual SMTP dispatch attempts/bound recipient across purposes; 40 total auth dispatch attempts. Queue limit 20; delivery concurrency 2; issuance/attempt lease 30 seconds; lock/statement timeouts 2/5 seconds.
- All deadline decisions use `clock_timestamp()` **after locks**; equality expires. No workstation clock changes. Hook admission uses a separate 3-second budget within the documented HTTP hook timeout; hook timestamps allow at most 300 seconds past and 30 seconds future.
- Secrets stay in server memory or protected configuration. Challenge/capability rows contain digests only. An async outbox contains authenticated ciphertext only, under a separate backend key, deleted on terminal delivery. No bodies, recipient lists, tokens, passwords, hashes or secrets in evidence/logs/browser storage.
- Default controls are disabled. Mode-disabled pages preserve the existing provider recovery flow. Mode-enabled pages reject legacy credentials; do not accept both flows as a bypass.
- No email-code login, guest mode, address-plus-code lookup, peek endpoint, fake Pro, role changes or weaker school/safety checks. A pending account requires a replacement password; recovery never confirms a pending account or signs anyone in.
- Private tables have RLS and no client grants; private helpers are not executable by `PUBLIC`, `anon` or `authenticated`. Authority is never derived from `user_metadata`, forwarded headers, addresses supplied by the browser or operation metadata alone.
- All 519 overlapping source entries retain their IDs and history; all 191 current matrix requirements must map to executable assertions. Do not turn static inspection into runtime evidence or count requirements as independent tests.
- Actual runtime security evidence is saved through managed Codex Security artifact tools. Product code/spec/plan files may use normal file tools. Only passed checks on the final exact committed candidate can establish completion.

## Review Focus

1. A mail scanner opens and executes the page repeatedly: no network request containing the link secret and no consume until the person presses Continue (Task 10).
2. A successful Continue response is lost, or the page refreshes: no second capability and no verifier fallback; a fresh quota-controlled request can recover (Tasks 5, 7, 10).
3. Signup's hook succeeds but the provider transaction rolls back: an outbox entry cannot verify or email a nonexistent account; cleanup releases its bounded lease without refunding dispatched attempts (Tasks 2, 6).
4. The normal local stack auto-confirms email and could hide a broken guard: the dedicated fixture explicitly requires confirmation and rejects an auto-confirm configuration before tests (Task 1).
5. A revoked operation's HTTP request arrives after a later legitimate reset: the old marker cannot resurrect authority, while the new owner operation still completes (Tasks 2, 8).

---

## File and interface map

Paths below are relative to this worktree. These files do not yet exist unless marked **modify**. Keep modules within this subsystem; do not refactor unrelated auth/friends code.

| Files | Responsibility |
|---|---|
| `scripts/auth-email-guard/fixture.mjs`, `fixture.test.mjs`, `compose.yaml`, `run.mjs` | Exact local target validation, isolated Docker services, lifecycle, test dispatch and cleanup |
| `scripts/auth-email-guard/provider.test.mjs`, `provider-probe.sql` | Disposable P1–P5 provider experiments; no normal-stack/hosted changes |
| CLI-created migration ending `_mort_email_challenge_guard.sql` | Private store, service functions, proof/grant fences, disabled mutation trigger and token hook |
| `supabase/functions/_shared/auth_email_guard/{types,crypto,parser,store,outbox,delivery,provider,redaction}.ts` and matching `_test.ts` files | Contracts, cryptography, strict input handling and server adapters |
| `supabase/functions/mort-auth-email-hook/{index,handler}.ts` | Standard Webhooks verification and bounded issuance/outbox admission |
| `supabase/functions/mort-auth-email-guard/{index,handler}.ts` | Continue and restricted password operations |
| `supabase/functions/mort-auth-email-worker/{index,handler}.ts` | Authenticated, bounded outbox delivery and reconciliation; no public worker authority |
| `supabase/functions/auth-email-guard.deno.json` | Pinned import map/test configuration limited to these functions; root `deno.lock` updated only for these imports |
| `scripts/auth-email-guard/{state,delivery,grant,security,cutover,load}.test.mjs` | Real database/provider/SMTP assertions |
| `scripts/auth-email-guard/{cases,coverage,evidence}.mjs`, `coverage.test.mjs` | Stable requirement mapping, sanitized evidence serialization and completeness checks |
| `scripts/auth-email-guard/control.mjs`, `control.test.mjs` | Local-only dry-run/activation/rollback/restore controls with explicit fixture identification |
| `web/auth/challenge/{controller,transport}.mjs`, matching `.test.mjs` files | Neutral entry, in-memory secrets, Continue, password-entry state and generic errors |
| `web/auth/confirmation/{index.html,confirmation.js}` | Standalone confirmation/replacement-password page |
| **Modify** `web/auth/recovery/{index.html,recovery.js,recovery.test.mjs}`, `web/auth/build-auth-pages.mjs` | Guard-mode recovery UI and generation; preserve disabled-mode behavior |
| **Modify if required** Flutter auth repository, verification screen and auth navigation tests | Replacement-password copy and HTTPS link compatibility, no architecture redesign |
| **Modify** `docs/security/MORT_AUTH_EMAIL_OPERATIONS.md` | Actual local outcomes, operational controls, hosted blockers; no claimed activation |

### Shared contracts (defined in `types.ts`)

- `Purpose = 'confirmation' | 'recovery'`; `GuardMode = 'disabled' | 'local_fixture'` for this execution. Hosted enabled mode is not emitted.
- `BoundEvent = {eventId:string, accountId:string, recipient:string, purpose:Purpose, signedAt:number}`. Recipient is validated provider input; never an HTTP caller-selected target.
- `Credential = {kind:'code'|'link', value:string}`; `ContinueInput = {itemId:string, credential:Credential, verifierHash:string}`. Hash encoding is lowercase SHA-256 hex, 64 characters.
- `PasswordInput = {capability:string, verifier:string, password:string}`. A capability carries no caller-selected account, email or purpose.
- `Failure = {ok:false, message:'That link or code is not valid. Request a new email.'}`; all well-formed redemption denials use the same body/status/headers and response scheduling.
- `ContinueResult = Failure | {ok:true, capability:string, maskedRecipient:string, purpose:Purpose, familyExpiresAt:string, capabilityExpiresAt:string}`. Dates are server UTC ISO strings.
- `PasswordResult = Failure | {ok:false, message:'Choose a password that meets the requirements.'} | {ok:true, message:'Password updated. Return to MORT to sign in.'}`. Policy errors are available only after possession checks.
- `DeliveryLease = {itemId:string, attemptId:string, generation:number, expiresAt:string, encryptedEnvelope:string}`; `DeliveryOutcome = 'acknowledged'|'failed'|'ambiguous'`.
- `ReservedOperation = {operationId:string, accountId:string, purpose:Purpose, addressGeneration:number, fenceGeneration:number, expiresAt:string}`. No raw authority in `app_metadata`.
- `GuardStore` owns transaction boundaries: `issue(event:BoundEvent, material:IssuanceMaterial):Promise<IssuanceResult>`, `claimDelivery():Promise<DeliveryLease|null>`, `finishDelivery(lease:DeliveryLease,outcome:DeliveryOutcome):Promise<boolean>`, `consume(input:ContinueInput,material:ConsumeMaterial):Promise<ContinueResult>`, `reservePassword(input:PasswordInput):Promise<ReservedOperation|Failure>`, `reconcileOperation(operationId:string):Promise<'committed'|'pending'|'fenced'>`.
- `IssuanceMaterial = {itemId:string, codeHmac:string, linkDigest:string, encryptedEnvelope:string}`; `IssuanceResult = {accepted:boolean}`. `ConsumeMaterial = {capabilityDigest:string, capabilitySecret:string}`; `consume` receives canonical parsed input plus server-computed credential digest, never stores its raw value.

The store adapter uses backend-only PostgreSQL connectivity to the private schema. It does not expose private functions through PostgREST or invent client RPC privileges. The typed adapter maps `Credential.value` to its digest before SQL. Returned secrets exist only long enough to send the response.

Adapter-only SQL envelopes are `StoreContinueInput = {itemId:string, kind:'code'|'link', credentialDigest:string, verifierHash:string}` and `StorePasswordInput = {capabilityDigest:string, verifierHash:string}`. Raw password, credential, verifier and capability are never SQL parameters. Password remains in memory for the supported Admin call. Public response possession checks precede password-policy disclosures.

Dependency contracts: `HookDeps = {store:GuardStore, webhookSecret:string, codeKey:CryptoKey, outboxKey:CryptoKey}`; `WorkerDeps = {store:GuardStore, outboxKey:CryptoKey, send:typeof sendFixedEmail, assertCommittedAccount:(lease:DeliveryLease)=>Promise<boolean>}`; `GuardDeps = {store:GuardStore, dispatch:typeof dispatchPassword, allowedOrigins:ReadonlySet<string>, mode:GuardMode}`. Fixed deadlines/keys/digest adapters are private configuration, not input flags. `FixedMail = {recipient:string, purpose:Purpose, url:string, code:string, expiresAt:string}`.

Harness contracts: `FixtureConfig` is the immutable manifest with exact addresses/ports, expected service labels/image digests and a generated fixture UUID; `FixtureIdentity` is independently observed Docker/SQL/Auth/capture identity plus confirmation/provider settings. `FixtureHandle` adds in-memory fake credentials and tracked fixture-owned resources to that validated identity. `CheckpointReport` is `{providerDigest:string, checkpoints:Record<'P1'|'P2'|'P3'|'P4'|'P5',{status:'PASS'|'FAIL'|'BLOCKED',observationIds:string[]}>}`. `ControlPlan` is `{action:'activate'|'rollback'|'restore',fixtureId:string,expectedGeneration:number,nextGeneration:number,steps:string[],ready:boolean}` and is revalidated before apply.

Evidence contracts: `CaseMapping = {sourceId:string,tier:1|2,assertionIds:string[],policyExceptionId:string|null}`. `SanitizedCaseEvidence` contains source/assertion IDs, candidate SHA, provider digest, fixture UUID, caller-role label, redacted request **shape only**, timing/concurrency numbers, expected/observed outcome enums, allowed/observed counters, before/after state digests, log-audit boolean and cleanup boolean. Never serialize raw HTTP, SQL rows, credential-derived digests or address inventories. Failed log audit/cleanup prevents PASS.

## Execution commands and gates

Use PowerShell from the worktree root unless stated otherwise. Each new test is run before its implementation and must fail for its missing behavior, not due to missing Docker/credentials. Setup failures are blockers, never passing assertions. Discover Supabase CLI subcommands with `--help` before using them. No `db reset`, `db push`, hosted audit script, deploy or generic Docker cleanup is authorized here.

`node scripts/auth-email-guard/run.mjs --suite <name>` is produced in Task 1. Names are `provider`, `state`, `delivery`, `grant`, `security`, `cutover`, `load`, `tier1`, `tier2`, `regression`. It preflights the local fixture, loads fake fixture credentials privately, dynamically imports suites only after validation, and cleans up its tracked accounts/rows. It exits nonzero on setup, assertion, sanitization or cleanup failure; reports only suite/case IDs and redacted state.

Tasks end with a scoped checkpoint commit when their tests pass. Stage only listed new files and reviewed guard-specific hunks with `git add -- <exact paths>` or `git add -p -- <existing files>`; inspect `git diff --cached` before `git commit`. Never use `git add .`, commit unrelated existing changes, or require a clean working tree by discarding work. Record candidate HEAD and dirty-scope manifest separately until a coherent candidate commit is possible.

### Task 1: Fail-closed isolated fixture and runner (M0)

**Files:** Create fixture/compose/run files and `fixture.test.mjs` from the map.

**Interfaces:** Produces `assertMortAuthFixture(config:FixtureConfig, observed:FixtureIdentity):void`, `startFixture():Promise<FixtureHandle>`, `stopFixture(handle):Promise<void>`. `FixtureHandle` supplies `authUrl`, `dbUrl`, `smtpUrl`, `captureUrl`, `guardUrl`, `mode`, image digests and a tracked cleanup list; credentials stay private.

- [ ] Write `rejectsWrongTargetBeforeImport`, `rejectsAutoconfirmAndRealSMTP`, `acceptsExactSyntheticFixture`, and `cleanupNeverTouchesOtherResources`. Assert hosted URLs, credentials inherited from general `.env`, other project labels, unexpected ports and auto-confirm all abort before any client creation or SQL.
- [ ] Run `node --test scripts/auth-email-guard/fixture.test.mjs`; expect behavior failures.
- [ ] Implement the exact manifest: Docker Compose project `mort-mobile`, dedicated services/resources prefixed `mort-mobile-auth-guard-qa-`, API `127.0.0.1:55421`, DB `127.0.0.1:55422`, capture UI/API `127.0.0.1:55424`, fake TLS SMTP `127.0.0.1:55425`, guard HTTP `127.0.0.1:55426`. Validate resource labels plus UUID-tagged disposable volume/database identity; do not accept only a hostname or Compose label. Leave normal 54321–54323 services and volumes alone. Pin existing provider images by digest, no working-stack upgrade; explicitly enable confirmation, disable phone/anonymous providers, set OTP expiry 600 and JWT 3600 in this fixture only. Provision schema/seed synthetic data, not a data dump of real accounts. Resource collision aborts.
- [ ] Implement dynamic suite import after preflight; require dedicated fake-credential input instead of reading the normal repository environment. SQL readbacks validate fixture UUID, provider version, configuration and capture ownership. Stage local TLS certificate/key only in an ignored restricted fixture directory, never Git.
- [ ] The Compose fixture includes Auth, DB, API gateway, PostgREST, Storage, Realtime, Deno guard handlers, local verified OAuth issuer and SMTP capture with pinned images and an isolated internal network. Only the manifest's loopback ports are published; provider/checker/worker internal addresses are fixed by the fixture. No service reads a normal-stack data volume. Start only these named services, never the whole Compose project or unrelated Docker containers.
- [ ] Rerun unit tests; start fixture only through the new validated runner and check healthy version/configuration without printing environment secrets. Checkpoint commit `test: isolate MORT email guard fixture`.

### Task 2: Prove provider compatibility before activation work (P1–P5)

**Files:** Create `provider.test.mjs`, `provider-probe.sql`; modify fixture wiring only.

**Interfaces:** Consumes `FixtureHandle`; produces `runProviderCheckpoints(handle):Promise<CheckpointReport>` where each P1–P5 is `PASS|FAIL|BLOCKED` with sanitized observation IDs and provider image digest. The SQL prototype is fixture-only and is removed after the run.

- [ ] Write paired negative/positive probes: pending signup plus direct PKCE/implicit/OTP confirmation must fail inside provider mutation; legitimate guarded Admin confirmation plus replacement password succeeds; old password never signs in. Probe an expired delayed Admin request against a newer operation, then prove the newer operation succeeds. Probe actual OAuth linking using a fixture-owned local issuer, including unconfirmed password identity cleanup and verified matching identity. Verify actual password-reset token cleanup and refresh-session revocation; measure existing JWT behavior through fixture PostgREST/Storage/Realtime without claiming instant revocation.
- [ ] Run `node scripts/auth-email-guard/run.mjs --suite provider` against the unguarded baseline; bypass-denial probes must fail while positive controls succeed.
- [ ] Install only a transaction-bound, disabled-by-default prototype grant check in the disposable fixture, invoke supported Admin APIs with an operation correlator, and observe actual old/new rows, lock timing and authentication method values. Never alter stored credentials directly. Demonstrate proof/confirmation/replacement password commit atomically and no intermediate password session can be minted.
- [ ] Add a signed-hook callback during uncommitted signup, then force provider rollback. Assert no FK deadlock, false verification, usable challenge or emitted account email; cleanup must finish. Record hook retry/timeout/idempotency behavior. Confirm Deno npm/SMTP adapter compatibility without contacting IONOS.
- [ ] Rerun the five checkpoint probes with positives. Any failure is an activation blocker; document the exact unsupported provider behavior and continue only independent disabled components. No fallback authentication design is authorized. Checkpoint commit `test: pin provider compatibility checkpoints`.

### Task 3: Private schema and deny-by-default privileges (M1)

**Files:** Create the migration using `pnpm exec supabase migration new mort_email_challenge_guard` after reading `migration new --help`; immediately record its actual path here. Create `security.test.mjs`; create `types.ts`/`store.ts` interface stubs as needed by tests.

**Interfaces:** Produces private schema `mort_auth_guard` tables `control`, `account_generations`, `families`, `items`, `capabilities`, `address_proofs`, `operation_grants`, `quota_events`, `hook_events`, `outbox`, `delivery_attempts`. `control.enabled` defaults false. `account_generations` keys account UUID and monotonic address/credential/fence/activation generations; it has no signup-time FK to uncommitted `auth.users`.

- [ ] Write `clientsCannotReadOrExecutePrivateGuard`, `migrationDefaultsDisabled`, `retiredGenerationsNeverResurrect` and deletion/retention assertions. Assert `anon`, authenticated A/B, expired sessions, user metadata injection and schema enumeration cannot access private rows/helpers. Include a legitimate service operation to prevent reject-everything passes.
- [ ] Run `node scripts/auth-email-guard/run.mjs --suite security`; expect missing-schema/assertion failures.
- [ ] Implement constraints for purpose/state/deadline/counter bounds, one active family/account/purpose, item uniqueness and capability/operation uniqueness. Enable RLS; revoke public/client schema, table and function grants including default execution. Use service-only helpers with fixed search paths and minimal function owners. Give `supabase_auth_admin` only the eventual token-hook execution/read authority needed, no blanket private-table mutation.
- [ ] Record grants, schema exposure and disabled trigger/control behavior. Retain dispatch quota digests across account deletion/recreation for at least the rolling hour. Delete secret ciphertext on delivery terminal/lease expiry; orphan challenges expire no later than 600 seconds, expired capabilities cannot retain authority, and terminal operation fences survive cleanup until all delayed-write generations are irrevocably rejected. Account deletion retires authority without exporting PII.
- [ ] Rerun privilege/constraint tests, migration encoding/parity checks. Checkpoint commit `feat: add disabled private email guard store` with the CLI-produced migration only.

### Task 4: Cryptography, strict parsing and safe responses (M2)

**Files:** Create `crypto.ts`, `parser.ts`, `redaction.ts`, matching tests and subsystem Deno config; reuse `_shared/secure_codes.ts` without weakening its existing behavior.

**Interfaces:** Produces `makeSecret():string`, `codeDigest(code:string,context:string,key:CryptoKey):Promise<string>`, `secretDigest(secret:string):Promise<string>`, `verifierDigest(verifier:string):Promise<string>`, `parseContinue(raw:Uint8Array):ContinueInput`, `parsePassword(raw:Uint8Array):PasswordInput`, `parseHook(raw:Uint8Array):BoundEvent`, `publicFailure():Failure`, `safeEvent(id:string,outcome:string):Record<string,string>`.

- [ ] Write rejection-sampling tests at 4,200,000,000 and below; assert 8 digits including leading zeros, 32-byte independent secrets, HMAC context binding, fixed-time digest comparison, strict 43-character base64url and 64-character verifier digest encodings. No weak entropy fallback.
- [ ] Add duplicate JSON-key, oversized body (>16 KiB), wrong type, duplicate/noncanonical UUID, mixed credential, email-plus-code, malformed UTF-8 and unsupported action tests. Parsing failures cause zero store writes; a canonical eligible UUID with a wrong recognized secret reaches the counter. Signed provider address is one exact mailbox; reject CR/LF, display names, multiple recipients and ambiguous/unsupported international forms rather than invent equivalence.
- [ ] Run `deno test --config supabase/functions/auth-email-guard.deno.json supabase/functions/_shared/auth_email_guard/`; expect missing-function failures.
- [ ] Implement Web Crypto/HMAC-SHA-256 and SHA-256 helpers; no Math.random/time UUIDs, modulo-biased digits, Gmail alias rewrite, raw value logging or plaintext credentials in rows. Parser uses an audited duplicate-key check and strict structural allowlists. Preserve provider-bound address bytes after validation; quota canonicalization must match inspected provider behavior conservatively and pass case/recreation tests.
- [ ] Rerun Deno units; secret-shaped synthetic fixtures must not appear in safe serialization. Checkpoint commit `feat: add strict cryptographic email guard inputs`.

### Task 5: Atomic families, shared failures, quotas and consume (M1/M4)

**Files:** Extend the new guard migration, `store.ts`; create `state.test.mjs`.

**Interfaces:** Implements `GuardStore.issue`, `claimDelivery`, `finishDelivery`, `consume`. SQL functions in `mort_auth_guard`: `issue_event(event jsonb, material jsonb) returns jsonb`, `claim_delivery() returns jsonb`, `finish_delivery(lease jsonb, outcome text) returns boolean`, `consume_item(input jsonb, material jsonb) returns jsonb`. Raw credentials are digested before SQL; capability secret is returned by the adapter only when its digest insert and family consumption commit.

- [ ] Write tests for five failures shared across code/link/current/grace; A-ID+B-secret debits A only; unknown/malformed IDs debit no family; fifth failure commits and concurrent success resolves once. A retired or terminal item cannot debit a newer family. Add failure-result-vs-exception rollback tests, consume/capability insertion rollback and response-loss replay denial.
- [ ] Write `graceStartsAtSMTPPromotion`, `atMostTwoEligibleItems`, `stalledAttemptCannotPromoteLate`, `resendNeverRenewsFamily`, `freshTerminalFamilyDoesNotCancelIssuedCapability`. Assert 600/60/60/300-second policies and timestamps; at `>= deadline` reject. Hold row locks across a deadline and prove post-lock time wins.
- [ ] Run `node scripts/auth-email-guard/run.mjs --suite state`; expect state/counter failures.
- [ ] Implement deterministic lock ordering (control/generations, account-purpose, family, item/capability, quota keys), authoritative post-lock time and terminal states. Return bad-credential results normally so failed-attempt increments commit. Family failure ceiling is never reset by issuance/resend. Atomically insert capability digest with immutable verifier hash and consume all family items.
- [ ] Implement rolling quotas under locked recipient/global keys: family admissions separate from actual dispatch reservations; every send/retry reserves immediately before transport, with no ambiguous refund. Replayed hook events do not issue another item or consume another family quota. Concurrent queue occupancy cannot exceed 20. Local test time uses fixture-row deadline setup and real locks, never a production clock parameter or public time override.
- [ ] Rerun state units and SQL integration with positive controls. Checkpoint commit `feat: enforce atomic email challenge lifecycle`.

### Task 6: Signed hook, encrypted queue and bounded SMTP worker (M3)

**Files:** Create hook/worker handlers, `outbox.ts`, `delivery.ts`, their Deno tests and `delivery.test.mjs`; extend store functions/migration.

**Interfaces:** Produces `handleEmailHook(request:Request,deps:HookDeps):Promise<Response>`, `runDeliveryBatch(deps:WorkerDeps):Promise<{claimed:number,acknowledged:number}>`, `encryptEnvelope(plaintext:Uint8Array,binding:string,key:CryptoKey):Promise<string>`, `decryptEnvelope(ciphertext:string,binding:string,key:CryptoKey):Promise<Uint8Array>`, `sendFixedEmail(message:FixedMail,lease:DeliveryLease):Promise<DeliveryOutcome>`. `FixedMail` is server-created recipient/purpose/HTTPS URL/code/deadline, never arbitrary template input.

- [ ] Write signature/freshness/body/idempotency tests using actual `user` and `email_data` hook payloads. Allow signup/recovery only; other email actions fail safely in enabled fixture mode. Assert wrong signature/replayed modified body/301-second-old/31-second-future input has no issuance. Duplicate same-event acceptance cannot create another envelope.
- [ ] Write delivery tests for acknowledgment, rejection, socket timeout, TLS/certificate failure, worker crash, queue saturation, second/third simultaneous workers, late ACK and provider-signup rollback. No queue ACK or ambiguous outcome promotes; maximum 2 concurrent deliveries; old delivered item stays valid after failed successor. All expired ciphertext is purged.
- [ ] Run Deno handler tests plus `node scripts/auth-email-guard/run.mjs --suite delivery`; expect failures.
- [ ] Verify Standard Webhooks over raw bytes before parsing. Use a 3-second hook admission budget; immediately enqueue authenticated AES-256-GCM ciphertext (fresh 12-byte nonce, item/account/purpose/recipient/generation as associated data) under a separate backend-only key. Persist digest-only challenge data, no built-in provider tokens. Return successful hook ACK only for committed admission; failures are generic, bounded and observable without secrets.
- [ ] Worker checks a **now-committed** matching account/address and guard generation before sending; no uncommitted lookup in the hook. Acquire a fenced 30-second attempt lease; reserve quotas before connecting. Use strict TLS and a fixture-only trust root; no ignore-certificate or insecure fallback. Set transport deadlines within remaining lease; destroy socket on timeout. Fixed `auth@mortapp.org` sender and HTTPS origin, single recipient, no code in subject/preheader, actual UTC family expiry. One transport dispatch per attempt; no library auto-retry. Retrying requires another reserved attempt and bounded owner flow. Server-authenticated worker invocation, leases and configuration are never exposed to the browser.
- [ ] Rerun delivery/signature units and real fixture SMTP tests, including hook completion within provider deadline. Checkpoint commit `feat: deliver guarded email through bounded encrypted outbox`.

### Task 7: Public Continue and verifier-bound password gateway (M4)

**Files:** Create guard handler/index, handler tests; extend `store.ts` reservation interface and integration state tests.

**Interfaces:** Produces `handleEmailGuard(request:Request,deps:GuardDeps):Promise<Response>`. Only `POST /continue` consumes `ContinueInput`; `POST /password` consumes `PasswordInput`. GET/peek/arbitrary-account/password operations have no authority. `GuardDeps` supplies the store, backend digest keys, operation dispatcher and fixed allowed origins; dependency injection is internal test code, never HTTP parameters.

- [ ] Write strict route/method/size/CORS tests; all canonical invalid/expired/exhausted/unknown credentials return the same failure/body/headers/status without target disclosure. No account lookup API exists. Assert ID alone, email+code and copied verifier/capability cannot change credentials or receive account data.
- [ ] Add capability just-before/at/after 300 seconds; invalid password does not consume or extend; invalid verifier never dispatches; valid possession reveals policy error only. Consumed/lost response never issues a second capability; a fresh terminal-family request under quotas succeeds without cancelling the old issued capability.
- [ ] Run guard Deno tests and the state integration suite; expect failures.
- [ ] Implement atomic Continue using Task 5; return server-derived masked address and both deadlines only on success. Require 12–128-character passwords with upper/lower/digit plus any stricter pinned provider requirement; read actual fixture policy and test exact boundary, do not weaken it. Validate verifier and policy before one-use capability reservation. Guard mode/config absence fails closed for enabled routes.
- [ ] Implement the amended 350 ms invalid-denial schedule and separate non-charged busy result, with 250 ms store budget, per-source 2/per-item 1/global 64 admission. Test timing distributions and source-B liveness under source-A flood. CORS/Origin are browser containment, never authorization. No query parameters or redirects carry secrets. Rerun paired controls; checkpoint commit `feat: add verifier-bound Continue and password gateway`.

### Task 8: Credential mutation, proof, token gating and delayed-write fence (M5)

**Files:** Extend migration and `store.ts`; create `provider.ts`, `grant.test.mjs` and Deno adapter tests; modify provider probe to use actual helpers.

**Interfaces:** Produces `dispatchPassword(operation:ReservedOperation,password:string):Promise<'committed'|'pending'|'fenced'>`; SQL `reserve_password(input jsonb) returns jsonb`, `guard_auth_user_mutation() returns trigger`, `custom_access_token_hook(event jsonb) returns jsonb`, `reconcile_operation(operation_id uuid) returns text`. Public metadata operation key is `mort_email_operation_id`; only a private grant can authorize it.

- [ ] Write direct provider bypass tests (verification GET/POST, PKCE exchange, implicit, OTP/magiclink/recovery/invite/email-change) with no MORT completion. Assert no confirmation/password change/refresh or new session where denied. Include ordinary confirmed password sign-in, OAuth, refresh and normal provider token-cleanup positives.
- [ ] Write account/address change-and-change-back, deletion/recreation, metadata spoofing, false OAuth verified claims, grant reuse, two competing Admin requests and unknown outcome tests. Hold provider lock until capability/grant expires: dispatched-before expiry still fails at write. Fence old request, complete new owner operation, release old request: old write fails and new password remains. A marker must neither authorize nor expose private state in minted claims.
- [ ] Run `node scripts/auth-email-guard/run.mjs --suite grant`; expect bypass/fencing failures.
- [ ] Implement the P1–P5-proven trigger predicate only, disabled by control. Lock account generations and grant, take post-lock time, require matching UUID/exact email/generation/purpose/lease, atomically replace proof and consume grant in the provider transaction. Supported Admin APIs change password and exact-address confirmation in one operation for confirmation; recovery changes password only. No raw credential SQL writes. Bound correlation metadata may be merged through Admin, never used as authorization alone.
- [ ] Token hook uses actual observed provider method labels and live private proof; blanket label guesses are prohibited. Reject email-code session methods and pending/incorrect proof; preserve existing authorized password/OAuth/refresh behavior. Verified OAuth provider-owned identity can establish matching address proof only after P4 passes, without preserving attacker-chosen pending password authority. Restrict execution to `supabase_auth_admin` and keep hook queries under its documented 2-second budget.
- [ ] Reconcile unknown Admin outcomes without reopening capabilities. Terminal fenced generations reject later writes even if an old request reintroduces its marker; protected cleanup cannot clear a newer operation. Account credential changes retire outstanding capabilities/tokens as proven by P5; record real existing-JWT limitations. Rerun grant and provider suites plus positives. If atomicity/fencing/liveness fails, keep activation blocked. Checkpoint commit `feat: enforce guarded provider writes and address proof`.

### Task 9: Local coherent cutover, baseline, rollback and restore (M9)

**Files:** Create control script/unit tests and `cutover.test.mjs`; extend migration control helpers.

**Interfaces:** Produces `planControl(action:'activate'|'rollback'|'restore',handle:FixtureHandle):Promise<ControlPlan>`, `applyLocalControl(plan:ControlPlan,handle:FixtureHandle):Promise<void>`. CLI defaults dry-run; apply requires `--local-fixture --apply` and successful identity preflight. No hosted target or Management API client exists in this script.

- [ ] Write partial activation, baseline/sign-up/confirmation race, rollback coherence and pre-restore capability/grant replay tests. Assert a fresh baseline includes only accounts already confirmed before the fenced cutover; historical counts 60/2 are never literal allowlists. Pending accounts need replacement passwords. Restore blocks redemption before trusted generation changes.
- [ ] Run `node --test scripts/auth-email-guard/control.test.mjs` and cutover suite; expect failures.
- [ ] Implement one fixture-controlled activation boundary: gate ingress, lock provider mutation boundary, snapshot current confirmed address generations/proofs, enable delivery/private checker/mutation guard/token hook/browser mode coherently, release ingress after verification. No partial success. Reconstruct proof from account/provider authority, never a string allowlist or client metadata.
- [ ] Use a monotonic generation journal outside the disposable DB volume, restricted to the fixture runner; rollback/restore cannot accept a DB snapshot's own generation as fresh authority. Fence before restoring, rotate generation and retire old families/capabilities/grants before reopening. Rollback returns the coherent previous provider flow and accurately records its weaker five-attempt assurance; never reopen consumed guard authority. Print only control names, counts and boolean readiness.
- [ ] Rerun baseline/restore races and post-rollback legitimate sign-in, then re-enable fixture for later tests. Checkpoint commit `test: rehearse coherent local auth guard transitions`.

### Task 10: Standalone Continue/password pages and site generation (M6)

**Files:** Create browser controller/transport, confirmation route and tests; modify existing recovery page/tests and `build-auth-pages.mjs` only for these routes/config/headers.

**Interfaces:** Produces `createChallengeController({transport,crypto,now,onState}):ChallengeController` with `load(fragment:string):void`, `continue():Promise<void>`, `submitPassword(password:string,confirmation:string):Promise<void>`, `dispose():void`; `ChallengeTransport` has `continue(input:ContinueInput):Promise<ContinueResult>`, `password(input:PasswordInput):Promise<PasswordResult>`. State: `neutral|continuing|password|submitting|success|failure`. Builder accepts guard mode/endpoint explicitly; production defaults remain disabled.

- [ ] Write tests: scanner/page load makes zero transport calls, clears fragment into memory immediately; UUID alone shows neutral text not verified/recipient; Continue success shows server-masked target/deadlines; failure is red with text/icon, success green with text/icon and live-region announcement. Confirmation copy explains replacement of the signup password. No JavaScript produces safe explanatory text rather than fake success.
- [ ] Add lost-response, refresh, back-forward, double-click Continue and stale asynchronous completion tests. No storage/rebind/fallback/new-capability replay; button concurrency and generation fencing preserve state. Corrupted payloads/query secrets/duplicate fragment fields fail neutral/generic; no provider credentials accepted in enabled mode.
- [ ] Run `node --test web/auth/challenge/*.test.mjs web/auth/recovery/recovery.test.mjs`; expect new-state failures while existing disabled-mode tests remain green.
- [ ] Implement verifier using browser Web Crypto and memory only, hash sent at Continue, raw verifier only in password POST. Clear password fields after send and all credentials on success/dispose/terminal failure. API response is not HTML; use `textContent`, fixed strings and validated server dates. Form success only after confirmed operation commit; pending outcome directs a fresh flow without false success or secret-bearing retries.
- [ ] Add `/auth/confirmation/` and guarded recovery to generator. Keep black/gray surfaces, white/silver secondary styling and accessible green/red statuses. Apply no-store, no-referrer, restrictive CSP, `frame-ancestors 'none'`, no analytics/third-party scripts or secret query strings. Preserve separately approved CAPTCHA iframe headers. Build test output to a temporary directory; local fixture permits only its explicit loopback config, without relaxing production Supabase-host/public-key validation. Audit mortapp.org same-origin scripts/service-worker scope and record unresolved hosted origin risks.
- [ ] Rerun page-state/builder/accessibility/browser transport tests, including actual browser reload and network capture in a disposable browser profile (no Android emulator). Checkpoint commit `feat: add guarded email confirmation and recovery pages`.

### Task 11: Preserve Flutter auth/link compatibility (M7)

**Files:** Inspect then modify only if required `flutter_mort/lib/data/repositories/auth_repository.dart`, `flutter_mort/lib/features/auth/email_verification_screen.dart`, `flutter_mort/lib/features/auth/unified_auth_screen.dart`; tests `friends_auth_navigation_test.dart`, `unified_auth_screen_test.dart`, new `email_guard_compatibility_test.dart`. Inspect `app_config.dart`/`app_router.dart` before touching them.

**Interfaces:** Preserve existing auth repository public signatures and normal password/OAuth sign-in. HTTPS confirmation/recovery is a browser-owned guarded flow; native return opens normal sign-in, never accepts a cap or fakes a recovered session.

- [ ] Write contracts proving existing password/OAuth/auth-back navigation and original disabled-mode deep links work, pending-account copy explains replacement-password confirmation when enabled, and failed browser recovery cannot set native authenticated state. No new guest or teen/adult role inference from email-domain shortcuts.
- [ ] Run `flutter test test/email_guard_compatibility_test.dart test/friends_auth_navigation_test.dart test/unified_auth_screen_test.dart` from `flutter_mort`; expect only new-contract failures.
- [ ] Implement the smallest required copy/link handling changes; do not change paywall, theme, auth architecture, version, eligibility or entitlements. If all existing behavior already satisfies tests, record no production client change.
- [ ] Rerun focused Flutter tests plus `node scripts/qa-release-deep-links.mjs` from root; record Android/iOS manifest parity by inspection/tests, not a device claim. Checkpoint reviewed guard-only hunks with `fix: preserve guarded email auth navigation` if code changed.

### Task 12: Trace all requirements and run bounded adversarial cases (M8/M9)

**Files:** Create `cases.mjs`, `coverage.mjs`, `coverage.test.mjs`, `evidence.mjs`, `load.test.mjs`; extend the named state/provider/security/delivery/cutover suites.

**Interfaces:** Produces `validateCoverage(sourceIds:string[],mapping:CaseMapping[]):void`, `runCase(id:string,fixture:FixtureHandle):Promise<SanitizedCaseEvidence>`, `serializeEvidence(record:SanitizedCaseEvidence):string`. Every case records caller role, redacted shape, exact fixture/candidate, concurrency/timing, expected/observed result, permitted counter changes, state digest, log audit and cleanup. Raw sensitive state is never serialized.

- [ ] Write mapping tests for all 191 consecutive unique MD2 IDs and retained MD/DOCX/OB/AD/RR/FS entries (519 overlapping entries), no inherited PASS, no empty/unowned runnable assertion, no missing core ID. Keep static triage separate. Approved D2/D5 exceptions link original assertions to revised assertions; never relabel contradictory old assertions passing.
- [ ] Run `node --test scripts/auth-email-guard/coverage.test.mjs`; expect missing mappings.
- [ ] Map T1/T2/T6 to state/parser/guard; T3/T4/T7 to delivery/provider; T5/T10 to provider/grant/security; T8 to browser; T9 to quota/load; T11/T13 to cutover/grant; T12 to fixture/evidence; T14 to browser/provider/load. Keep core assertions Tier 1 and optional breadth Tier 2. MD-115–120 map explicitly to privilege/config/cutover/rollback/logging/restore tests. Continue-only means no peek route: optional peek semantics are owner-scoped out with route-absence proof, not fabricated successful peek tests.
- [ ] Run Tier 1 first. Pair each denial class with a legitimate success control. Fuzz only fixture ingress: maximum 20 concurrent requests, 500 requests per load invocation, 60-second wall deadline, DB test pool max 8; abort on any unauthorized mutation/session, secret exposure, cleanup failure, unexpected non-fixture connection or resource-bound violation. Quota-controlled denial is expected under load but cannot substitute for legitimate post-load recovery. Rotate only synthetic trusted-ingress contexts, never public proxies or spoofed untrusted forwarded headers.
- [ ] Run core deadline/lock races and then bounded Tier 2 breadth. Real time determines assertions; setup may move disposable row deadlines, never expose a production clock override. Rehearse backup/restore and cleanup; maintain closed handles and queue accounting. Independently verify output/logs contain none of the generated fixture secrets (report leak booleans only).
- [ ] Rerun coverage and affected suites; store sanitized artifacts through the managed security tool with candidate SHA and no runtime status on unexecuted cases. Checkpoint commit `test: certify guarded email requirement coverage`.

### Task 13: Relevant regression, secret scan and exact candidate (M10)

**Files:** Modify runner regression dispatch and operations doc; review all changed paths/lockfiles/migration plus pre-existing dirty-scope manifest.

**Interfaces:** Produces an exact-candidate command/result manifest. No build artifact, deployment or hosted configuration change is produced.

- [ ] Run `deno fmt --check` on the new function directories/config and `deno check --config supabase/functions/auth-email-guard.deno.json` on the three function entrypoints. Run subsystem Deno units and existing `_shared/secure_codes_test.ts`; dependency downloads use pinned lock inputs only.
- [ ] Run `pnpm check`, applicable repository lint, Node browser/fixture/coverage tests, and site generation/validation against temporary output. Run `flutter analyze` and the **full** `flutter test` suite from `flutter_mort`; record exact counts/skips, do not copy historical 798/815 results.
- [ ] Run existing backend/RLS/onboarding/account-deletion/secure-invite suites through the preflight runner against the disposable fixture, never generic environment defaults. Preserve onboarding/school/guardian/social/payment/entitlement semantics. Inspect every selected script's environment/target behavior before dynamic import; refuse any hosted-only script rather than pointing it at production.
- [ ] Run `powershell -NoProfile -File scripts/secret-scan.ps1`, migration encoding/parity checks and `git diff --check`; scan guard browser/function output as well as source. Review grants, config-default-off, template injection, origin isolation and native parity. Fix concrete failures then rerun affected/full required gates.
- [ ] Inspect scoped staged changes, commit coherent guard candidate and record exact HEAD. Rerun Tier 1, P1–P5, secret/diff checks and relevant regression against that exact HEAD; any subsequent source change invalidates affected candidate evidence. Preserve unrelated working changes explicitly, without describing them as verified guard source.

### Task 14: Single-agent review and disabled hosted activation package (M11/M12)

**Files:** Update operations document with factual readiness; save case/result/review artifacts through managed Codex Security storage, not source-control secret files.

**Interfaces:** Produces `CODE_VERIFIED|INCOMPLETE` and `LOCAL_GUARD_VERIFIED|BLOCKED` separately from `HOSTED_ACTIVATION_NOT_PERFORMED`, `STORE_TESTING_PENDING`, `PRODUCTION_ROLLOUT_NOT_PERFORMED`.

- [ ] Review the same exact candidate and evidence sequentially: Believer (spec positive controls), Skeptic (bypass/races), Investor/operations (mail quota/availability/rollback), Judge (only evidence-backed conclusions). No agent delegation. A failed provider/security assertion cannot be overruled by a successful build or static opinion.
- [ ] Record every unresolved finding, external blocker and excluded optional assertion. All Tier 1/P1–P5/local delivery gates must actually pass before local guard certification. Missing tools, cleanup or observations mean BLOCKED/NOT_RUN, never PASS.
- [ ] Prepare the concrete later hosted cutover proposal with exact hooks, disabled control defaults, origin/header configuration, secret locations without values, coherent activation/rollback steps and current generation/baseline procedure. Account-specific IONOS capacity, SMTP credentials, received-message SPF/DKIM/DMARC alignment, origin/service-worker audit and staging approval remain external gates.
- [ ] Stop before hosted changes. Ask for later hosted activation approval only after its reviewable gates/package exist. Do not ask for release/merge approval as a substitute and do not change preserved artifacts.

## Plan self-review and handoff

Specification coverage: sections 0–3/9/13A → global constraints and Tasks 1/4–7; section 4 → Tasks 3/6–10; sections 5–8 → Tasks 2/4–8; section 10 → Task 9; section 11 → Tasks 1/12; section 12 → Tasks 2/13/14; section 13 → Tasks 7/10/14. Each review-focus case is assigned above. Signatures/types are shared in one contract map; private authority stays behind store transactions, not client RPC.

**Current evidence:** specification/plan execution approved; partial fixture/provider/private-state/crypto/hook/SMTP checkpoints are recorded above and in managed security storage. The full guard, remaining provider/transport variants, source-matrix certification and hosted activation are not completed. Checkpoint commits are not certified release candidates.

**Execution:** owner approved this plan with the supplied review; the amendment above resolves its execution prerequisites. Use `superpowers:executing-plans`, single agent. No additional specification or implementation-plan approval is needed. Hosted activation is a later, separate gate.

### References inspected for this plan

- [Supabase Auth hooks](https://supabase.com/docs/guides/auth/auth-hooks): documented HTTP/Postgres hook deadlines and permissions. The async outbox is a design inference from those deadlines, subject to real pinned-provider tests.
- [Send Email hook](https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook): signed provider payload and hook replacement of SMTP; do not forward built-in tokens into the guarded flow.
- [Pinned GoTrue source](https://github.com/supabase/auth/tree/v2.197.0): compatibility must be demonstrated in the matching fixture, not inferred from current documentation alone.
- [Supabase changelog](https://supabase.com/changelog.md): inspected 2026-10-08; record exact DB minor/image in execution and inspect applicable pgcrypto changes before migration tests. No working-stack upgrade is part of this plan.
