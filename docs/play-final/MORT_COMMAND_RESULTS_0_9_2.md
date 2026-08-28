# Command Results 0.9.2

Commands below were run from `C:\Users\micha\Mort` unless a subdirectory is shown.

| Command | Result |
| --- | --- |
| `npx supabase db push --linked` | Pass; migration `20260722050500` applied after earlier MORT Guide and Billing migrations |
| `npx supabase migration list --linked` | Pass; local/remote aligned through `20260722050500` |
| `npx supabase db lint --linked --level warning --fail-on error` | Pass; no error-level result, identity-stub warnings documented |
| `npx supabase db advisors --linked --type security --level warn --fail-on error` | Pass with warnings; reviewed in advisor report |
| `npx supabase db advisors --linked --type performance --level warn --fail-on error` | Pass with one overlapping-policy warning |
| Focused Node QA loop | Pass, 50/50 scripts |
| `.\scripts\run-final-supabase-regression.ps1` | Pass, 23/23 scripts |
| `flutter pub get` | Pass; lockfile resolved |
| `dart format lib test` | Pass; 134 files, 0 changed |
| `flutter analyze` | Pass; no issues |
| `flutter test` | Pass; 105 tests |
| `flutter build web --release --dart-define=WEB_PREVIEW_MODE=true --dart-define=IAP_ENABLED=false --dart-define=ADS_ENABLED=false --dart-define=USE_TEST_ADS=true` | Pass; `build/web` created |
| First signed APK/AAB build | Compiled and signed, then rejected by emulator because PowerShell concatenated Dart defines |
| Corrected `flutter build apk --release --build-name=0.9.2 --build-number=92` with nine separate closed-pilot defines | Pass; corrected APK built |
| Corrected `flutter build appbundle --release --build-name=0.9.2 --build-number=92` with the same defines | Pass; corrected AAB built |
| `.\scripts\verify-play-aab.ps1 -BundlePath ...app-release.aab` | Pass; package/version/SDK/signer verified |
| `apksigner verify --verbose --print-certs ...app-release.apk` | Pass; v2 signature, one MORT signer |
| API 36 emulator `adb install -r`, launch, process/log/screenshot checks | Pass; Closed Pilot and hosted backend visible, sign-in route rendered |
| `.\scripts\secret-scan.ps1` | Pass for source values |
| `node scripts\qa-aab-secret-scan.mjs` | Pass; 917 entries checked against four available sensitive values |
| `node scripts\qa-aab-signing.mjs` | Pass; expected upload certificate, debug signer rejected |
| `.\scripts\sensitive-file-scan.ps1` against workspace | Expected fail on local `.env.local`; archives must exclude it and are scanned separately |

Local Edge probes compiled `ai-support`, `google-play-verify-purchase`, and `google-play-rtdn`; unauthenticated/unauthorized requests returned 401. Remote `ai-support` and `ai-safety` are active and return 401 without authentication. Google Play and Stripe provider functions were not deployed because their server credentials are absent.
