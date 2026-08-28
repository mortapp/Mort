# MORT 0.9.13 Emulator Test Matrix

## Device

- AVD: `Medium_Phone_API_36.1`
- Serial: `emulator-5554`
- Android: 16
- API: 36
- ABI for native integration: x86_64
- Final APK SHA-256:
  `38884295182E2FF0D5E6300D15307BEDEF65B6A925DC6B48C897C63FA92B0FD1`

## Exact Final APK

| Scenario | Result | Evidence |
| --- | --- | --- |
| Clean emulator-only install | Pass | Streamed install succeeded after clean AVD state |
| Package/version | Pass | `com.mortapp.mobile`, `0.9.13+103`, min 24, target 36 |
| Cold launch | Pass | Final run `Status: ok`, `LaunchState: COLD`, 6,585 ms |
| Sustained foreground | Pass | PID 3618 and top-resumed MORT activity after 15 seconds |
| Signed-out welcome/auth | Pass | Reviewed launch/auth screenshots and semantic hierarchy |
| Google OAuth start | Pass with external branding gate | Reached `accounts.google.com`; Google displayed raw Supabase host |
| Google cancel recovery | Pass | Continue button re-enabled and cancellation message displayed |
| Fatal/ANR scan | Pass for exercised path | Zero MORT fatal/error matches |
| Warm/process/background/offline/slow network | Not completed | Requires an expanded exact-artifact manual matrix |
| Upgrade from 0.9.12+102 | Not completed | Final run used clean install |
| Teen/Adult/Guardian/Admin authenticated flows | Not completed | No user credentials were automated |
| Camera/gallery/notifications/deletion | Not completed | Physical/manual capability gate |

## Native Integration Harness

The separate driver test APK passed two tests on API 36/x86_64: secure-storage
round trip, device-auth capability, permission snapshot, screen security,
package metadata, and 1.6x large-text safety acknowledgments.

The first listener-based attempt failed after 854.6 seconds with an ADB protocol
fault and Flutter temporary-listener finalization `PathNotFoundException`. It was
not counted as a pass. The runner was changed to `flutter drive`; the retry
passed in 295.4 seconds. The exact signed release APK was reinstalled and
cold-launched after that harness run.

## Classification

Emulator evidence is real but incomplete. It supports a partially verified
closed-test build, not a production-ready claim.
