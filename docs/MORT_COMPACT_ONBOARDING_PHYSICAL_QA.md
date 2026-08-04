# MORT Compact Onboarding Physical QA

Date: 2026-08-04
Branch: `feature/compact-onboarding-and-screen-polish`

## Verified APK

- Path: `C:\Users\micha\Mort\artifacts\compact-onboarding-qa\mort-compact-onboarding-qa-0.9.13+103.apk`
- Package: `com.mortapp.mobile`
- Version: `0.9.13+103`
- minSdk: `24`
- targetSdk: `36`
- Size: `68,400,126` bytes
- SHA-256: `E9B96BD0F7950631647B0D5656CE7DCBBCE4AFCF6D3E334DAE9B73AF448B46F8`
- Signed: `true`
- Profile: `closed_test`

## QA Status

- APK built through the repository-approved closed-test release path.
- QA verification of signing and package metadata passed.
- Physical device installation and runtime verification remain pending.

## Physical QA Preparation

Use the following commands once ADB device connectivity is available:

- `adb devices -l`
- `adb install -r "C:\Users\micha\Mort\artifacts\compact-onboarding-qa\mort-compact-onboarding-qa-0.9.13+103.apk"`

If a signing mismatch occurs:

- `adb uninstall com.mortapp.mobile`
- `adb install "C:\Users\micha\Mort\artifacts\compact-onboarding-qa\mort-compact-onboarding-qa-0.9.13+103.apk"`

## Physical QA Coverage

The physical QA journey should cover:

- email login and Google login
- Terms and Privacy links
- five-step onboarding
- location allow and deny flows
- city/ZIP fallback
- interrupted onboarding resume
- Applications and application details
- Job Feed search/filter/sort/refresh
- Saved Jobs removal workflow
- Safety Center `Call 911` action
- Safety Ping and Safety Circle
- ordinary screenshots and protected sensitive route behavior
- Android back gesture, background/resume, and restart behavior
- logcat scans for `TransformLayer is constructed with an invalid matrix`, `FATAL EXCEPTION`, `ANR`, `E/flutter`, `AuthRetryableFetchException`, and `com.mortapp.mobile`

## Status

- Build and verification complete.
- Physical runtime validation required.
