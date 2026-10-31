# Remove Space UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Apply the canonical 2026-10-12 MORT visual language to the active Flutter release app and remove decorative star/space backgrounds.

**Architecture:** Keep Flutter as the active release app in this checkout. Apply the attached product and visual requirements through the shared theme, cards, actions, and navigation. Remove visual effects at the shared screen layer so routes cannot reintroduce stars through per-screen atmosphere settings; remove the debug entry point.

**Tech Stack:** Flutter, Dart, existing MORT theme and widget system.

**Spec:** `docs/superpowers/specs/2026-10-12-mort-mobile-ui-ux-design.md`

## Global Constraints

- Preserve existing screen workflows and the supplied `build/ui-preview` artifacts.
- Use the copied 2026-10-12 specification as product source; the preview images are examples.
- Do not change backend, marketplace, publishing, payment, identity, or document-collection behavior.
- Preserve role, age, Guardian, accessibility, and route behavior.
- Do not remove functional rating stars.

## Review Focus

- Light mode remains primary; dark mode remains readable and fully supported.
- Shared surfaces and primary actions use flat theme colors without glass, glow, or metallic gradients.
- Startup/offline/fatal configuration surfaces must use the current theme background.
- User-provided home/explore screenshots and preview data remain unchanged.
- Normal and debug app routes must not expose the space renderer.
- Release safety configuration must remain identical after the UI-only change.

---

### Task 1: Apply the design language to shared app surfaces

**Files:**
- Modify: `flutter_mort/lib/core/widgets/mort_widgets.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_liquid_glass.dart`
- Modify: `flutter_mort/lib/core/routing/app_router.dart`

**Interfaces:** Keep `MortScreen` constructor compatibility while making atmosphere options visually inert.

- [x] Use the theme scaffold color for `MortScreen` in light and dark mode.
- [x] Remove atmospheric background painting and focal layers from `MortScreen`.
- [x] Replace `MortScaffold`'s `MortSpaceBackground` with the theme scaffold surface.
- [x] Remove the debug atmosphere route and import.
- [x] Flatten shared card surfaces for both themes; keep tap targets and semantics.
- [x] Remove metallic gradients/glows from the shared primary action.
- [x] Keep the preview images unchanged; they remain examples under the canonical spec.

### Task 2: Rebuild the signed closed-test AAB from current UI source

**Files:**
- Output: `build/play/mort-closed-test-0.9.17-122.aab`

- [ ] Run `scripts/build-standard-closed-test-aab.ps1` with the existing protected signing credentials after all source changes are final.
- [ ] Independently inspect AAB signature, package/version, checksum, and safety flags.
- [ ] Confirm production database and release controls were not changed.

This plan covers the shared visual foundation and removal of the superseded space artwork. It does not mark all of the much broader workflow requirements in the canonical product specification as implemented.
