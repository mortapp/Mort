# Deployed Supabase Audit

Project: `rakjydmgwwgtdislanbt`

Audit date: 2026-07-22

- Local and remote migrations match through `20260722225742_fix_adult_job_cancellation_enum_cast.sql`.
- The 0.9.3 support, evidence, PIN, payment resolution, abandonment, refund reconciliation, support queue, avatar, AI/rate-limit, payment-operations, and cancellation-lint migrations are deployed.
- `ai-support`, `avatar-url`, and `support-evidence-url` were deployed during this pass. Other Stripe/send-push functions were already present and were not represented as newly deployed.
- Remote regression: PASS, 26 scripts.
- Multi-user RLS/Storage isolation: PASS, 30/30 checks.
- Schema lint at error level: PASS after fixing `request_adult_job_cancellation` enum assignment.
- Security Advisor: 264 non-error findings, comprising 45 info-level RLS-with-no-policy deny-by-default notices and 219 warnings. Warnings include one intentional anonymous release-mode RPC, 217 authenticated SECURITY DEFINER RPC exposure notices, and one Free-plan leaked-password notice.
- Performance Advisor: 170 non-error findings: 95 unindexed foreign keys, 74 unused-index notices, and one multiple-permissive-policy warning.

The blanket SECURITY DEFINER notices are not automatically vulnerabilities: MORT intentionally exposes caller-bound RPCs, revokes `PUBLIC`/`anon` where appropriate, uses explicit grants, empty search paths, server-owned checks, and direct adversarial tests. They remain an ongoing least-privilege review surface. Performance findings remain technical debt and prevent a perfect backend score.

Leaked-password protection is `DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT`. When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.
