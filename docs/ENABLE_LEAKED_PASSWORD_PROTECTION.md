# Enable Leaked-Password Protection

## Current classification

**DEFERRED — PLAN-LIMITED SECURITY ENHANCEMENT**

Production project: `jxbnrkasktbhtiujkhay`

Isolated QA project: `ckcxakhxqlkhppsxxjhv`

Verified on 2026-07-14: the Supabase dashboard would not enable HaveIBeenPwned leaked-password protection because the project was on the Free plan. Supabase documents this control as available on Pro and above. The retired project `rakjydmgwwgtdislanbt` must never be used.

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

## Exact authorized configuration change

This change is **prepared but not authorized or applied in this session**. A project owner must separately approve the plan upgrade, the production Auth setting change, and the post-change verification window. No application migration or secret change is required.

First apply and verify the setting in isolated QA using the QA project's Auth dashboard or the currently supported Supabase management interface. Use only dedicated synthetic QA accounts and confirm that a password known to be present in the HIBP corpus is rejected while a non-breached policy-compliant password follows the normal signup/reset path. Do not use synthetic JWT claims, real credentials, or real identity data.

After QA evidence is reviewed, an authorized owner may make the same setting change in the production project's Auth password-security controls:

1. Confirm the production dashboard is project `jxbnrkasktbhtiujkhay` and the plan is Pro or above.
2. Open Auth settings and the password-security controls.
3. Enable leaked-password protection and save the configuration.
4. Verify the setting is enabled in the production dashboard without attempting a real-user signup or reset.
5. Run the approved synthetic QA signup and password-reset checks against QA, not production.
6. Rerun the Supabase Auth/Security Advisor for production and record the finding count, timestamp, project ref, and dashboard evidence.
7. Update `docs/SUPABASE_FINAL_ADVISOR_AUDIT.md` and the consolidated production-readiness report with the verified result and date.

## Rollback and failure handling

The setting is a defense-in-depth control and must not be disabled merely to bypass a test failure. If a provider or Auth regression is confirmed, the owner may disable the setting through the same production dashboard only after recording the incident, impact, approver, and reason; then rerun the Auth advisor and restore the existing password-policy and rate-limit controls. Any rollback must be followed by a new QA reproduction and a provider/support review before re-enablement.

No plan upgrade, dashboard change, production configuration change, or advisor rerun was performed in this session.

Official reference: [Supabase password security](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).
