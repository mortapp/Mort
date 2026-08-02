# MORT Android Emulator Evidence 0.9.6

This report records Google Play reviewer-mode QA against the signed closed-test APK. It is not a production-readiness claim and is not a physical-device result.

## Artifact under test

- Package: `com.mortapp.mobile`
- Version: `0.9.6+96`
- APK: `build/play/mort-play-closed-test-qa.apk`
- Bytes: `77116060`
- SHA-256: `9F4A638039D7272BF12E39AE98A36419CF94C77FC28BAEC3C413E0C5A5DD94FA`
- Signing: verified by `scripts/qa-android-apk.ps1 -RequireSigned`
- Emulator: `Medium_Phone_API_36.1`, Android 16, 1080x2400

## Observed reviewer flow

- Entering exact ASCII identifier `play-review@mortapp.test` hid password, Google, registration, and recovery actions and exposed `Continue as Play Reviewer`.
- The role selector opened Teen, Adult, Guardian, Support, and Admin demonstrations.
- Teen accepted demo START PIN `123456`, accepted demo COMPLETION PIN `654321`, advanced a synthetic payment state, and attached local synthetic proof.
- Adult completed the local job setup/review/schedule/scope/completion checklist and displayed demo PINs.
- Guardian and Support routes opened with synthetic workflows.
- Admin opened read-only simulations and explicitly stated that it was not a production administrator session.
- Exiting reviewer mode restored normal sign-in controls.
- Force-stopping and relaunching changed the app process and returned to the public splash; reviewer state did not persist.
- MORT log inspection found no MORT fatal exception or MORT ANR during the flow.

## Evidence

Raw screenshots and accessibility trees are retained in `build/emulator-0.9.6` and copied into `mort-play-reviewer-evidence-0.9.6.zip` under `signed-apk-emulator`.

Key captures include:

- `reviewer-exact.png` and `.xml`
- `role-selector.png` and `.xml`
- `teen-pins-complete.png`
- `adult-top.png` and workflow XML captures
- `guardian-top.png`
- `support-top.png`
- `admin-top.png`, `admin-bottom.png`, and XML captures
- `after-exit.xml`
- `after-process-restart.png` and `.xml`

## Honest limitations

- The emulator displayed one Android System UI ANR dialog during startup. Selecting Wait recovered the emulator. This was not a MORT process ANR, but it makes this emulator run unsuitable as the only release signal.
- Android ADB bulk text injection dropped characters; the exact reviewer identifier was entered character by character for the successful test.
- Normal sign-in controls were restored in the signed APK, but a real normal-user session was not completed in this emulator pass. Automated Flutter UI and remote ordinary Auth creation covered that boundary.
- No physical Android phone was tested.
- The AAB signature and contents were verified, but an AAB is not installed directly on the emulator.

