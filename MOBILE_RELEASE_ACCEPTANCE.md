# MORT Mobile Release Acceptance

**Assessment date:** 2026-11-08
**Repository:** `mortapp/Mort`
**Release code:** `codex/production-prelaunch-android-gate`, `941d5324011ad48b9afb011047142d5b5f1701c5`
**PR:** [#72](https://github.com/mortapp/Mort/pull/72), draft and stacked on PR #69

## Android artifact

| Property | Verified result |
|---|---|
| Artifact | `C:\Users\micha\mort-web-main\mort-worktrees\mobile-release-validation\build\play\mort-production-public-0.9.16-111.aab` |
| Package | `com.mortapp.mobile` |
| Version | `0.9.16+111` |
| Size | 84,049,810 bytes |
| SHA-256 | `0EC6E2EFD4A6FF5BAC98AD33C7F73E40F169BF6740786556075467B9648808B7` |
| Supabase target | `jxbnrkasktbhtiujkhay` |
| Profile | `production_prelaunch`, stage `production_public` |
| SDK | min 24, target 36 |
| Signing | Signed; `verify-play-aab.ps1` matched the signature to the protected local MORT upload certificate |
| Certificate SHA-256 | `04:42:C2:21:38:B0:D6:23:F9:A6:F4:78:1A:44:2B:F4:A9:33:27:8F:AB:8E:85:76:74:4D:C1:FD:7C:33:4D:EF` |

The artifact manifest records `gitDirty=false` at the stated commit. The AAB was rebuilt and the official repository verifier passed. A Java `jarsigner -strict` invocation reports that the signing certificate is self-signed and lacks a timestamp; normal signature verification and the repository verifier passed. The signer matches the local protected upload certificate, but the Play Console upload/App Signing relationship has not been compared.

This is a signed **prelaunch** artifact. It is not evidence of public activation, legal approval, Play review, a device test, or production launch. Do not upload it to a public production track without the required approval.

## Fail-closed runtime configuration

The manifest records marketplace publishing, real identity/document verification, marketplace payments, public activation, Google auth, remote push/crash reporting, AI, ads, and IAP disabled. Deterministic support fallback is enabled. The Supabase production target is the authoritative project. The read-only server release-status check also returned marketplace and real document collection false.

## Automated results

- CI run [42535222096](https://github.com/mortapp/Mort/actions/runs/42535222096): Flutter authoritative, public-site, Expo-reference, Stripe contracts, Android device-test APK package, local Stripe regression, and Stripe security-freeze passed. Hosted Stripe regression and Stripe provider E2E were skipped.
- Full Flutter suite: **617 passed, 2 skipped, 0 failed**.
- Flutter formatting and analyzer passed.
- Repository AAB verifier passed signature, package, version, SDK, forbidden-permission, exported-component, and artifact checks.
- The device-test APK CI job is packaging only. Local `adb devices` showed no attached physical device.

## Android acceptance not run

No physical device was attached, so fresh install, auth/session flows, deep links, permission prompts, network loss/recovery, retry behavior, job and safety workflows, accessibility, and crash-free navigation remain unverified. No hosted authenticated test was claimed.

## iOS status and requirements

Static project configuration identifies bundle ID `com.mortapp.mobile`, deployment target iOS 18.0, Automatic code signing, and callback URL metadata. No Xcode build/archive or iOS device acceptance ran on this Windows host.

An authorized release operator needs:

1. macOS host with a supported Xcode and CocoaPods/Flutter toolchain.
2. Apple Developer team access, distribution certificate, provisioning profile or authorized automatic signing, and App Store Connect app record matching `com.mortapp.mobile`.
3. Verify entitlements, URL schemes, privacy usage descriptions, associated domains, notification configuration, production Supabase target, and legal version values before archiving.
4. Build/archive, sign, export, verify certificate/profile/bundle ID, then run on a real iOS device. Do not fabricate an archive or signing status.

## Release recommendation

**Android artifact: built and locally signature-verified for controlled prelaunch review. Mobile release: NOT READY for public distribution.** Remaining blockers: legal approval/final content, Google OAuth configuration and sign-in verification, backend authenticated acceptance, Play Console certificate match, physical Android testing, iOS archive/device validation, and approved operational support.
