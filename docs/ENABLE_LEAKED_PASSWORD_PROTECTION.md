# MORT Leaked-Password Protection

**2026-11-21 status:** MORT's custom password guard is the release candidate; no paid-plan change is required to evaluate it. It is implemented in [PR #109](https://github.com/mortapp/Mort/pull/109), available in hosted QA, and not deployed as an enforced guard in production. The built-in [Supabase password control](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection) is a separate setting, not evidence for or against MORT's implementation.

## Current contracts

- **Production `jxbnrkasktbhtiujkhay`:** `leaked-password-check` v3 is deployed. It requires a real authenticated caller, expects `sha1Prefix`, and returns `suffixes` and `degraded`. Flutter on `main` still sends `password`, expects `leaked` and `check_unavailable`, and interprets errors as not leaked. Do not count that integration as working protection. Production has neither `password-guard` nor the password-attestation triggers.
- **QA `ckcxakhxqlkhppsxxjhv`:** `password-guard` v1, the service-role-only quota RPC, and Auth password-attestation triggers are present. This is catalog evidence, not proof that the current Flutter build successfully signs up and recovers an account using them.
- **Flutter candidate:** The code in #109 uses the custom guard for signup and password recovery, checks for breached passwords server-side, shares only a hash prefix with the breach corpus, and refuses a password write if the check cannot complete. This replaces the legacy incompatible preflight rather than restoring it as an enforcement mechanism.

## Before authorizing any production rollout

1. Verify the exact Flutter candidate on QA with fresh accounts and controlled inboxes. Cover breached and acceptable passwords, email confirmation, reset-link/deep-link handling, recovery with a new password, existing sign-in, and Apple/Google OAuth. Keep provider outages and policy failures covered by isolated tests.
2. Reconcile the candidate with current `main` and [PR #115](https://github.com/mortapp/Mort/pull/115). Do not merge #109 or #114 as part of this verification. The production client is Flutter; Swift-reference results do not satisfy this gate.
3. Separate backend prerequisites from final enforcement in the reviewed rollout. The guard requires its quota RPC and secrets before the client can use it. Stage those prerequisites without rejecting existing password writes, verify the guard, and resolve installed-client compatibility before authorizing the enforcement triggers. Do not deploy a guard-dependent Flutter build before that endpoint works. Do not apply the trigger migration while supported clients still depend on direct password writes.
4. After separate production approvals, verify the deployed Edge bundle, exact triggers and grants, and successful supported-client signup and recovery. Document rollback for both the triggers and app compatibility. Keep the production gate open until live evidence exists.
