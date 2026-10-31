# Codex Execution Brief — MORT Production Readiness

Read `docs/architecture/MORT-PRODUCTION-REFERENCE-ARCHITECTURE.md` completely before changing code.

## Mission

Bring MORT toward a safe production release by implementing and verifying the architecture in small, reviewable steps. Do not optimize for a percentage. Optimize for passing evidence-backed release gates.

## Source-of-truth environments

- Production Supabase project ref: `jxbnrkasktbhtiujkhay`.
- Production website: `https://mortapp.org`.
- Production web repo: `mortapp/mort-web`, project `mort-web`, branch `main`.
- Production mobile source: `mortapp/Mort/flutter_mort`.
- Deleted project `rakjydmgwwgtdislanbt`: NEVER use, contact, configure, or treat as a fallback.
- Stripe account for sandbox inspection/testing only: `Mort sandbox`, account context `acct_1TvorjJmJ5J7gUVQ`, `livemode:false`.

## Required workflow

1. Start with read-only inventory. Confirm repository, branch, commit, Supabase project ref, deployed functions, tables, policies, grants, triggers, secrets *names only*, Vercel environment variable names only, and Stripe sandbox endpoint configuration.
2. Identify stale documentation and correct references to the deleted Supabase project. Do not change runtime configuration as part of documentation cleanup.
3. Build a code-to-contract matrix for every active client call, RPC, Edge Function, table, storage bucket, and policy.
4. Prioritize the three known critical contracts: Guardian application approval; private job-location lifecycle; server-side job-distance calculation.
5. For each contract, write tests first, implement in a feature branch, and prepare a minimal additive migration. Never run an unreviewed migration on production.
6. Run unit, integration, RLS, concurrency, idempotency, and cross-role tests in an isolated disposable environment. If no isolated environment is available, stop before schema mutation and report the exact blocker.
7. Review all safety, moderation, reporting, blocking, messaging, verification, privacy, and account lifecycle flows.
8. Implement/verify backups, monitoring, notification delivery, incident runbooks, and a real restore drill.
9. Treat Stripe as a separate gated phase. Test sandbox only. Verify all RPC/table dependencies for the existing `stripe-webhook` handler, deploy the matching handler only after approval, and configure endpoint-specific signing secrets through an approved secure secrets interface. Do not print or commit secrets.
10. Generate a release-gate report with PASS / FAIL / BLOCKED, exact evidence, commit SHA, environment, and owner.

## Hard safety constraints

- No Stripe live mode, no live connected account, no live secret access.
- Do not modify the two existing sandbox webhook endpoints until their destination handler is deployed, the correct endpoint-specific signing secret is securely configured, and event-level integration tests pass.
- Do not enable marketplace publishing, public job discovery, payments, Connect onboarding, transfers, payouts, or real identity-document collection.
- Keep every existing production kill switch disabled.
- Do not create fake production accounts, jobs, assignments, payments, or verification records.
- Do not bypass RLS, loosen grants, disable policies, or rely on client-side role checks.
- Do not replay the full local migration chain or assume local migrations match production.
- Do not deploy directly to production from an unreviewed working tree.
- Do not report a feature complete without evidence from the correct environment.
- If a credential, legal decision, isolated environment, or human approval is missing, stop that workstream and mark it BLOCKED. Continue with independent safe work.

## Required final report

Include:
- current commit and working-tree status;
- exact files changed;
- migrations proposed/applied and target environment;
- tests run and results;
- RLS/access matrix results;
- deployed function inventory;
- backup artifact and restore evidence;
- OAuth and mobile/web release evidence;
- Stripe sandbox event coverage and endpoint state;
- secrets configured by name only, never values;
- remaining blockers and risk owner;
- release gate decision: GO / NO-GO.

Do not claim 100% unless every required release gate in the architecture has evidence and explicit sign-off.
