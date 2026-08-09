# MORT Codex Overnight State

- Updated: 2026-08-08 (America/Indianapolis)
- Branch: `feature/compact-onboarding-and-screen-polish`
- Latest verified checkpoint before final documentation: `3c1f9f0`
- Runtime artifact source: `909a4235268ee16b2d6884862c0236cbec632b4b`
- Version: `0.9.14+104`
- Package: `com.mortapp.mobile`

## Completed

- Unified auth, role onboarding, Liquid Glass system, role dashboards,
  messaging, settings, Safety Center, and route/action audit are committed.
- Hosted Supabase regression passed 45/45 scripts; migration parity, schema
  lint, advisors, RLS, and storage checks passed.
- Flutter analyzer and full tests passed: 349 passed, two provider-gated skips.
- Expo reference checks, lint, build, export, and Doctor passed.
- Play release QA passed after stale QA assertions were repaired.
- Signed APK and AAB from clean runtime source are verified.
- APK target SDK 36, 11 permissions, and 18/18 native-library 16 KB alignment
  passed.
- Android release lint passed.
- API 36 native integration passed two test bodies with the canonical version
  injected through non-secret test defines.
- Exact signed APK cold-launched on API 36 with the process alive, MainActivity
  resumed, and no fatal Android/Flutter logs.

## Open

- The Samsung SM-A146U remembered wireless endpoint refused the final connection.
- The repaired OAuth callback to `/account-status` still needs the exact physical
  rerun with zero invalid-matrix errors.
- Authenticated Teen, Adult, Guardian, Admin, and Support hardware journeys need
  secure human login.
- Provider, moderation/support staffing, legal/privacy, Play Console, and iOS
  gates remain external.

## Next Exact Step

Finish the final local gates and package `artifacts/release-0.9.14+104`. When the
owner securely re-enables Samsung wireless debugging and authenticates, install
the exact signed APK and rerun the OAuth/account-status and role matrices without
recording credentials or private device data.
