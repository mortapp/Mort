# MORT Monochrome Teen Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute this plan task-by-task. Each task begins with a fresh read-only analyst, is implemented by the primary single writer, receives a fresh read-only review, and is committed only after its focused gate passes.

**Goal:** Converge the complete active teen journey to MORT's approved black/white/silver/graphite/cool-blue system while preserving marketplace, safety, privacy, payment, routing, accessibility, and production-isolation behavior.

**Architecture:** Refine production widgets in place and compose the Phase 2 canonical UI primitives. Keep the primary agent as the only writer because the authoritative handoff forbids concurrent worktree writes. Fresh subagents independently inventory and review each bounded slice; they do not edit, commit, switch branches, or mutate external state.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, Material 3, widget tests.

**Spec:** `docs/superpowers/specs/2026-09-09-mort-monochrome-teen-core-design.md`

## Global constraints

- Do not change routes, repositories, providers, backend calls, pagination/session caching, application transitions, polling, proof contracts, PIN behavior, role guards, or location privacy.
- Never imply that a proposed rate, payment preference, pending funding state, or locally completed task is a confirmed payment.
- Use deterministic in-memory test state only. No production Supabase writes, payments, identity verification, push prompts, emergency actions, uploads, or persistent QA accounts.
- Do not enable Google Play reviewer mode or weaken production/default QA and reviewer guards.
- Preserve native controls, semantics/Appium identifiers, keyboard behavior, safe areas, system back, and accessible non-color state labels.
- Keep PR #8 open and unmerged. Do not touch its branch/worktree, `main`, PR #4's dirty checkout, or preserved untracked `work/`. Never force-push.
- Deep Safety Center content remains Phase 5, messaging Phase 7, and financial surfaces Phase 6; this phase verifies their teen route boundaries without duplicating later work.

---

### Task 1: Teen shell and home hierarchy

**Files:**
- Create: `flutter_mort/test/teen_core_visual_convergence_test.dart`
- Modify: `flutter_mort/lib/features/mort_screens.dart` (`RoleHomeScreen` and teen-only helpers)
- Modify only if an observable defect requires it: `flutter_mort/lib/features/teen/teen_shell.dart`
- Modify only for proven large-text defects: `flutter_mort/lib/core/widgets/mort_widgets.dart`, `flutter_mort/lib/core/widgets/mort_liquid_glass.dart`
- Test: `flutter_mort/test/teen_shell_navigation_test.dart`

**Interfaces:**
- Consumes: `TeenShell`, `TeenNavigationScope`, `MortTeenDestinationHeader`, `MortGlassNavigationBar`, canonical cards/state widgets, existing teen home providers.
- Produces: unchanged teen home destinations, navigation history, notification action, current-job/nearby/safety/profile/leaderboard/quick-link behavior.

- [ ] **Step 1: Dispatch a fresh read-only analyst**

  Inventory the teen shell and teen branch of `RoleHomeScreen`, exact route/actions, current legacy tokens, responsive risks, and relevant existing tests. The analyst must not edit the shared worktree.

- [ ] **Step 2: Write RED visual and hierarchy tests**

  Pump the production teen home with deterministic in-memory state at 320×568 and 390×844. Assert canonical teen header/shell behavior, priority order of current status → nearby opportunities → safety/next action, preserved lower-priority links, reduced-motion safety, 200% text behavior, no layout exceptions, and no active `roseGold`/`godPink`/`neon` references in the teen home slice.

- [ ] **Step 3: Verify RED**

  Run `flutter test --no-pub test/teen_core_visual_convergence_test.dart test/teen_shell_navigation_test.dart`. Expect failure on the current teen-home legacy podium/rank treatment or hierarchy contract.

- [ ] **Step 4: Implement the minimum teen-only presentation changes**

  Use the canonical teen destination header, remove redundant dominant branding only in the teen branch, keep current-job and nearby-work sections first, make safety/next action prominent, and visually subordinate growth/leaderboard/ad content without deleting any route or action. Replace non-semantic legacy podium/rank primary colors with neutral silver/graphite hierarchy.

- [ ] **Step 5: Focused verification and fresh review**

  Run the new tests plus `teen_shell_navigation_test.dart`, teen cases in `mort_back_navigation_test.dart`, `physical_rendering_regression_test.dart`, and accessibility/touch-target tests. Dispatch a fresh read-only reviewer against the exact task diff. Repair every Critical or Important finding with a failing test first; rerun until the reviewer reports zero Critical/Important findings.

- [ ] **Step 6: Commit the accepted slice**

  Confirm only intended files are staged and commit coherently, for example `feat(ui): refine teen home hierarchy`. Do not push yet unless recovery safety requires it.

### Task 2: Job discovery, filters, saved jobs, and job detail

**Files:**
- Modify: `flutter_mort/lib/features/jobs/teen_job_screens.dart`
- Modify only if needed for consistent cards: `flutter_mort/lib/features/jobs/job_screens.dart` (`SavedJobsScreen` slice only)
- Modify/Test: `flutter_mort/test/teen_core_visual_convergence_test.dart`
- Test: `flutter_mort/test/job_and_safety_widget_test.dart`
- Test: `flutter_mort/test/marketplace_pagination_test.dart`
- Test: `flutter_mort/test/job_page_session_cache_test.dart`

