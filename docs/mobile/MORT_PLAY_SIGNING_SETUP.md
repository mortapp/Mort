# MORT Android Signing and Play Release Setup

> Status: Google Play production access has been granted for MORT (`com.mortapp.mobile`). This is Play Console eligibility; it does not by itself prove that a particular public-production AAB has been built, submitted, approved, or rolled out. Reviewed 2026-10-25.

At the time of this review, the hosted Supabase release policy reports `closed_test` / `closed_pilot`, with public marketplace, remote push, and real document collection disabled. These are backend capability gates; they do not change MORT's Google Play production-access status or Play release track.

## Implemented signing boundary

- Application ID: `com.mortapp.mobile`.
- Upload key alias: `mort-upload`.
- Private keystore: `C:\Users\micha\MortSecrets\android\mort-upload-key.jks` (outside the repository).
- Local credential source: Windows DPAPI-protected CLIXML outside the repository, or all four `MORT_UPLOAD_*` environment variables.
- Gradle release tasks fail when signing values are missing or incomplete. There is no debug fallback.
- Public certificate report: `docs/mobile/MORT_UPLOAD_CERTIFICATE_REPORT.md`.

The existing local upload key and DPAPI-protected credentials were verified on the release machine against the checked-in public certificate report. Keep using this key for updates to the existing Play listing. Do not generate a replacement.

Required environment names are `MORT_UPLOAD_KEYSTORE_PATH`, `MORT_UPLOAD_KEY_ALIAS`, `MORT_UPLOAD_STORE_PASSWORD`, and `MORT_UPLOAD_KEY_PASSWORD`. Never put values in Git, ZIP files, screenshots, chat, `.env.local`, Flutter source, or Play listing documents.

## Build profiles

Each artifact is built for a distinct MORT backend profile. A Play Console production-access grant does not override the backend release-mode checks.

| Purpose | Entry point | Expected artifact/profile |
|---|---|---|
| Internal closed testing | `scripts/build-standard-closed-test-aab.ps1` | `closed_test` / `closed_pilot`; public marketplace, identity collection, remote push, crash reporting, ads, and IAP remain disabled in this profile. |
| Restricted production pilot | `scripts/build-production-pilot-aab.ps1` | `production_pilot` / `restricted_production_pilot`; public marketplace and real identity collection remain disabled. The live server must report the pilot stage. |
| Public production | `scripts/build-production-public-aab.ps1` | `production_public` / `production`; the local production profile and live server must both have approved public activation. |

The public-production builder fails closed unless the release profile validates and the hosted `get_release_mode_status` RPC reports `production_public`, public marketplace enabled, real document collection approved, and maintenance mode off. The release profile also requires the real remote-push and crash-reporting providers. Public activation, identity processing, and legal/operational approvals remain explicit release gates; do not change profile values to bypass missing approval evidence.

The checked-in GitHub Actions workflow, `.github/workflows/mort-signed-closed-test.yml`, builds only the closed-test profile. The existing upload key is not configured as GitHub Actions secrets, so signed CI builds are not currently available. Local DPAPI recovery does not provision those CI secrets.

## Build and verify

```powershell
.\scripts\build-standard-closed-test-aab.ps1
.\scripts\build-production-pilot-aab.ps1
.\scripts\build-production-public-aab.ps1
.\scripts\build-standard-closed-test-apk.ps1
```

For Play AAB output, run the entry point for the intended profile from the table above. The shared builder pins the Supabase project, validates the server release profile, applies the profile's feature flags, obfuscates Dart code, verifies the upload-certificate signature and manifest, and stores symbol files outside the repository under `%USERPROFILE%\MortSymbols\android\<versionName>+<versionCode>`. The AAB and its verification report are written under `build\play\`; public-production output is named `mort-production-public-<versionName>-<versionCode>.aab`. The standard closed-test APK uses `build-standard-closed-test-apk.ps1`; `build-closed-test-apk.ps1` creates a separate reviewer-demo profile.

## Play App Signing

1. The adult account owner creates the app in Play Console with package `com.mortapp.mobile`.
2. Enroll in Play App Signing. Google protects the app-signing key; MORT keeps the separate upload key.
3. Build with the intended profile and upload only the resulting verified AAB after its server/profile activation gates pass. Do not upload a closed-test or pilot artifact as a public-production release.
4. Compare Play Console's upload-certificate SHA-1 and SHA-256 with the checked-in public certificate report.
5. Never upload or share the JKS. Only the signed AAB and public certificate may leave the release machine.
6. Confirm the Play Console maximum prior version code is lower than the candidate's version code. This repository cannot inspect Play upload history.

Official reference: https://developer.android.com/studio/publish/app-signing
