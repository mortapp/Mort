# Supabase Advisor Review 0.9.2

Linked project: `rakjydmgwwgtdislanbt`.

`supabase db lint --linked --level warning --fail-on error` returned no errors. Warnings are unused parameters in disabled identity-verification stubs; preserving those signatures keeps the provider contract fail closed.

Security advisor returned warning-level findings for intentionally callable `SECURITY DEFINER` API RPCs. These RPCs use fixed search paths and internal identity/role/row checks; automated forgery, role, RLS, storage, and multi-user tests pass. The advisor cannot infer those body checks, so the warning is accepted only with continued per-RPC review and regression. The anonymous `get_release_mode_status` endpoint returns public release state only.

Performance advisor returned one warning: `account_deletion_requests` has separate permissive self/admin SELECT policies. This is functionally correct but can be consolidated in a future performance migration after query-plan measurement.

## Leaked-password protection

**DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT**

Supabase Dashboard reports HaveIBeenPwned leaked-password protection requires Pro or above. This is not an unresolved code security bug, and no paid upgrade was made. Current mitigations are strong minimum length, required complexity, auth rate limiting, email verification, RLS, account restriction logic, and secure password reset.

Future task: “When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.”
