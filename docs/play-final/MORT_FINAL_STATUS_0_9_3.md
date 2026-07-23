# MORT 0.9.3 Final Status

Release label: Android closed-test candidate, not production ready.

- Authoritative client: `flutter_mort` 0.9.3+93.
- Supabase project: `rakjydmgwwgtdislanbt`.
- Remote backend regression: 26/26 scripts.
- Multi-user isolation: 30/30 checks.
- Stripe boundary QA: 25/25 scripts, with provider operations disabled.
- Focused support/PIN/evidence QA: 8/8 scripts.
- Flutter: format unchanged, analyzer clean, 115/115 tests, web release built.
- Android: signed APK/AAB, app-module release lint, and API 36 emulator launch/sign-in validation evidence.
- Expo reference: typecheck/lint/Doctor 20/20/web export pass.
- Source/dependency/binary secret scans pass.
- Development completion: 73% under strict binary gates.
- Production launch readiness: 60% under strict binary gates.

No iPhone, Xcode, TestFlight, Stripe live, qualified legal review, provider budget dashboard, production monitoring, incident exercise, or restore exercise is claimed.

## Final Android Artifacts

- APK: `mort-android-0.9.3-final-qa.apk`, 75,267,252 bytes, SHA-256 `8DBA82C5DDA1A0EC9795D257898E8D31B34BFB9B63738F072655F16EA9195445`.
- AAB: `mort-android-0.9.3-closed-test.aab`, 61,166,576 bytes, SHA-256 `B9EAF06FE4CB7EBC698039DCCF5F619B483AE56E8F417DADEE92B0EAB730D33B`.
- Package: `com.mortapp.mobile`; version `0.9.3+93`; min SDK 24; target SDK 36.
- Android 36 emulator: clean install, foreground launch, home render, Sign In navigation, empty-form validation, and zero MORT fatal/ANR log lines passed.
- A transient `com.android.systemui` ANR occurred after the resource-heavy build. It was verified as System UI, dismissed, and the MORT checks were rerun successfully. It is not counted as physical-device evidence.