**Interfaces:**
- Consumes: existing jobs repository/provider, pagination/cache, save/apply mutations, optional approximate-distance service, `MortSearchField`, `MortSelect`, `MortChip`, `MortGlassCard`, and canonical state widgets.
- Produces: unchanged feed, filter, search, pagination, save, detail, and apply behavior with one coherent marketplace visual system.

- [ ] **Step 1: Dispatch a fresh read-only analyst**

  Inventory feed/filter/card/saved/detail states, route actions, provider effects, location handling, legacy tokens, and tests. Require explicit confirmation that discovery never reveals or persists exact coordinates.

- [ ] **Step 2: Write RED discovery tests**

  Assert canonical search/select/filter controls, calm filter expansion, consistent cards, approximate area/distance only, visible title/pay preference/time/category/trust/safety/application signals, empty/loading/error/retry states, saved-state parity, and job-detail hierarchy. Verify 320×568, 200% text, keyboard behavior, and zero active legacy primary references in the rendered discovery/detail slice.

- [ ] **Step 3: Verify RED**

  Run `flutter test --no-pub test/teen_core_visual_convergence_test.dart test/job_and_safety_widget_test.dart test/marketplace_pagination_test.dart test/job_page_session_cache_test.dart`. Expect failure on current job-card/detail legacy accent treatments or non-canonical select presentation.

- [ ] **Step 4: Implement presentation-only convergence**

  Replace legacy decorative accents with silver/graphite/cool-blue semantic treatments and migrate safe wrapper-level dropdown presentation to `MortSelect` without changing native select semantics or filter values. Preserve query construction, pagination, caching, save/apply calls, error handling, exact copy where behavior-sensitive, and approximate-location privacy. Keep the apply action keyboard/safe-area clear.

- [ ] **Step 5: Focused verification and fresh review**

  Run the discovery tests plus route/back, physical rendering, location privacy, and job-profile hardening coverage. Dispatch a fresh read-only reviewer. Repair Critical/Important findings RED-first and rerun all focused checks.

- [ ] **Step 6: Commit the accepted slice**

  Stage only discovery files and commit coherently, for example `feat(ui): converge teen job discovery`.

### Task 3: Applications, lifecycle, progress, and proof

**Files:**
- Modify: `flutter_mort/lib/features/jobs/application_screens.dart`
- Modify: `flutter_mort/lib/features/jobs/job_progress_screen.dart`
- Modify only within the active class: `flutter_mort/lib/features/mort_screens.dart` (`ProofUploadScreen`)
- Modify/Test: `flutter_mort/test/teen_core_visual_convergence_test.dart`
- Test: `flutter_mort/test/application_detail_screen_test.dart`
- Test: `flutter_mort/test/job_progress_widget_test.dart`
- Test: `flutter_mort/test/proof_review_screen_performance_test.dart`

**Interfaces:**
- Consumes: shared role-aware application/progress providers, status timeline, server-owned transitions, polling, proof/evidence APIs, PIN confirmation rules, and canonical state/card/progress components.
- Produces: unchanged application list/detail, accepted/scheduled/in-progress/completed/cancelled/disputed states, progress actions, and proof workflow with clearer truthful hierarchy.

- [ ] **Step 1: Dispatch a fresh read-only analyst**

  Inventory every state/action and its server predicate, cross-role sharing, proof and PIN constraints, payment wording, legacy tokens, performance-sensitive code, and focused tests.

- [ ] **Step 2: Write RED lifecycle tests**

  Assert labeled and non-color-only applied/accepted/scheduled/in-progress/completed/paid-or-payment-preference/cancelled/disputed states; availability and timeline hierarchy; server-confirmed payment truth; fail-closed missing state; proof instructions/status/actions; accessible semantics; and zero active legacy primary references. Cover teen plus representative adult/guardian rendering because the widgets are shared.

- [ ] **Step 3: Verify RED**

  Run `flutter test --no-pub test/teen_core_visual_convergence_test.dart test/application_detail_screen_test.dart test/job_progress_widget_test.dart test/proof_review_screen_performance_test.dart`. Expect failure on current availability/completion/funding/PIN legacy accent treatments.

- [ ] **Step 4: Implement presentation-only convergence**

  Map ordinary lifecycle emphasis to silver/graphite and keep danger/warning/success colors only for semantic states. Use labels/icons/borders in addition to color. Preserve action predicates, optimistic-state rules, repository calls, expected-update timestamps, polling, proof payloads, PIN handling, fail-closed branches, and all payment-truth wording.

- [ ] **Step 5: Focused verification and fresh review**

  Run lifecycle/proof tests plus adult/guardian application regressions, route/back coverage, physical-rendering tests, and the relevant performance budget. Dispatch a fresh read-only reviewer with explicit payment/security review. Repair every Critical/Important finding RED-first and rerun.

