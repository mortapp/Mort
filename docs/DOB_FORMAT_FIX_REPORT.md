# DOB Format Fix Report

Date: 2026-07-11

## Result

- Every live Flutter DOB input uses the shared `DateOfBirthField`.
- The visible and accepted format is `MM/DD/YYYY`.
- The formatter inserts slashes after month and day, limits the value to eight digits, supports digit-only and recognized ISO paste, and handles deletion across separators.
- Profile writes remain normalized to the Supabase `date` representation `YYYY-MM-DD`.
- Profile reads convert ISO values back to the U.S. display format without UTC conversion.
- Age is calculated from calendar year, month, and day. Teen roles require ages 13-17; adult and guardian roles require age 18 or older.

## Validation

The shared parser rejects incomplete values, malformed formats, impossible calendar dates, future dates, implausible ages, and role/age mismatches with user-facing errors. Manual entry remains available when the optional date picker is used.

## Verification

- `dart format lib test`: pass, 71 files checked.
- `flutter analyze`: pass, no issues found.
- `flutter test`: pass, 45 tests.
- `scripts/build-web-preview.ps1`: pass, including release web build.
- `scripts/secret-scan.ps1`: pass.
- Built bundle audit: new placeholder/helper/error strings present; old DOB placeholder absent.
- Source audit: both live DOB forms use the shared field; no old DOB input pattern remains.
- Browser audit at 390x844: Flutter loaded, document and body width remained 390 pixels, and no browser warnings or errors were reported.

## Browser Limitation

The hosted-auth sign-up flow must create or authenticate a user before the Age Gate route is available. No QA password was present for this pass, so the browser audit covered the PWA shell and sign-up layout but did not type into the authenticated Age Gate. Formatting, paste, cursor/deletion, validation, keyboard action, and storage conversion are covered by Flutter unit and widget tests. No physical iPhone test was performed.
