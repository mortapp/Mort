# MORT Mobile UI/UX Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the production Flutter app with the supplied MORT prototype across Android and iOS without changing authorization, backend behavior, or disabled release controls.

**Architecture:** Use Flutter's shared theme and reusable component layer as the cross-platform design authority, then migrate route families in small slices. Keep the prototype as a visual reference only and preserve existing repositories, RPCs, role guards, and fail-closed states.

**Tech Stack:** Flutter/Dart, Material 3 theme tokens, widget tests, existing Supabase-backed repositories.

**Spec:** `docs/MORT_UI_UX_PROTOTYPE_ALIGNMENT.md`, based on the supplied `MORT — Interactive Product Prototype.md`, PDF notes, screenshots, and source archive.

## Global Constraints

- Production client is `flutter_mort`; it is shared by Android and iOS.
- Use the provided monochrome design with semantic green, amber, and red only.
- Remove starfield, decorative glow, content blur, and content shadows from active product screens.
- Keep all safety, verification, role-access, and backend response gates intact.
- Do not enable marketplace publishing, document collection, payments, Stripe, or AI.
- Do not use prototype demo data, demo PINs, mock payment success, or fabricated verification states.
- Do not change website, production Supabase, or hosted QA.

## Review Focus

- Any action hidden by larger text, keyboard, safe area, or 390 x 844 viewport must remain reachable; verify responsive and accessibility widget tests.
- Pending and failed network operations must keep their real status and retry affordance; verify the screen continues to use repository outcomes.
- Emergency/destructive actions must remain more distinct than ordinary status color; verify semantics and contrast tests.
- Private addresses and Guardian-only values must not appear in newly composed cards or sheets; verify existing privacy/authorization widget assertions.
- Android and iOS should share geometry while using native system insets and back behavior; verify platform parity tests and explicitly leave macOS archive/device validation for its authorized host.

---

### Task 1: Establish the prototype design tokens

**Files:**
- Modify: `flutter_mort/lib/core/theme/mort_colors.dart`
- Modify: `flutter_mort/lib/core/theme/mort_typography.dart`
- Modify: `flutter_mort/lib/core/theme/mort_spacing.dart`
- Modify: `flutter_mort/lib/core/theme/mort_tokens.dart`
- Test: `flutter_mort/test/prototype_ui_theme_test.dart`

- [ ] Write tests for the prototype palette, neutral surfaces, 16/20 px spacing, 12–18 px radii, semantic state colors, and typography scale.
- [ ] Run the focused test and confirm it fails on the legacy palette.
- [ ] Implement tokens and local typography setup without changing screen behavior.
- [ ] Run the focused test and existing token/theme tests.

### Task 2: Align app chrome and shared components

**Files:**
- Modify: `flutter_mort/lib/core/theme/mort_theme.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_space_background.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_liquid_glass.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_widgets.dart`
- Modify: `flutter_mort/lib/core/widgets/mort_design_components.dart`
- Modify: `flutter_mort/lib/app.dart`
- Test: existing component, glass, navigation, and space-background tests

- [ ] Write/update focused widget tests for light/dark theme selection, flat headers/cards/navigation, sheet elevation, and absence of decorative star/glow rendering.
- [ ] Confirm the new expectations fail against the current UI.
- [ ] Update theme and shared chrome while retaining component APIs so existing screen logic does not need wholesale rewrites.
- [ ] Run focused tests, then analyzer and formatting.

### Task 3: Migrate teen discovery and job detail

**Files:**
- Modify: `flutter_mort/lib/features/teen/teen_shell.dart`
- Modify: `flutter_mort/lib/features/jobs/teen_job_screens.dart`
- Test: `flutter_mort/test/teen_core_visual_convergence_test.dart`, `flutter_mort/test/job_and_safety_widget_test.dart`

- [ ] Assert teen home order is Up Next, quick jobs, and nearby results; verify neutral job cards and apply states.
- [ ] Recompose discovery and detail surfaces with the shared job-card/sheet pattern, keeping current repository loading, error, filters, and application checks.
- [ ] Run focused tests and analyze all changed Dart files.

### Task 4: Migrate active work, safety, and completion

**Files:**
- Modify: `flutter_mort/lib/features/jobs/job_progress_screen.dart`
- Modify: `flutter_mort/lib/features/jobs/proof_review_screen.dart`
- Modify: `flutter_mort/lib/features/safety/trust_safety_screens.dart`
- Test: `flutter_mort/test/job_progress_widget_test.dart`, `flutter_mort/test/safety_circle_lifecycle_test.dart`, relevant privacy tests

- [ ] Cover checklist gating, server-backed Start/Finish PIN, emergency hold, sharing disclosures, evidence grid, and disabled/retry states.
- [ ] Migrate layouts without weakening release conditions or exposing private coordinates.
- [ ] Run focused safety and job tests.

### Task 5: Migrate poster, money, Guardian, and moderator surfaces

**Files:**
- Modify only existing screen files for adult job management, applications, financial/wallet/receipt, Guardian, and moderation routes.
- Test: existing job creation, application, Guardian, payment-safety, and moderation widget tests.

- [ ] Align poster priority order, posting flow, applicant comparison, wallet rows, receipt hierarchy, Guardian notices, and moderator case/audit layouts.
- [ ] Preserve authorization boundaries, disabled payment actions, and actual server outcomes.
- [ ] Run focused tests per family.

### Task 6: Finish onboarding, messaging, and remaining shared routes

**Files:** onboarding, profile, inbox/chat, settings, support, verification, legal, and shared screen components under `flutter_mort/lib/features/`.

- [ ] Map each existing production route to a prototype pattern or document a deliberate exception.
- [ ] Apply shared spacing, typography, surface, loading/empty/error states, accessibility labels, and role-aware navigation.
- [ ] Keep verification and legal flows fail-closed when provider evidence or approved legal versions are absent.
- [ ] Run focused route, auth, messaging, privacy, and accessibility tests.

### Task 7: Cross-platform verification and handoff

**Files:**
- Update: `docs/MORT_DESIGN_SYSTEM.md`
- Update: `docs/MORT_UI_UX_PROTOTYPE_ALIGNMENT.md`
- Test: Flutter suite, Android build checks, existing Android/iOS parity tests.

- [ ] Run Flutter format, analyzer, full test suite, Android debug/release configuration checks where signing/legal gates allow, and route screenshots at 390 x 844.
- [ ] Verify the same Flutter route widgets and tokens are used for both platforms; run Android/iOS platform-parity tests.
- [ ] Record that iOS archive and physical-device acceptance require an authorized macOS/Xcode host if unavailable here.
- [ ] Summarize changed screens, tests, and any remaining platform acceptance dependency.
