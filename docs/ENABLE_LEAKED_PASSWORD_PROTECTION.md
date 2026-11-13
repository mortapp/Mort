# Leaked-Password Protection

## Current production status

**CUSTOM MORT CHECKER DEPLOYED — SUPABASE AUTH CONTROL DISABLED**

Authoritative production project: `jxbnrkasktbhtiujkhay`.

On 2026-11-13, the live Supabase Security Advisor reported `auth_leaked_password_protection` as **WARN — Leaked Password Protection Disabled**. This is the separate Supabase Auth HaveIBeenPwned control; it is not the same as MORT's custom checker.

The production project has an active `leaked-password-check` Edge Function (version 2, `verify_jwt=false`). Its deployed implementation manually validates the caller's user JWT with Supabase Auth, accepts a password over HTTPS from the authenticated client, hashes it server-side, sends only the first five SHA-1 digest characters to HaveIBeenPwned, and returns a boolean breach result. The Flutter client currently uses that deployed request/response contract.

The deployed version does not handle `OPTIONS` preflight or add explicit CORS response headers. Because the Flutter Web client invokes the function with authorization and JSON headers, browser preflight is expected to fail; the app's fail-open behavior can then allow a password without a completed lookup. Treat the Flutter Web path as unverified until browser QA and deployment of the CORS-capable source. Native Android/iOS calls are not subject to browser CORS. The Next.js website uses its own server-side HIBP checker.

The GitHub source had drifted to a different prefix/suffix API contract from the deployed function. PR #91 aligns the source with the deployed contract and adds request limits, a best-effort per-isolate rate limit, a four-second HIBP timeout, response validation, CORS preflight handling, and tests. These additional source controls are **not active in production until the PR is verified, merged, and the Edge Function is deployed**.

An older version of this document referred to project `rakjydmgwwgtdislanbt`. That project is deleted and is not the production target. The old project's July 2026 Free-plan limitation does not establish the current plan or feature eligibility of `jxbnrkasktbhtiujkhay`.

Do not change the Supabase plan, spend money, or change production Auth settings without separate authorization.

## Custom MORT checker data flow

1. The authenticated client sends the password to MORT's Edge Function over HTTPS.
2. The Edge Function validates the user JWT and hashes the password in memory.
3. Only the first five hexadecimal characters of the SHA-1 digest are sent to HaveIBeenPwned using its range API.
4. The Edge Function compares the returned suffixes in memory and returns only `leaked` (or `check_unavailable`).
5. The plaintext password, full digest, HIBP prefix, and HIBP response rows must never be logged or persisted.

The current availability policy is fail-open: if the HIBP service or MORT check endpoint is unavailable, signup/password recovery is not blocked. This avoids provider outages locking users out, but means an outage can temporarily bypass the custom breach check. Keep this trade-off explicit and cover it with tests.

## Enforcement boundary and direct-API bypass

The custom HIBP checker is an application-level preflight, not an Auth-server password policy. The Flutter and Next.js clients call it before sending a password to Supabase Auth, but Supabase Auth's public signup endpoint and authenticated password-update endpoint can still be called directly by a modified client. A caller can therefore skip the app-level preflight.

Because the separate Supabase Auth leaked-password control is currently reported disabled, MORT must not claim that every account password is server-enforced against breach corpora. Treat the custom checker as defense-in-depth until the native Auth control is enabled or every password-creation/change path is routed through a trusted server boundary and direct Auth paths are appropriately restricted. Do not attempt to solve this by hiding the public anon/publishable key; it is intentionally public.

A safe production decision requires checking the current Supabase plan and feature eligibility. If native Auth enforcement is unavailable, design and test a server-mediated signup/password-change flow with email verification, abuse controls, and no alternate direct paths before disabling public signup. Do not change these production settings as part of this source-only PR.

## Separate controls — do not conflate them

- **MORT custom HIBP checker:** an application-level Edge Function used by the Flutter signup and password-recovery flows.
- **Supabase Auth leaked-password protection:** an independent server-side Auth control; currently reported disabled by the production advisor.
- **GitHub secret scanning and push protection:** controls for credentials accidentally committed to source/history. They do not check whether an end-user password appears in a breach corpus.

## Verification checklist

Before deploying the source changes from PR #91:

1. Confirm Flutter tests cover breached, clean, unavailable, and malformed response handling.
2. Confirm Deno tests cover the SHA-1 known vector, positive HIBP matches, zero-count padding rows, and malformed provider output.
3. Confirm Edge Function type-check passes.
4. In a controlled QA environment, test a known breached fixture and a known clean fixture. Never use a real user's password.
5. Test timeout, non-2xx HIBP response, malformed payload, unauthenticated request, CORS preflight, and rate-limit behavior.
6. Verify signup and password recovery both call the checker; inspect any additional password-change or admin/service paths.
7. Confirm no plaintext password, full SHA-1 digest, prefix, or HIBP suffix list is logged or persisted.
8. Deploy only to the authoritative production project after the source is merged and the deployment is explicitly authorized; then verify the deployed version and rerun the Auth/Security Advisor.

## Enabling Supabase Auth protection

When the authoritative production project's plan and dashboard eligibility have been verified, and the owner authorizes the change:

1. Open the Supabase dashboard for project `jxbnrkasktbhtiujkhay`.
2. Open Auth settings and the password-security controls.
3. Enable leaked-password protection if the project plan permits it.
4. Verify signup and password-reset behavior with dedicated QA accounts.
5. Rerun the Supabase Auth/Security Advisor.
6. Update this document with the verified setting, plan eligibility, and date.

Official reference: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
