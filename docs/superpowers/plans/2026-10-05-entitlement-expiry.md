# Entitlement expiry implementation plan

> Execute sequentially in the existing integration worktree. AGENTS.md requires one agent.

**Goal:** Expire server-side benefits on time even if a provider expiration webhook is delayed.

**Architecture:** A caller-scoped SQL reader derives entitlements from individually unexpired provider product states. Only accounts without product-state history may use the existing cache fallback, respecting its expiry. Existing entitlement, ad eligibility, and username RPCs consume that reader.

**Tech stack:** PostgreSQL, additive Supabase migrations, transaction-rolled-back Node QA.

**Spec:** AGENTS.md, docs/blueprints/MORT_MASTER_EXECUTION_BLUEPRINT.md, owner Free < Plus < Pro and no local grant requirements.

## Constraints and review focus

- Preserve signed build 115 and uploaded build 114; no hosted migration, upload, merge, or production rollout.
- No paid tier may unlock core marketplace or safety functionality.
- Preserve active historical customers and lifetime grants; do not infer expired Pro from a longer-lived Plus/add-on.
- Resolve only auth.uid(), including for administrator callers; no arbitrary account parameter.
- Cancellation/billing issues retain access through the provider-confirmed paid period.
- Anonymous callers get no entitlement reader permission; stale cached flags never override product states.

## Task: expiry-aware server benefits

Files: create scripts/qa-revenuecat-entitlement-expiry.mjs and supabase/migrations/20261005120000_revenuecat_entitlement_reads_respect_expiry.sql; update completion evidence.

- [x] Write rolled-back local QA covering expired product without expiration webhook, mixed Plus/Pro, lifetime, active Pro username allowance, legacy cache fallback, and self-only reads.
- [x] Run QA and capture the expected stale-entitlement failure before implementation.
- [x] Implement public.get_my_active_revenuecat_entitlements() returning text[], scoped to auth.uid(), with hardened search_path and restricted execution grants.
- [x] Reuse it in get_my_entitlements(), get_ad_eligibility(), get_username_change_status(), and request_username_change(); retain existing RPC signatures and non-subscription behavior.
- [x] Apply migration locally only and run expiry/lifecycle, entitlement forgery, username, ad, and RLS regressions.
- [x] Inspect diff, scan secrets/encoding, run the sequential repository audit, and record exact evidence and remaining external gates.

## Follow-up: MORT Verify defects discovered by lint/runtime QA

- [x] Reproduce sandbox session startup using scripts/qa-mort-verify-hash-resolution.mjs, without sending email/documents or retaining control changes.
- [x] Restore explicit first-party decision-source compatibility with an additive constraint migration; keep pending incapable of verification and retain the independent production source gate.
- [x] Reproduce the unresolved digest call, then qualify extensions.digest in the session and retired verifier bodies using an additive migration; preserve hardened search paths and revoked verifier execution.
- [x] Rerun runtime QA, teen verification contracts, identity isolation, and public-schema lint. Add local-only runtime regression to the CI runner.
