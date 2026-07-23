# MORT Android Release Threat Review

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

## Verified source controls

- HTTPS-only Android network policy; cleartext disabled.
- Hosted Supabase project fixed to `rakjydmgwwgtdislanbt` by release scripts.
- No service-role, database password, Supabase access token, provider secret, or signing password is passed as a Dart define.
- Secure session storage uses `flutter_secure_storage`; Supabase owns refresh/session handling.
- Release signing fails closed and is checked against the upload certificate.
- Public marketplace, identity-document verification, IAP, and ads are false compile-time flags.
- Custom `mort://app` deep link is routed through authenticated app state; universal HTTPS links are not claimed.
- Cleartext, localhost, private development IPs, verbose content logging, message crash logging, and coordinate analytics are prohibited.

## Residual threats and gates

- A compiled public Supabase anon key is expected and not privileged; RLS remains the security boundary.
- RevenueCat and Google Mobile Ads native code remains bundled while disabled. The final AAB/Play SDK scan must be reviewed for transitive behavior and policy declarations.
- Obfuscation symbols must be retained outside the repo for every uploaded version.
- Physical process-death, secure-storage, biometric, notification-preview, photo-picker, deep-link, and offline tests remain required.
- Play Console version history, pre-launch report, SDK warnings, and signing enrollment are external manual checks.
- External legal pages need real adult publisher/contact values and an HTTPS deployment.
