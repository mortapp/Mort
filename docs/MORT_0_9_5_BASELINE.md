# MORT 0.9.5 Baseline

Captured: 2026-07-23

This report records the verified starting point before 0.9.5 implementation.
It does not claim production readiness or completion of external provider gates.

## Repository

- Authoritative Git root: `C:\Users\micha\Mort`
- Authoritative client: `C:\Users\micha\Mort\flutter_mort`
- Starting branch: `mort-0.9.4-completion-security`
- Working branch: `mort-0.9.5-google-auth-full-completion`
- Starting commit: `ab874540b627578307c34d6b33f7e49839a18066`
- Remote: `https://github.com/mortapp/Mort.git`
- Starting worktree: clean
- Push state: not attempted; GitHub owner authentication and author identity are not verified

The eight entries in `artifacts/MORT_0_9_4_ARTIFACT_INVENTORY.json` were
rehashed. Every artifact existed and every byte count and SHA-256 matched.

Protected source backup:

- Path: `backups/0.9.5-baseline/mort-source-ab87454-20260723005446.zip`
- Bytes: `3,163,324`
- Entries: `1,642`
- SHA-256: `96CE53CA065EB1CA86DAC85C1B73CDE0F0BDE6D50F1A8B091E16089D49295099`

## Toolchain

- Flutter: `3.41.2`, stable, revision `90673a4eef`
- Dart: `3.11.0`
- Supabase CLI: `2.109.0`
- Stripe CLI: unavailable on this Windows host
- Android platform/target SDK: `36`
- Android Debug Bridge: `36.0.2-14143358`
- Gradle JDK: Microsoft OpenJDK `17.0.17+10-LTS`
- Shell-default Java: Oracle Java `1.8.0_481`; release scripts select JDK 17

Dependency resolution reported 33 newer packages outside current constraints.
No dependency was upgraded as part of baseline capture.

## Application Identity

- Flutter version: `0.9.4+94`
- Android application ID and namespace: `com.mortapp.mobile`
- iOS bundle identifier: `com.mortapp.mobile`
- Android minimum SDK: `24`
- Android target SDK: `36`
- Existing custom scheme: `mort`
- Existing configured Flutter redirect: `mort://app/auth-callback`
- Existing Supabase mobile allowlist entry: `mort://auth-callback`
- Existing web origin: `https://mort-web.vercel.app`
- Upload certificate SHA-1: `7F:3E:52:5C:05:F3:D8:72:C1:68:63:08:EA:F2:79:5A:8E:96:D9:97`
- Upload certificate SHA-256: `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`
- Debug certificate SHA-1: `EC:4F:C8:69:23:AE:03:51:0D:CC:4D:9C:9C:8C:5B:E8:02:0E:44:A5`
- Debug certificate SHA-256: `6A:42:90:83:85:1A:F4:4B:03:35:EF:2C:24:C7:1A:36:C5:C0:4F:EC:D7:75:5E:55:13:4B:80:53:BF:FC:F1:EB`

The existing Flutter redirect and hosted allowlist do not match. Google login
was therefore not considered usable at baseline.

## Authentication Audit

- Supabase Flutter: `2.16.0`
- GoTrue Dart: `2.26.0`
- Auth flow type: PKCE
- Native session persistence: custom `MortSecureSessionStorage`
- Web session persistence: `SharedPreferencesLocalStorage`
- Auth repository: `flutter_mort/lib/data/repositories/auth_repository.dart`
- Sign-in and registration UI: `flutter_mort/lib/features/mort_screens.dart`
- Auth listener: Riverpod `authStateProvider`
- Onboarding guard: `GuardedRoute` plus `evaluateRouteAccess`
- Profile bootstrap: idempotent `on_auth_user_created` trigger
- Profile writes: protected `save_my_onboarding_profile` and `update_my_profile` RPCs
- Password reset: Supabase reset flow using the configured redirect
- Account deletion: protected in-app request and deletion workflow from 0.9.4
- Google OAuth implementation: absent
- Connected Accounts UI: absent
- Manual identity linking: disabled in hosted Auth configuration

The profile trigger inserts with `ON CONFLICT DO NOTHING`. It may use provider
display name only for the first empty profile row and does not overwrite an
existing MORT profile on a later login or link event. Role, DOB, verification,
admin authority, restrictions, and onboarding state are not derived from OAuth
metadata.

## Hosted Supabase

- Project ref: `rakjydmgwwgtdislanbt`
- Migration history: local and remote aligned through `20260723030622`
- Active Edge Functions: `16`
- Database lint at error level: no findings
- Private Storage buckets: `8`
- Public marketplace: closed
- Real identity collection: disabled
- Google provider: disabled
- Google client ID: not configured
- Google client secret: not configured
- Google nonce skipping: disabled, so nonce checking remains enabled
- Manual identity linking: disabled
- Email autoconfirm: disabled
- Hosted password minimum: `6`; client registration uses a stronger validator
- Hosted redirect allowlist: includes exact mobile/web entries plus one broad
  web wildcard that requires 0.9.5 tightening

Stripe functions are deployed but Stripe CLI and local provider secrets are
absent. Provider-backed Stripe transactions were not baseline-tested and
real-money mode remains disabled.

## Route Inventory

The last verified generated inventory contains 175 Flutter routes and 46 Expo
reference source routes. The Expo app remains reference-only and is not counted
as duplicate Flutter completion. Four Flutter route builders were mechanically
unresolved and 142 routes had no direct static route test at 0.9.4.

## Baseline Commands

| Command | Real result |
|---|---|
| `flutter pub get` | PASS; dependencies resolved, 33 constrained updates reported. |
| `dart format --output=none --set-exit-if-changed lib test` | PASS; 152 files, zero changes. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | PASS; no issues. |
| `flutter test` | PASS; 128/128 tests. |
| `npx supabase migration list --linked` | PASS; aligned through `20260723030622`. |
| `npx supabase functions list --project-ref rakjydmgwwgtdislanbt` | PASS; 16 active functions. |
| `npx supabase db lint --linked --level error` | PASS; no findings. |
| `.\scripts\run-final-supabase-regression.ps1` | PASS; 26/26 scripts and 30/30 isolation checks. |

## Baseline Limitations

- No Google Cloud credentials or Google OAuth client secret were available.
- Google is not enabled in Supabase Auth.
- No approved Google test-account login was performed.
- No Google account-linking runtime test was performed.
- No Stripe provider transaction was performed.
- No physical Android device test was performed.
- No macOS/Xcode/iPhone/TestFlight test was performed.
- No legal, tax, privacy, labor, or teen-safety approval was performed.
- The eleven older synthetic reviewer fixtures remain pending owner classification.
- Supabase leaked-password protection remains **DEFERRED - PLAN-LIMITED SECURITY ENHANCEMENT**.