- [ ] **Step 6: Commit the accepted slice**

  Stage only lifecycle/proof files and commit coherently, for example `feat(ui): clarify teen job lifecycle`.

### Task 4: Teen profile, growth tools, and route completion

**Files:**
- Modify: `flutter_mort/lib/features/teen/teen_profile_screen.dart`
- Modify only active classes: `flutter_mort/lib/features/mort_screens.dart` (`SkillsScreen`, `AvailabilityScreen`, `FeatureChecklist` used by Hustle Academy)
- Modify only active class: `flutter_mort/lib/features/mission/mission_pilot_screens.dart` (`EarningsGoalsScreen`)
- Modify/Test: `flutter_mort/test/teen_core_visual_convergence_test.dart`
- Test: `flutter_mort/test/profile_persistence_contract_test.dart`
- Test: `flutter_mort/test/video_profile_job_hardening_test.dart`

**Interfaces:**
- Consumes: existing profile providers/repositories, availability/skills/goals state, honest portfolio placeholder, router-owned Hustle Academy checklist, and teen Safety route boundary.
- Produces: unchanged profile/edit/portfolio/skills/availability/goals/academy/safety destinations with coherent monochrome presentation.

- [ ] **Step 1: Dispatch a fresh read-only analyst**

  Inventory every profile/growth route and action, persistence boundary, unavailable portfolio copy, Safety route handoff, academy checklist, legacy tokens, and responsive/accessibility risks.

- [ ] **Step 2: Write RED profile and route-completeness tests**

  Assert the canonical profile header/cards, neutral interest/placeholder treatments, native skills/availability/goals controls, honest portfolio unavailability, retained Hustle Academy items, reachable teen Safety route, every Phase 4 route in the router inventory, 200% text/small viewport stability, and zero active legacy primary references in exact class slices.

- [ ] **Step 3: Verify RED**

  Run `flutter test --no-pub test/teen_core_visual_convergence_test.dart test/profile_persistence_contract_test.dart test/video_profile_job_hardening_test.dart`. Expect failure on the current profile and academy legacy accent treatments.

- [ ] **Step 4: Implement presentation-only convergence**

  Replace non-semantic profile/avatar/interest/checklist accents with canonical graphite/silver hierarchy and migrate wrapper-level selectors to `MortSelect` only where native semantics and values remain identical. Preserve profile persistence, upload behavior, routes, unavailable-feature truth, and every existing action. Do not redesign the Safety Center body in this task.

- [ ] **Step 5: Focused verification and fresh review**

  Run the focused tests plus guardian/profile regressions, route/back tests, physical rendering, touch-target, and accessibility coverage. Dispatch a fresh read-only reviewer. Repair all Critical/Important findings RED-first and rerun.

- [ ] **Step 6: Commit the accepted slice**

  Stage only profile/growth/test files and commit coherently, for example `feat(ui): refine teen profile and growth tools`.

### Task 5: Phase-wide regression, isolation audit, review, and push

**Files:**
- Modify if needed: `docs/superpowers/specs/2026-09-09-mort-monochrome-teen-core-design.md`
- Modify if needed: `docs/superpowers/plans/2026-09-09-mort-monochrome-teen-core.md`
- Update ignored execution evidence: `.superpowers/sdd/2026-09-09-mort-monochrome-teen-core/progress.md`

- [ ] **Step 1: Audit scope and route completeness**

  Diff Phase 4 against its starting SHA. Prove every listed teen route is accounted for, all actions remain wired, and no backend/migration/repository/provider/router/release/lock file changed unless explicitly required and independently reviewed. Confirm zero active `roseGold`, `godPink`, or non-semantic `neon` references in exact Phase 4 rendered slices and record the repository-wide remaining count for later phases.

- [ ] **Step 2: Run fresh verification**

  Run `dart format lib test integration_test`, rerun it to prove no changes, `flutter analyze --no-pub`, the entire `flutter test --no-pub` suite, and `flutter build apk --debug`. Record pass/fail counts, duration, artifact path, size, and SHA-256. Run the protected default/release QA and reviewer-mode guard tests, including proof that QA mode cannot activate in production/default configuration.

- [ ] **Step 3: Security and production-isolation review**

  Inspect the exact phase diff for secrets, privileged keys, external writes in tests, client-trusted auth/payment state, weakened role/RLS assumptions, precise-location leakage, QA/reviewer exposure, real payment or identity paths, and dependency/lock changes. Use repository scanners when available and record any unavailable tool plus the fallback evidence.

- [ ] **Step 4: Fresh whole-phase review**

  Dispatch a fresh read-only reviewer over all Phase 4 commits and acceptance criteria. Repair every Critical/Important finding with a failing regression first; rerun affected focused tests and the full gate after any production change. Do not accept vague approval without file/line evidence and explicit severity counts.

- [ ] **Step 5: Verify branch and PR safety, then push**

  Confirm the worktree is clean, commits are coherent, PR #8 is still OPEN and UNMERGED with its original head/base, and no protected checkout or preserved `work/` was touched. Push `design/mort-monochrome-flutter-convergence` normally, verify local and remote SHA equality and ahead/behind 0/0, and do not merge or force-push.
