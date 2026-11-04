# Enable Leaked-Password Protection

## Current status (2026-11-04)

<badge>Deferred — production setting not yet enabled</badge>

- Production project: `jxbnrkasktbhtiujkhay`.
- QA project: `ckcxakhxqlkhppsxxjhv`.
- The November 3–4 production security audit found leaked-password protection disabled.
- The prior Free-plan limitation was verified against the retired project `rakjydmgwwgtdislanbt`; that does not prove the current production project's plan or feature availability.

Do not upgrade a plan or spend money solely to complete this task without separate authorization.

## Required validation

1. Confirm the current production project's plan and whether leaked-password protection is available.
2. Verify signup, password update, and password-reset UX in QA with dedicated test accounts.
3. Confirm error handling is safe and does not expose whether an email address exists.
4. Obtain release-owner approval before changing the production Auth setting.
5. Enable the setting in the production dashboard only after the QA flow passes.
6. Re-run the Supabase Auth/Security Advisor and record the verified result and date.

## Current mitigations

- password length and complexity requirements
- Auth rate limiting
- email verification
- RLS and account restriction logic
- secure password reset flow

These controls do not replace a breached-password corpus check. Keep the item open until the current production project is checked and the control is enabled or its limitation is documented.

Official reference: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
