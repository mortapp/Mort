# MORT RLS and Storage Test Report

Run date: 2026-07-22

## Passed Evidence

- Final Supabase regression: 26/26 scripts.
- Complete multi-user isolation: 30/30 checks.
- Avatar Storage: owner upload/display/replace/remove passed; unrelated overwrite/list/download failed as required.
- Eight audited Storage buckets are private.
- Support thread, message, assignment, and evidence isolation passed.
- Ordinary admin payment-operations access was denied without an expiring financial role.
- Role, verification, entitlement, quota, moderation, test-account, and server-owned field forgery attempts were rejected.
- Jobs, applications, saved jobs, addresses, exact locations, guardian links, notifications, evidence, reports, and payment allegations remained participant/recipient isolated.

The tests use direct Supabase clients and RPC/Storage calls, not only Flutter route guards. QA users created by each run were removed by that run. Real identity evidence remains disabled and was not collected.
