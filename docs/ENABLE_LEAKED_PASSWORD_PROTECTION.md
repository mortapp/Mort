# Enable Leaked-Password Protection

## Current classification

**DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT**

Project: `rakjydmgwwgtdislanbt`

Verified on 2026-07-14: the Supabase dashboard would not enable HaveIBeenPwned leaked-password protection because the project is on the Free plan. Supabase documents this control as available on Pro and above.

This advisor finding is a defense-in-depth enhancement blocked by the current plan, not an unresolved MORT application-code security bug. Do not upgrade the plan or spend money solely to complete this task without separate authorization.

## Current mitigations

- strong password minimum length
- required password complexity
- Auth rate limiting
- email verification
- RLS
- account restriction logic
- secure password reset flow

These controls reduce password guessing, automated abuse, unauthorized data access, and account-recovery risk. They do not duplicate the HaveIBeenPwned corpus check, so the plan-limited enhancement remains worth enabling after a future authorized upgrade.

## Future upgrade task

> When Supabase is upgraded to Pro, enable leaked-password protection immediately and rerun Auth security advisors.

## Future manual procedure

Only after a separately authorized Supabase Pro upgrade:

1. Open the Supabase dashboard for project `rakjydmgwwgtdislanbt`.
2. Open Auth settings and the password-security controls.
3. Enable leaked-password protection and save the configuration.
4. Verify signup and password-reset behavior with dedicated QA accounts. Do not use real user credentials.
5. Rerun the Supabase Auth/Security Advisor.
6. Update `docs/SUPABASE_FINAL_ADVISOR_AUDIT.md` with the verified result and date.

Official reference: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
