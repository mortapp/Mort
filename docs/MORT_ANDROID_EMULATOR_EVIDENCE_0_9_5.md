# MORT Android Emulator Evidence 0.9.5

Date: 2026-07-24

Environment: Android `Medium_Phone_API_36.1` emulator, 1080x2400, Android 16,
software graphics, read-only AVD. No physical Android device was used.

## Exact artifact

- Package: `com.mortapp.mobile`
- Version: `0.9.5+95`
- Minimum/target SDK: 24/36
- Manifest permissions: 10
- Signed QA APK bytes: 77,082,652
- Signed QA APK SHA-256:
  `AB0D093E4BB5E5C8AC261C50160CD1C58160D35E2993D6A5433F72B123A8902C`
- Signed AAB bytes: 61,493,557
- Signed AAB SHA-256:
  `C0E404CB4E306D0469A31226108BDA1D1887072E3EDF19816D04821A3FA5EE85`

The APK installed with `adb install -r -t` and the independent package check
confirmed release signing. The AAB signer matched the protected MORT upload
certificate; a debug certificate was explicitly rejected.

## Executed checks

1. Online cold launch: PASS, `LaunchState: COLD`, 12,433 ms total.
2. Hosted backend health check: PASS; connected state rendered only after the
   server RPC completed.
3. Sign-in screen and disabled Google owner-configuration state: visually and
   semantically verified.
4. Process death: PASS; PID ended and a new PID cold-launched in 6,216 ms.
5. Offline cold launch: PASS, 5,950 ms total.
6. Offline state: PASS; `MORT cannot connect right now` and
   `Retry connection` rendered after the bounded health check.
7. Recovery without relaunch: PASS; Wi-Fi/data were restored, the visible retry
   control was tapped, and `Connected securely` returned.
8. MORT-specific fatal exception or ANR after online, offline, and recovery
   checks: none found.
9. System emulator instability: Android System UI and Bluetooth produced system
   dialogs during initial setup. Bluetooth was disabled; neither dialog belonged
   to `com.mortapp.mobile`.

Evidence files remain under `build/emulator-0.9.5/`. The final offline and
recovered screenshots were transferred with binary-safe `adb pull`.

## Not completed on emulator

No real Google provider was configured, so Google sign-in and account linking
were not completed. No QA credentials were entered for a complete role journey.
Avatar persistence/replacement/removal, camera/gallery, push delivery, job and
message role journeys, START/COMPLETION PIN UI, Stripe PaymentSheet, disputes,
account deletion, TalkBack, text scaling, and notification deep links were not
completed on this exact installed build. Hosted adversarial tests cover backend
contracts but do not replace these device journeys.

No physical Android, iPhone, TestFlight, or App Store result is claimed.
