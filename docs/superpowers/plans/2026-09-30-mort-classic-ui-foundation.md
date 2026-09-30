# MORT Classic UI Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. This repository requires one agent; do not delegate. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the global dark/atmospheric presentation with one readable classic Flutter design system and preserve navigation through role-specific shells.

**Architecture:** Evolve existing theme/color/components in place. Preserve the router paths, guards, repositories and sensitive wrappers. Consolidate bottom navigation into one component used by teen, adult and guardian shells.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-09-30-mort-classic-ui-design.md`

## Global Constraints

- `com.mortapp.mobile`; Flutter remains authoritative.
- No build 115, Play upload, PR merge, production rollout, hosted migration or provider activation.
- Build 114 AAB stays byte-identical.
- RevenueCat/Google Play prices and entitlements remain provider-authoritative.
- Safety, account, payment, and verification guards stay in place.
- White/black/neutrals are the default; semantic color retains meaning.
- Reduced motion, large text, safe areas and screen readers are required.

## Review Focus

- A dark-only widget on a white surface must retain readable contrast; check representative screens after the theme change.
- A nested teen deep link must select the correct bottom tab and preserve the sensitive wrapper.
- Android back from a tab must restore prior tab state rather than exit a Safety flow.
- The keyboard must not cover an action or bottom navigation on a small phone.
- A role mismatch must still show the guarded state, never another role's screen.

---

### Task 1: Freeze the route inventory

**Files:** `docs/ui/MORT_CLASSIC_UI_SCREEN_INVENTORY.md`, `flutter_mort/lib/core/routing/app_router.dart` (read only).

- [ ] Enumerate every literal GoRouter destination and onboarding redirect; record the role and release gates.
- [ ] Enumerate non-router public screen/view classes and modal-entry source files.
- [ ] Check route count against the baseline 217 literal destinations and 11 redirects; correct any extraction error.
- [ ] Commit the inventory before presentation code changes.

### Task 2: Replace global theme and shared surfaces

**Files:** `flutter_mort/lib/core/theme/mort_colors.dart`, `mort_theme.dart`, `mort_typography.dart`, `mort_tokens.dart`, `flutter_mort/lib/core/widgets/mort_widgets.dart`, `mort_design_components.dart`, `flutter_mort/lib/main.dart`, `app.dart`.

**Interfaces:** `MortTheme.classic(): ThemeData`; existing `MortScaffold`, `MortScreen`, `MortHeader`, buttons, fields, cards retain constructor signatures.

- [ ] Add widget tests that assert light theme, black primary CTA, readable field/error colors, white scaffold and reduced-motion behavior.
- [ ] Run focused tests and confirm the current dark presentation fails the new assertions.
- [ ] Implement classic tokens and ThemeData; update app entry points to use `MortTheme.classic()`.
- [ ] Remove production atmosphere/glow from shared scaffolds/cards while preserving back, keyboard and safe-area contracts.
- [ ] Run focused tests, `dart format`, `flutter analyze`, then commit.

### Task 3: One accessible bottom navigation component

**Files:** `flutter_mort/lib/core/widgets/mort_design_components.dart`, `mort_liquid_glass.dart`, `flutter_mort/lib/features/teen/teen_shell.dart`, `flutter_mort/lib/core/routing/app_router.dart`.

**Interfaces:** `MortBottomNavigation` accepts selected index, `MortNavigationDestination` list and selection callback; active item has semantic selected state and subtle elevation.

- [ ] Add widget tests for five teen/adult labels, four guardian labels, active shadow, 48 px targets, large text and disabled animation.
- [ ] Replace the teen glass bar and reorder teen branches to Home, Jobs, Messages, Safety, Profile without changing route paths.
- [ ] Add adult and guardian role shells only after preserving their existing route/guard/deep-link behavior.
- [ ] Run focused navigation/back/deep-link tests, full Flutter test, Android/iOS parity checks and commit.

### Task 4: Review and certify the foundation slice

**Files:** `docs/ui/MORT_CLASSIC_UI_DESIGN_SYSTEM.md`, inventory statuses, test evidence.

- [ ] Inspect the exact diff for contrast, safety wrapper, route, provider and role regressions.
- [ ] Run `dart format`, `flutter analyze`, `flutter test`, source secret scan and `git diff --check`.
- [ ] Perform sequential Believer, Skeptic, Investor/operations and Judge passes; fix reproducible defects.
- [ ] Update the foundation evidence. Leave later feature routes marked pending until individually reviewed.

The school-email policy and each remaining feature family require separate implementation slices under the same spec. Do not mark the full product code complete when only this foundation passes.
