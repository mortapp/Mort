# MORT Google Play Upload Signing Setup

> Status: historical signing procedure; production AAB not yet re-verified as of 2026-11-04. A QA-only device-test APK exists, but it is not a signed Play Store AAB or store certification.

## Implemented signing boundary

- Application ID: `com.mortapp.mobile`.
- Upload key alias: `mort-upload`.
- Private keystore: `C:\Users\micha\MortSecrets\android\mort-upload-key.jks` (outside the repository).
- Local credential source: Windows DPAPI-protected CLIXML outside the repository, or all four `MORT_UPLOAD_*` environment variables.
- Gradle release tasks fail when signing values are missing or incomplete. There is no debug fallback.
- Public certificate report: `docs/mobile/MORT_UPLOAD_CERTIFICATE_REPORT.md`.

Required environment names are `MORT_UPLOAD_KEYSTORE_PATH`, `MORT_UPLOAD_KEY_ALIAS`, `MORT_UPLOAD_STORE_PASSWORD`, and `MORT_UPLOAD_KEY_PASSWORD`. Never put values in Git, ZIP files, screenshots, chat, `.env.local`, Flutter source, or Play listing documents.

## Build and verify

`powershell
.\scripts\build-play-aab.ps1
.\scripts\verify-play-aab.ps1
.\scripts\build-closed-test-apk.ps1
`

The production AAB build targets `jxbnrkasktbhtiujkhay`; QA/device-test builds target `ckcxakhxqlkhppsxxjhv`. The production AAB build fixes release stage to `closed_test`, fixes operational mode to `closed_pilot`, disables public marketplace and real identity verification, disables ads and IAP, obfuscates Dart code, and stores symbol files outside the repository at `C:\Users\micha\MortSymbolsandroid\0.9.0+90`.

## Play App Signing

1. The adult account owner creates the app in Play Console with package `com.mortapp.mobile`.
2. Enroll in Play App Signing. Google protects the app-signing key; MORT keeps the separate upload key.
3. Upload `build/play/mort-closed-test.aab` only after `verify-play-aab.ps1` passes.
4. Compare Play Console's upload-certificate SHA-1 and SHA-256 with the checked-in public certificate report.
5. Never upload or share the JKS. Only the signed AAB and public certificate may leave the release machine.
6. Confirm the Play Console maximum prior version code is lower than 90. This repository cannot inspect Play upload history.

Official reference: https://developer.android.com/studio/publish/app-signing
