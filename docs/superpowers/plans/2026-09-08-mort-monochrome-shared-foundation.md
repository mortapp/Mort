# MORT Monochrome Shared Foundation Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development task-by-task and superpowers:verification-before-completion before every commit/progression claim. Preserve the single-writer rule; use fresh read-only subagents for review gates.

**Goal:** Complete Phase 2 by evolving MORT's existing Flutter primitives into the canonical monochrome visual foundation used by every later screen-convergence phase.

**Architecture:** Add one deterministic painter-backed space background, expose compatibility-preserving canonical names around existing brand/scaffold/state APIs, and refine existing tokens/components rather than starting a second design system. All changes stay inside Flutter presentation/theme code and tests; route, data, auth, safety, QA, and backend behavior remain unchanged.

**Tech Stack:** Flutter, Dart, Material 3, `CustomPainter`, widget tests.

**Spec:** `docs/superpowers/specs/2026-09-08-mort-monochrome-shared-foundation-design.md`

---

### Task 1: Deterministic space background

**Files:**
- Create: `flutter_mort/lib/core/widgets/mort_space_background.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_widgets.dart`
- Test: `flutter_mort/test/mort_space_background_test.dart`

1. Write widget/painter tests proving the same seed and size produce the same sparse star/constellation composition, a different seed changes it, the painter is isolated by `RepaintBoundary`, and reduced motion creates no active decorative ticker.
2. Run `flutter test --no-pub test/mort_space_background_test.dart`; confirm RED because the canonical component does not exist.
3. Implement immutable composition generation and a `CustomPainter` using MORT background/silver/accent tokens. Keep density low, sizes tiny, cool-blue points rare, repaint decisions value-based, and motion absent unless a later approved phase explicitly needs it.
4. Export the component through `mort_widgets.dart` and replace `MortScreen`'s gradient-only root decoration with `MortSpaceBackground` without disturbing its existing navigation/safe-area tree.
5. Re-run the focused test and existing back/navigation tests; confirm GREEN.

### Task 2: Canonical logo and motion contracts

**Files:**
- Modify: `flutter_mort/lib/core/theme/mort_tokens.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_brand.dart`
- Test: `flutter_mort/test/mort_brand_foundation_test.dart`
- Test: `flutter_mort/test/mort_redesign_test.dart`

1. Write tests proving `MortLogo` uses the approved monochrome asset, preserves the image semantic label and optional wordmark, clamps invalid dimensions, and reveals without an animation/ticker when `MediaQuery.disableAnimations` is true.
2. Run the focused brand test; confirm RED because `MortLogo` is not exposed and reduced-motion construction still starts the controller.
3. Add canonical motion durations/easing helpers matching micro/control/content/reveal timing. Evolve `MortBrandMark` behind a public `MortLogo` API and prevent decorative animation from starting when reduced motion is active, while preserving existing callers.
4. Run the focused tests and `flutter test --no-pub test/mort_redesign_test.dart`; confirm GREEN.

### Task 3: Scaffold and header convergence

**Files:**
- Modify: `flutter_mort/lib/core/widgets/mort_widgets.dart`
- Test: `flutter_mort/test/mort_scaffold_foundation_test.dart`
- Test: `flutter_mort/test/mort_back_navigation_test.dart`

1. Write tests proving the public `MortScaffold` contract retains SafeArea, max width, configurable gutters, scrolling, bottom slot, keyboard dismissal, header-aware back behavior, and Android bottom clearance. Add a large-text/narrow-screen header test.
2. Run the focused scaffold test; confirm RED because the public canonical API and the expected refined header treatment are absent.
3. Evolve `MortScreen` into the implementation-compatible `MortScaffold` API without changing routing logic. Refine `MortHeader` eyebrow/title/subtitle styling from shared tokens and preserve existing `MortScreen` callers.
4. Run scaffold, back-navigation, and teen-shell navigation tests; confirm GREEN.

