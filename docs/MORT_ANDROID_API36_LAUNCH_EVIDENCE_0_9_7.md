# MORT Android API 36 Launch Evidence 0.9.7

Recorded: 2026-07-28 (America/Indianapolis)

Status: **LIMITED LAUNCH SMOKE PASS**

This evidence does not represent complete native QA, a physical-device test, or approval for real users.

## Build under test

- APK: `C:\Users\micha\Mort\build\play\mort-closed-test.apk`
- Package: `com.mortapp.mobile`
- Version: `0.9.7+97`
- APK bytes: 61,224,372
- APK SHA-256: `B0F005D1DC80A56B770A42F80B3CA21953933C994FA06D5E99B7D0EC7028570A`
- Upload signer: verified by the closed-test release pipeline

## Environment

- AVD: `Medium_Phone_API_36.1`
- Platform: Android API 36.1 generic medium phone
- Emulator: Android Emulator 36.3.10
- Successful graphics backend: `auto-no-window`

## Results

| Check | Result |
|---|---|
| Emulator boot | PASS |
| Signed APK install | PASS |
| App data clear / cold launch | PASS |
| Foreground activity | `com.mortapp.mobile/.MainActivity` |
| AndroidRuntime/Flutter fatal scan | PASS during successful probe |
| Welcome screen rendering | PASS by screenshot inspection |
| Emulator shutdown | PASS |

Screenshot: `C:\Users\micha\Mort\artifacts\native-qa\mort-api36-launch.png`

- Bytes: 450,840
- SHA-256: `35A9DFC922AD29D82E79CEB58A7F6CD5FECEDDD0D99A086CA5345B9664C34466`
- Visual result: closed-pilot badge, MORT rose-gold mark, light-blue safety banner, Enter MORT and Sign in controls, and closed-pilot access disclosure rendered without visible clipping at the captured size.

## Failed attempts retained honestly

1. The first Flutter-launched AVD installed and resumed `MainActivity` but disconnected before durable screenshot evidence.
2. The first scripted `swiftshader_indirect` run installed and cold-launched the app, then the AVD transport closed.
3. The cleanup path initially masked the primary failure when `adb emu kill` targeted the dead emulator; `scripts/qa-android-api36-launch.ps1` was fixed.
4. A second `swiftshader_indirect` run reached the app with no fatal scan finding but went offline during screenshot pull.
5. The final `auto-no-window` run completed and produced the evidence above.

## Still required

- Full teen/adult/guardian/admin journeys on native Android.
- API 24, API 29/30, API 35, and repeated API 36 testing.
- Physical Android phone, preferably Samsung.
- Permission deny/grant, background/foreground, rotation, process death, offline/reconnect, token expiry, PIN abuse, report/block, proof upload, and account-deletion journeys.
- Play Console pre-launch report and owner review.
