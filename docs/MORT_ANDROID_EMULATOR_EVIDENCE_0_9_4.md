# MORT Android Emulator Evidence 0.9.4

Date: 2026-07-23

Environment: Generic Medium Phone API 36.1 emulator. No physical Android device
was connected, and no physical-device result is claimed.

## Artifact

- Package: `com.mortapp.mobile`
- Version: `0.9.4+94`
- Signed QA APK SHA-256:
  `CFA81CD22B97CC86249909489995FCFF643EC24D3DD2A268E7A64DFB3D0C9BB8`
- AAB SHA-256:
  `DBDCCDA2DB1C7D5B7EDF1BBC3E48AE674893AF5D04BE8E6CE26D1252E45B05FA`
- Min/target SDK: 24/36
- Manifest permissions: 10; background location, foreground service, ad ID,
  advertising-services IDs, and wake lock absent.

## Automated evidence

1. Signed APK streamed install: PASS.
2. Cold launch of `.MainActivity`: PASS.
3. Account entry UI (`Sign In`, `Create Account`, or welcome state): visible.
4. Process alive after cold launch: PASS.
5. MORT fatal/ANR log lines after cold launch: 0.
6. Force-stop/process-death relaunch: PASS.
7. Wi-Fi/data disabled launch: process alive, safe account/retry state visible,
   fatal/ANR lines 0.
8. Wi-Fi/data restored and app relaunched: process alive, fatal/ANR lines 0.
9. Network services restored in cleanup: PASS.

## Not verified in this run

No automated credentials were entered through the emulator UI, so account
creation, full signed-in role journeys, camera/gallery selection, persistent
avatar across reinstall, push delivery, notification taps, all PIN screens,
payment UI, evidence upload, text scaling, TalkBack, dark mode, performance, and
real sensor behavior were not completed on-device. Hosted multi-user and Storage
QA exercised the corresponding backend contracts. These are not substitutes for
physical Android testing.
