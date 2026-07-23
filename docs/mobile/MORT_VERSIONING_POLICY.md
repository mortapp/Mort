# MORT Mobile Versioning Policy

> Status: closed-test publication candidate dated 2026-07-20. Not legal approval, not a public launch, and not a production-readiness claim.

The single version source is `flutter_mort/pubspec.yaml`. Current candidate: `0.9.0+90` (Android versionName 0.9.0, versionCode 90).

- `0.x.x`: development, internal test, and closed pilot.
- `1.0.0`: unavailable until separate production approval.
- Android versionCode must increase for every Play upload and must exceed every code already known to Play Console.
- Never reuse or lower a Play versionCode, including after a rejected release.
- Read with `node scripts/read-mobile-version.mjs --json`.
- Increment with `node scripts/increment-android-version.mjs --name 0.9.1 --code 91`; the script refuses a non-increasing code.
- Confirm Play Console's latest artifact before every upload because local source cannot prove remote version history.
