# MORT Supreme Security Review

## Verified Controls

- Supabase Auth is the sole identity/session authority; PKCE is used for Google OAuth.
- Role, account status, onboarding, verification, credits, and marketplace transitions are server authoritative.
- All 45 hosted regression suites passed, including 30 explicit cross-user/RLS checks.
- Nine Storage buckets are private with 18 object policies; no object path/content was read during inventory.
- Linked migration parity is 158/158; `db lint --level error` is clear and dry-run is up to date.
- Signed APK/AAB match the protected upload certificate and reject debug signing.
- APK/AAB scan covered 970 extracted entries against available sensitive values and Google client-secret markers.
- Final source scan covered 1,861 files and 54 reviewed media assets against 10 available secret values.
- Cleartext, broad storage, background location, billing, advertising ID, AdMob auto-init, and wake-lock capabilities are absent from the final release.
- APK ZIP and all 18 ELF native libraries pass 16 KB alignment checks.

## Advisor State

Supabase returned no error-level security or performance findings. Security has
82 info and 288 warning findings, dominated by intentionally callable
security-definer RPCs that are exercised by authorization QA. Performance has
213 info and 5 warning findings. These counts require ongoing review; they are
not evidence that every advisor suggestion is irrelevant.

Leaked-password protection is **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**.
Supabase requires Pro for the HaveIBeenPwned control. Current mitigations are
password length/complexity, Auth rate limits, email verification, RLS, account
restriction, and secure reset. When Supabase is upgraded to Pro, enable leaked-
password protection immediately and rerun Auth security advisors.

## Residual Risks

- Production provider credentials and webhooks are not activated or end-to-end tested.
- Eleven long-lived synthetic pilot/reviewer accounts remain; all use the synthetic domain, but active admin/partner assignments must be reviewed and removed before real users.
- Physical-device log, tamper, network-loss, biometric, camera, and notification testing is incomplete.
- Human moderation/support and legal response processes are unstaffed.
- Dependency updates shown by `flutter pub outdated` need isolated compatibility review; no known production npm vulnerability was reported.

No unresolved Critical/High code-controlled vulnerability was found in this
pass. That is not a penetration-test, legal, provider, or public-launch approval.
