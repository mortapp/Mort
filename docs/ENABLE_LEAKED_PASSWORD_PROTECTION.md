# Leaked-Password Protection

## Current production status

**SUPABASE AUTH CONTROL DISABLED — CUSTOM MORT CHECKER UNDER REPAIR**

Authoritative production project: `jxbnrkasktbhtiujkhay`.

On 2026-11-13, the live Supabase Security Advisor reported `auth_leaked_password_protection` as **WARN — Leaked Password Protection Disabled**. This means the separate Supabase Auth HaveIBeenPwned check is not enabled.

The repository also contains a custom MORT HIBP k-anonymity Edge Function and Flutter client. A source review found that the Flutter client and Edge Function used incompatible request/response contracts, so the Flutter check could fail open without completing the lookup. The correction is in PR #91 and must not be considered complete until CI and the focused tests pass and the change is merged.

An older version of this document referred to project `rakjydmgwwgtdislanbt`. That project is deleted and is not the production target. The old project's July 2026 Free-plan limitation does not establish the current plan or feature eligibility of `jxbnrkasktbhtiujkhay`.

Do not change the Supabase plan, spend money, or change production Auth settings without separate authorization.

## How the custom MORT checker is intended to work

1. The client computes the SHA-1 digest locally.
2. The client sends only the first five hexadecimal characters to MORT's authenticated Edge Function.
3. The Edge Function queries the HaveIBeenPwned range API using that prefix and returns candidate suffixes.
4. The client compares the remaining 35 digest characters locally.
5. The plaintext password and complete digest must never be sent to HaveIBeenPwned or written to logs.

The current availability policy is fail-open: if the HIBP service or MORT check endpoint is unavailable, signup/password recovery is not blocked. This avoids provider outages locking users out, but means an outage can temporarily bypass the custom breach check. Keep this trade-off explicit and cover it with tests.

## Separate controls — do not conflate them

- **MORT custom HIBP checker:** application code and Edge Function; its client/backend contract and all password-setting paths require tests.
- **Supabase Auth leaked-password protection:** independent server-side Auth control; currently reported disabled by the production advisor.
- **GitHub secret scanning and push protection:** controls for credentials accidentally committed to source/history. They do not check whether an end-user password appears in a breach corpus.

## Verification checklist

After PR #91 is merged:

1. Confirm the Flutter SHA-1 prefix and suffix comparison unit tests pass.
2. Confirm the Edge Function accepts only an authenticated request with a valid five-character prefix and returns the expected `ok`, `degraded`, and `suffixes` fields.
3. In a controlled QA environment, test a known breached fixture and a known clean fixture. Never use a real user's password.
4. Test HIBP timeout, non-2xx response, malformed payload, and unauthenticated request behavior.
5. Verify signup and password recovery both call the checker; inspect any additional password-change or admin/service paths.
6. Confirm no plaintext password, full SHA-1 digest, or HIBP suffix list is logged or persisted.
7. Rerun the production Supabase Security Advisor and record the Auth leaked-password control separately from the custom checker.

## Enabling Supabase Auth protection

When the authoritative production project's plan and dashboard eligibility have been verified, and the owner authorizes the change:

1. Open the Supabase dashboard for project `jxbnrkasktbhtiujkhay`.
2. Open Auth settings and the password-security controls.
3. Enable leaked-password protection if the project plan permits it.
4. Verify signup and password-reset behavior with dedicated QA accounts.
5. Rerun the Supabase Auth/Security Advisor.
6. Update this document with the verified setting, plan eligibility, and date.

Official reference: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
