# MORT Security Report 0.9.5

The filename is retained from the sprint requirement. Code-controlled security
is **not 100%**. Current score: `26/33 = 78%`.

## Passed in this sprint

- No service-role, database, Supabase access, RevenueCat V2, push-invoke, or
  signing secret was passed to Flutter or found in delivery scans.
- Source scan: 1,502 files, 30 known app media, 10 available secret values.
- Android extraction scan: 2,596 APK/AAB entries against 5 available sensitive
  values.
- Git history: 9 commits and 4 configured secret values, zero findings.
- Production dependency audit: no known vulnerabilities after pinning PostCSS
  8.5.18 for the source-map traversal advisory.
- Supabase remote schema lint previously returned no results.
- Remote RLS/isolation regression passed; the complete user-isolation matrix was
  30/30 and the 0.9.5 focused regression passed all seven added/final scripts.
- AI safety now has bounded input, deterministic fallback, server quota,
  idempotency, safe logs, and no raw-content logging.
- RevenueCat fulfillment is atomic under concurrency, rejects changed-payload
  event replay, protects server-owned state, and handles stale provider events.
- Signed media functions have request-size limits, safe codes, correlation IDs,
  and structured safe logging.
- Google callback policy requires exact native/web routes and rejects bearer
  tokens in callback URLs.
- The rebuilt APK has cleartext blocked, selected sensitive screens protected,
  release signing enforced, min/target SDK 24/36, and 10 reviewed permissions.

## Open warnings and external gates

The refreshed Supabase advisor snapshot has zero error-level findings, but it is
not a clean-warning result:

- 277 security findings: 47 info and 230 warn.
- 47 RLS-enabled tables without policies; these are intentional no-access tables
  only where separately verified, but all must remain inventoried.
- 2 anonymous fixed-output `SECURITY DEFINER` status functions.
- 227 authenticated executable `SECURITY DEFINER` functions. The tested critical
  paths enforce identity/role/resource checks, but no claim is made that all 227
  received independent line-by-line audit in this sprint.
- 173 performance findings: 97 unindexed foreign keys, 75 unused indexes, and one
  multiple-permissive-policy warning.
- 11 retained synthetic QA users have 18 sessions/refresh tokens, one admin
  safety role, one partner role, 13 proof rows, and one owned Storage object.
  Owner classification and controlled cleanup are required before real users.

## Plan-limited password protection

`DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT`.

Supabase leaked-password protection requires Pro for this project. This is not a
code security defect. Current mitigations are a 12-character minimum, required
lower/upper/digit/symbol checks in the app, server lower/upper/digit enforcement,
email verification, rate limiting, RLS, account restriction logic, secure reset,
and session revocation paths.

Future task: **When Supabase is upgraded to Pro, enable leaked-password
protection immediately and rerun Auth security advisors.** Do not spend money or
upgrade the plan as part of this release.

No independent penetration test, physical-device mobile audit, staffed incident
exercise, restore drill, or qualified privacy/teen-safety review was completed.
