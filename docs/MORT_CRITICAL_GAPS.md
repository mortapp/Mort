# MORT Critical Gaps

Audit date: 2026-07-22

No known unresolved Critical or High source-code vulnerability was found in this pass. That does not make the system production ready.

## Release Blockers

1. Stripe live account, capabilities, live keys, webhook, Connect, and end-to-end provider actions are not verified.
2. Qualified legal, tax/payment, privacy, labor, and minor-safety review has not approved the drafts or operating model.
3. iOS has no Xcode compile, signing, archive, real-device, TestFlight, push, deep-link, camera, avatar, job, PIN, support, or Stripe evidence.
4. Production monitoring, alert ownership, spend alerts, on-call staffing, incident exercise, backup restore exercise, and emergency escalation contacts are not verified.
5. Identity verification provider integration and real ID collection remain disabled. Public marketplace access must stay closed.
6. OpenAI external generation and provider-side budgets are not configured; deterministic support remains the active mode.
7. Supabase advisors report warning-level SECURITY DEFINER exposure by design and performance debt. Each public RPC still requires ongoing least-privilege review.
8. Supabase leaked-password protection is `DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT`, not an unresolved code bug.

Before real users, complete every item in `MORT_EXTERNAL_ACTION_TRACKER.md` and repeat security, device, provider, restore, and operational testing.
