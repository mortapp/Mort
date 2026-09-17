# MORT iOS V8 Native Build/Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the owner-provided MORT iOS V8 SwiftUI source and produce reproducible simulator build/test evidence on macOS CI.

**Architecture:** Keep the native SwiftUI client isolated under `ios/`, generate the Xcode project deterministically with XcodeGen, and test it without production signing or backend/provider mutation. The shared Supabase/Stripe platform remains authoritative and is not modified by this plan.

**Tech Stack:** Swift 5, SwiftUI, Swift Testing, XCTest, XcodeGen, GitHub Actions macOS runner.

**Spec:** `docs/superpowers/specs/2026-09-17-mort-ios-v8-native-build-design.md`

## Global Constraints

- iOS deployment target is 18.0.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Bundle identifier for build/test is `com.mortapp.mobile`.
- No service-role key, Stripe secret, or other server secret may ship in source.
- Preview mode must remain fail-closed when backend configuration is absent.
- No live Stripe or production release gate mutation is allowed.

---

### Task 1: Import the verified Swift source

**Files:**
- Create: `ios/MORTIOSV8/**/*.swift`
- Create: `ios/MORTIOSV8Tests/MORTIOSV8Tests.swift`
- Create: `ios/MORTIOSV8UITests/*.swift`

**Interfaces:**
- Consumes: exact source blocks from the owner-provided iOS V8 handoff.
- Produces: the full native source tree expected by the generated Xcode targets.

- [x] **Step 1: Extract all 80 `FULL SOURCE` blocks by their `EXACT PATH` values.**
- [x] **Step 2: Verify the extraction count is exactly 80.**
- [x] **Step 3: Run `swiftc -frontend -parse` against every extracted Swift file.**
- [x] **Step 4: Require 80/80 parser successes before repository write.**

### Task 2: Add deterministic Xcode project generation

**Files:**
- Create: `ios/project.yml`

**Interfaces:**
- Consumes: imported Swift source tree.
- Produces: application, unit-test, and UI-test targets under one `MORTIOSV8` scheme.

- [x] **Step 1: Define the iOS 18 application target and build settings.**
- [x] **Step 2: Define Swift Testing unit-test and XCTest UI-test targets.**
- [x] **Step 3: Keep signing/provider/backend configuration out of the generated project.**

### Task 3: Add native macOS CI

**Files:**
- Create: `.github/workflows/mort-ios-v8-native.yml`

**Interfaces:**
- Consumes: `ios/project.yml` and the native source tree.
- Produces: build, unit-test, and launch-smoke evidence from an iOS simulator.

- [x] **Step 1: Install XcodeGen on a macOS runner and generate the Xcode project.**
- [x] **Step 2: Select and boot an available iPhone simulator dynamically.**
- [x] **Step 3: Build the app with signing disabled.**
- [x] **Step 4: Run `MORTIOSV8Tests`.**
- [x] **Step 5: Run the UI-test launch smoke.**
- [x] **Step 6: Upload the `.xcresult` bundles on both success and failure.**

### Task 4: Verify CI evidence

**Files:**
- No production source changes expected unless CI exposes a real compile/test defect.

**Interfaces:**
- Consumes: GitHub Actions run output.
- Produces: an evidence-backed PASS or a concrete failing compiler/test diagnostic.

- [ ] **Step 1: Wait for the native iOS workflow on the integration branch.**
- [ ] **Step 2: Inspect the workflow conclusion and failing log step if any.**
- [ ] **Step 3: If red, make the smallest source/project fix supported by the compiler/test evidence and rerun.**
- [ ] **Step 4: Do not declare build/test complete until the macOS workflow is green.**
