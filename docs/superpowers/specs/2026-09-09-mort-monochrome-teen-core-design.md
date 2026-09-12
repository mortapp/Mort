# MORT Monochrome Teen Core Design

## Scope

Phase 4 converges the complete active teen experience: `/teen/home`, `/teen/jobs`, `/teen/jobs/:id`, `/teen/saved`, `/teen/applications`, `/teen/applications/:id`, the shared role-aware `/jobs/progress/:applicationId`, `/teen/proof/:applicationId`, `/teen/profile`, `/teen/profile/edit`, `/teen/portfolio`, `/teen/skills`, `/teen/availability`, `/teen/goals`, `/teen/hustle-academy`, and the teen shell entry to `/teen/safety`.

The full Safety Center body is reserved for Phase 5, messaging for Phase 7, and financial surfaces for Phase 6. This phase nevertheless proves that every teen destination remains reachable, visually coherent at its boundary, and honest about unavailable or later-phase capabilities. The approved master directive, the production Flutter application, and the read-only `origin/design/mort-monochrome-mobile-v0` reference are the design authorities, in that order.

## Visual direction

- Use the Phase 2 `MortSpaceBackground`, monochrome navigation, `MortTeenDestinationHeader`, graphite cards, silver hierarchy, canonical fields/selects/chips, restrained progress, and state components.
- Teen home is quiet and action-led: current job status, nearby opportunities, safety status, and the next useful action lead the page. Profile completion, growth links, leaderboard, and advertisements remain available but visually subordinate and below the primary content.
- Job discovery uses one calm search/filter surface and consistent cards. Each job card communicates title, approximate area or distance, pay preference, timing, category, trust/verification, risk or safety, and relevant application state without exposing an exact location.
- Job detail orders trust, pay preference, timing, approximate distance, scope, safety, poster context, and the apply action. A proposed rate or funding state must never be presented as a completed payment.
- Application and job-progress states remain visually distinct through labels, icons, borders, and semantic text—not color alone—for applied, accepted, scheduled, in progress, completed, paid/payment preference, cancelled, and disputed states.
- Teen profile and growth tools reuse the same graphite/silver system. The existing portfolio placeholder remains an honest unavailable-state surface rather than implying a publishing workflow that does not exist.

## Behavior and data boundaries

No route, repository, provider, pagination cursor, cache, mutation, status transition, polling rule, proof payload, PIN rule, location privacy rule, role guard, or backend contract may change. Exact job coordinates remain unavailable in general discovery; optional device location may only improve approximate distance using the existing service, and raw coordinates are not persisted by this presentation work.

All tests and visual fixtures use deterministic in-memory state. They perform no Supabase or other hosted write, payment, identity verification, push prompt, emergency action, or persistent-account creation. Google Play reviewer mode stays disabled and its production/default isolation remains regression-protected. The production/default release configuration exposes no QA harness.

The application continues to distinguish server-confirmed payment state from a payment preference, proposal, pending funding, or locally displayed job status. Proof and progress screens remain fail-closed when server state is missing or inconsistent. Shared adult and guardian application/progress behavior receives focused regression coverage because those widgets are role-aware.

## Accessibility, layout, and motion

- Preserve native editable/select controls, all existing semantics and Appium identifiers, logical focus order, safe areas, shell back behavior, and bottom-action keyboard clearance.
- Every state has a readable label and icon or structural treatment; color is never the only signal.
- Verify 320×568 and 390×844 viewports, 200% text scaling, reduced motion, keyboard-visible layouts, and minimum touch targets.
- Keep decorative stars and constellation details sparse, excluded from semantics, and inexpensive to paint. No new continuous animation is introduced.

## Test strategy

Add focused teen-core visual contract tests first, using production widgets with in-memory provider overrides. Assert observable hierarchy, copy, semantics, route actions, canonical component behavior, privacy wording, and absence of active legacy primary tokens in the exact rendered source slices. Do not use screenshot goldens as the primary acceptance mechanism.

Run existing shell-navigation, marketplace pagination/cache, job-and-safety, application-detail, job-progress, proof, profile, persistence, back-navigation, physical-rendering, accessibility, reviewer-mode, and release-guard regressions. After all slices, run formatting, analysis, the full Flutter suite, the Android debug build, a route-completeness audit, a production-isolation/security audit, and a fresh whole-phase review.

## Acceptance

Phase 4 is accepted when every active teen route is accounted for; all Phase 4 rendered slices use the monochrome foundation with zero active rose-gold primary references; behavior, privacy, payment truthfulness, and cross-role contracts pass; every independently testable slice has been reviewed and committed coherently; the phase-wide Flutter and Android gates pass; the branch is pushed normally; and PR #8 remains open and unmerged.
