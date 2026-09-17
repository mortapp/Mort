# MORT iOS V8 Native Build Design

**Status:** Owner-approved for build/test execution  
**Date:** 2026-09-17  
**Source authority:** `MORT_IOS_V8_COMPLETE_INTEGRATION_HANDOFF.txt` supplied by the owner  
**Production activation:** Not part of this work

## Goal

Place the complete MORT iOS V8 SwiftUI source in the MORT repository as an independently buildable native iOS project and establish reproducible macOS CI evidence for app compilation, unit tests, and a minimal UI launch smoke test.

## Boundaries

- The existing Supabase backend remains business, security, and financial authority.
- Stripe remains provider authority.
- This build/test pass does not wire live Supabase RPCs, Stripe PaymentSheet, APNs, camera/photo capture, TestFlight, production signing, or live payment credentials.
- Missing runtime backend configuration must continue to fail closed into the handoff's explicit preview mode.
- No service-role, Stripe secret, or other server credential may be placed in the iOS source or CI workflow.
- The native app bundle identifier for build/test is `com.mortapp.mobile`.

## Source layout

The 80 Swift files embedded in the handoff are imported verbatim under `ios/`:

- `ios/MORTIOSV8/` — application source
- `ios/MORTIOSV8Tests/` — Swift Testing unit suite
- `ios/MORTIOSV8UITests/` — XCTest UI smoke scaffolding

The generated code is treated as imported source rather than rewritten during this pass. All behavioral integration work remains a later shared-backend phase.

## Project generation

The handoff contains complete Swift source but not an Xcode project file. The repository therefore stores `ios/project.yml` as the deterministic project definition and generates `MORTIOSV8.xcodeproj` with XcodeGen on macOS CI.

Configuration:

- iOS deployment target: 18.0
- Swift language version: 5.0
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- iPhone target family
- generated Info.plist
- camera/photo usage strings from the handoff
- application bundle ID `com.mortapp.mobile`

The generated `.xcodeproj` is a build artifact and is not committed.

## Verification

Verification occurs in three layers:

1. Linux-side Swift parser pass over all 80 Swift files to catch syntax corruption during extraction.
2. macOS GitHub Actions app build and Swift unit-test execution on an available iPhone simulator.
3. Minimal UI-test launch smoke to prove the generated project can install and launch the app target in the simulator.

CI uses `CODE_SIGNING_ALLOWED=NO` and performs simulator-only validation; it does not create a distributable signed build.

## Acceptance

This phase passes only when macOS CI reports:

- Xcode project generation succeeds;
- native app target builds for an iOS simulator;
- `MORTIOSV8Tests` passes;
- the UI launch smoke passes;
- no secret is added to repository source;
- no production backend/payment gate is changed.
