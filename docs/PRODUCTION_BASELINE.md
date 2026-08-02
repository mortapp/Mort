# MORT Production Candidate Baseline

Recorded: 2026-07-28 (America/Indianapolis)

Verdict at baseline: NOT PUBLIC-PRODUCTION-READY

## Source state

- Branch created for this work: `production-readiness-0.9.7`
- Starting branch: `mort-0.9.5-google-auth-full-completion`
- Starting commit: `f566885453786f1fbdea08291b1b646a5cabe1bc`
- Authoritative client: `flutter_mort`
- Package: `com.mortapp.mobile`
- Baseline app version: `0.9.6+96`
- Linked Supabase project: `rakjydmgwwgtdislanbt`
- Audited redesign ZIP: 5,770,740 bytes
- Audited redesign ZIP SHA-256: `9C94E44BD4C51BB7F609C9FF526B94F67C212949A4DC15B43CC651D1D7BB06B8`

The working tree was intentionally dirty at branch creation. It contained the completed rose-gold redesign, generated launcher assets, previously implemented isolated Play reviewer work, existing 0.9.6 evidence, three applied redesign migrations, and preserved legacy/reference-client directories. No file was reset or discarded. The untracked `RorkIOSManualCopy`, `temp_old_zip`, `temp_zip`, root `lib` reference files, and existing reviewer/evidence files predated this production-readiness pass and remain excluded from release packaging.

## Toolchain

- Flutter: `3.41.2` stable, framework revision `90673a4eef`
- Dart: `3.11.0`
- DevTools: `2.54.1`
- Shell Java: Oracle Java `1.8.0_481`
- Gradle launcher/daemon Java: Microsoft JDK `17.0.17`
- Gradle: `8.14`
- Android Gradle Plugin: `8.11.1`
- Kotlin Android plugin: `2.2.20`
- Android compile SDK: `36`
- Android target SDK: `36`
- Android minimum SDK: `24`
- Node: `24.12.0`
- pnpm: `10.28.0`
- Supabase CLI: `2.109.0` (CLI reported `2.110.0` available)

The shell Java/Gradle Java difference is documented. Gradle is explicitly using JDK 17 and release builds previously completed under that JVM.

## Signing baseline

- Protected credential source: Windows DPAPI
- Existing keystore: present
- Upload certificate SHA-256: `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF`
- Package identity mismatch: none found
- New key generated: no

## Baseline commands and results

| Command | Exit | Result |
|---|---:|---|
| `git branch --show-current` | 0 | Starting branch recorded |
| `git rev-parse HEAD` | 0 | Starting commit recorded |
| `git status --short` | 0 | Dirty state recorded and attributed; no destructive cleanup |
| `git switch -c production-readiness-0.9.7` | 0 | Branch created |
| `flutter --version` | 0 | Flutter/Dart versions recorded |
| `java -version` | 0 | Shell Java 8 recorded |
| `flutter_mort/android/gradlew.bat --version` | 0 | Gradle 8.14 on JDK 17 recorded |
| `flutter analyze` | 0 | No issues; 161.0 seconds |
| `flutter test` | 0 | All 177 tests passed; 96.8 seconds |
| `scripts/secret-scan.ps1` | 0 | Source secret scan passed |
| `scripts/sensitive-file-scan.ps1` | 0 | 1,586 files and 42 known media checked against 10 available secret values |
| `npx supabase migration list --linked` | 0 | Local and remote histories aligned |
| `npx supabase db push --linked --dry-run` | 0 | Remote database up to date; nothing pushed |
| `node scripts/qa-redesign-backend.mjs` | 0 | Fee, transportation, forged-value, and RLS rollback QA passed |
| `scripts/run-final-supabase-regression.ps1` | 1 | First run exposed stale QA fixture after redesigned job amount contract |
| `scripts/run-final-supabase-regression.ps1 -StartAt qa-complete-multi-user-isolation.mjs` | 0 | Remaining 30-script regression passed after fixture repair |

The regression fixture repair changed `scripts/feature-qa-helpers.mjs` from a client payout input to the required gross adult amount. The server continued to derive the teen payout.

## Confirmed baseline blockers

- `flutter_mort/android/app/proguard-rules.pro` was missing while referenced by Gradle.
- Generic release script used obsolete `MORT_ANDROID_*` signing names.
- No validated production pilot/public script existed.
- Reviewer mode lacked a compile-time production gate.
- Digital-purchase dependencies and Billing permission remained in a build where IAP was disabled.
- Crash reporting had no configured provider sink.
- Remote device push had no Flutter token lifecycle.
- Identity provider, approved legal documents, staffed moderation, deletion processing, and native end-to-end device evidence were incomplete.
- Public marketplace activation was correctly fail-closed and must remain closed.

## Existing artifact baseline

- Signed closed-test APK: 78,773,577 bytes, SHA-256 `241BF7A1988268A9BD2385CCC08BF36D8F2CB9A67746251DF4169DC190E2334B`
- Signed closed-test AAB: 62,811,036 bytes, SHA-256 `B16F55A32F05825C318DCBB76F59535F616FCF3A238C2AEED05FF305A825923D`
- Existing certificate verification: PASS
- Existing APK/AAB extracted-value scan: PASS across 2,610 entries