### Task 4: Cards, buttons, toggles, chips, badges, and states

**Files:**
- Modify: `flutter_mort/lib/core/theme/mort_tokens.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_widgets.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_design_components.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_liquid_glass.dart`
- Test: `flutter_mort/test/mort_component_foundation_test.dart`
- Test: `flutter_mort/test/mort_haptics_microinteraction_test.dart`

1. Write tests for observable behavior: card border/radius and tap semantics; primary/secondary/tertiary/destructive/loading/disabled buttons; minimum touch size; one preference-gated haptic activation; toggle semantics and non-semantic active color; compact badge/chip legibility; and loading/empty/error/status state differentiation at large text.
2. Run the new focused test; confirm RED on missing canonical variants/components.
3. Evolve existing canonical widgets. Add `tertiary` while retaining `ghost` compatibility, add `MortToggle` and `MortStatusCard`, keep glass blur opt-in, use shared surface/border/radius tokens, and provide canonical `MortLoadingState` compatibility without duplicating rendering.
4. Keep destructive red and other semantic colors only where meaning requires them; remove legacy alias use from shared primary visuals.
5. Run focused component, haptic, redesign, and liquid-glass tests; confirm GREEN.

### Task 5: Form, navigation, and overlay foundation

**Files:**
- Modify: `flutter_mort/lib/core/widgets/mort_widgets.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_design_components.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_liquid_glass.dart`
- Test: `flutter_mort/test/mort_form_navigation_overlay_test.dart`
- Test: `flutter_mort/test/compact_onboarding_test.dart`
- Test: `flutter_mort/test/teen_shell_navigation_test.dart`

1. Write tests proving password/date/select/text-area/search fields keep native editable/select semantics, focus/error/disabled states, and the DOB label/hint contract. Test monochrome active/inactive bottom navigation while preserving selected index and callback. Test modal/sheet safe-area, keyboard, large-text, and danger confirmation behavior.
2. Run the focused test; confirm RED on missing canonical field/overlay wrappers or incorrect visual behavior.
3. Add thin, behavior-preserving canonical wrappers where required: `MortPasswordField`, `MortDateField`, `MortSelect`, and `MortModal`/sheet helpers. Do not wrap editable children in semantics containers that obscure the native node. Converge existing navigation and overlay styles to graphite/silver with tiny optional cool-blue signal.
4. Do not create a fake `MortMessageComposer`; first locate and adapt the production messaging composer in Phase 7 unless it can safely delegate to a shared field without changing its behavior.
5. Run focused form/navigation/overlay tests plus onboarding and teen-shell regressions; confirm GREEN.

### Task 6: Phase gate, independent review, and atomic delivery

**Files:**
- Modify: `.superpowers/sdd/2026-09-08-mort-monochrome-flutter-convergence/progress.md`
- Modify only if findings require it: Phase 2 production/test files above

1. Run `dart format lib test integration_test`, then `dart format --output=none --set-exit-if-changed lib test integration_test` and confirm exit 0. This also resolves the pre-existing format mismatch in `mort_liquid_glass.dart` transparently.
2. Run `flutter analyze --no-pub` and `flutter test --no-pub`; capture exact passed/skipped/failed counts.
3. Run `flutter build apk --debug`; confirm exit 0.
4. Audit `git diff --check`, `git status --short`, production-file scope, legacy shared primary color references, QA/release guards, and absence of backend/migration changes.
5. Dispatch a fresh read-only reviewer with the Phase 2 spec, plan, base SHA `d840c5a33356fb2691a00ed74f11445592cb9d3c`, and current diff. Repair every Critical/Important finding using failing tests first; rerun focused and full verification.
6. Update the durable ledger with exact results and remaining route/rose-gold metrics.
7. Commit coherently as `feat(theme): build monochrome MORT visual foundation` and push normally to `origin design/mort-monochrome-flutter-convergence`. Do not merge or modify PR #8.
