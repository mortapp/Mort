# MORT Release Readiness

Status: Android closed-test candidate built; public production launch blocked.

## Verified Here

- Flutter 0.9.3+93 formatting, analyzer, 115 tests, web release build.
- Signed Android APK and obfuscated AAB for `com.mortapp.mobile`, minSdk 24, targetSdk 36; MORT app-module `lintRelease` passes.
- Upload certificate verification and no debug signing.
- API 36 emulator install, foreground launch, home/sign-in rendering, accessible semantics, empty-form validation, and no fatal log entries.
- Remote Supabase migration parity, schema error lint, 26-script regression, 30 isolation checks, 25 Stripe boundary scripts, and 8 focused support/PIN scripts.
- Source, dependency, sensitive-file, and binary artifact scans.

The final emulator run used the exact named APK. A transient emulator System UI ANR occurred after the native build; window focus and accessibility hierarchy proved it belonged to `com.android.systemui`. After dismissal, MORT was foregrounded and the launch/sign-in/validation/no-fatal checks passed. This does not substitute for a physical Android test.

## Not Verified

- Physical Android authenticated critical-flow matrix or Play pre-launch report.
- Any iPhone, macOS/Xcode, archive, signing, TestFlight, push, deep-link, camera, avatar, PIN, support, or Stripe device flow.
- Stripe provider end-to-end operations or live mode.
- External AI generation and provider dashboards.
- Qualified legal/tax/privacy/teen-safety review.
- Production monitoring, alert receipt, staffing, incident exercise, or restore drill.

Public marketplace, real identity collection, live payments, external AI, ads, and IAP must remain off. This is not production ready.
