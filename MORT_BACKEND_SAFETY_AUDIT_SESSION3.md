# MORT Backend/Safety Audit — Session 3 (Auth/session, brief)

A shorter, targeted pass on auth/account/session architecture, done while other
regressions ran in the background.

## Account-state routing (client)

`flutter_mort/lib/core/auth/auth_startup.dart:179` (`routeAuthenticatedProfile`):
- Profile `id` mismatch against the authenticated `userId` → routed to an `offline`/
  error state rather than proceeding with an unverifiable profile (fail-closed).
- `account_status` containing `"deletion"` → routed to a dedicated deletion-pending
  screen.
- Any other non-`"active"` status (banned/suspended/blocked) → routed to a suspended/
  account-status screen, not the main app shell.
- Unknown/missing role or incomplete onboarding → forced into onboarding rather than
  guessing a destination; the `switch` on role has a safe `_ => '/account-status'`
  default rather than an unchecked cast.

This is client-side UX routing; the actual security boundary is backend RLS via
`is_profile_active()` (checks `account_status = 'active'` and `blocked_until`),
audited in Session 1/2 — so even a client routing bug would not itself grant a
suspended user backend access. No defect found.

## Item that cannot be verified from this repository

`supabase/config.toml` (the **local development** Supabase CLI config, not
necessarily synced to the hosted project) has `[auth.email] enable_confirmations =
false`. This file only governs `supabase start` (local stack); the hosted
project's actual email-confirmation requirement is configured in the Supabase
Dashboard (Authentication → Providers → Email) and is **not stored in this
repository**, and this session's Supabase MCP connection is bound to an unrelated
project ("Loop"), so it could not be checked either.

**This is neither confirmed broken nor confirmed fine — it needs a human with
dashboard access to the `rakjydmgwwgtdislanbt` project to check.** Flagged in
`MORT_EXTERNAL_RELEASE_GATES.md`.

Similarly, production Auth rate-limiting (login attempt throttling) is Supabase-
managed dashboard configuration, not something expressed in migrations or
`config.toml` — could not be verified from source for the same reason.

## Running tally addition

AUTH_ARCHITECTURE: client-side account-state routing sound; two items (email
confirmation requirement, Auth rate-limit config) require live dashboard
verification, not code changes — added to the external gates ledger as
verification items rather than scored as pass/fail.
