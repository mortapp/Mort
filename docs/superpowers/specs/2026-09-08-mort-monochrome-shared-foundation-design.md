# MORT Monochrome Shared Foundation Design

## Authority

This design distills the approved convergence directive and the v0 reference documents for Phase 2. The production Flutter application remains the behavioral authority; the user's reference image/recording is the visual authority; `design/mort-monochrome-mobile-v0` is secondary implementation guidance.

## Objective

Create one canonical, production-safe Flutter visual foundation for the entire MORT app: near-black space, graphite surfaces, cool white and metallic silver typography and controls, and only restrained cool-blue informational accents. Existing widgets evolve in place so feature routes can converge without changing navigation, business logic, backend contracts, safety affordances, QA isolation, or accessibility identifiers.

## Architecture

- `MortSpaceBackground` is a single deterministic painter-backed atmosphere. It uses seeded/precomputed stars and sparse constellation geometry, has no network or feature dependencies, and retains a static composition when animations are disabled.
- `MortBrandMark` remains the canonical logo implementation and gains the public `MortLogo` name without duplicating visual logic. It uses the approved monochrome asset and preserves a semantic image label. `MortAnimatedBrandMark` uses shared motion tokens and reveals immediately under reduced motion.
- `MortScreen` remains the route-safe canonical scaffold and gains the public `MortScaffold` name as a compatibility-preserving API. It owns safe areas, keyboard avoidance, mobile gutters, optional scrolling, bottom navigation, and the space background; it must not own auth, repositories, feature state, or network calls.
- Existing `MortHeader`, cards, buttons, fields, chips, badges, navigation, sheets, and state widgets remain canonical. Missing Phase 2 names are thin semantic wrappers or extensions around those implementations, not parallel component systems.
- All new decorative rendering is isolated behind `RepaintBoundary`. No hundreds-of-widget star field, perpetual shimmer, parallax, bounce, spin, or overshoot is permitted.

## Visual Contracts

- Background `#030507`; surface near `#0A0D11`; raised surface near `#10141A`; border near `#27303A`.
- Primary text `#F4F7FB`; muted text `#89939F`; primary action surface near white/silver with dark text.
- Cool blue is reserved for information, safety, location, verification, focus, or a tiny navigation signal.
- Cards use a thin graphite edge, roughly 16px radius, and nearly no shadow. Glass remains opt-in and should not add costly blur to scrolling lists.
- Controls meet at least 44x44 logical pixels, expose clear disabled/focus/error states, and do not rely on color alone for semantic status.
- Headers use a compact letter-spaced eyebrow, refined light-weight white title, and muted supporting copy.

## Compatibility and Safety Contracts

- Preserve `MortScreen` back handling, route fallbacks, iOS gestures, Android back behavior, keyboard dismissal, stage labeling, maximum content width, and the Android bottom-inset floor.
- Preserve existing TextField/TextFormField descendants and labels, including the iOS DOB accessibility representation `Date of birth\nMM/DD/YYYY`; do not mask native editable semantics.
- Preserve haptic preference gating and exactly one haptic layer per action.
- Preserve `SafeSponsoredCard` advertising/safety semantics and all safety, payment, guardian, verification, and danger distinctions.
- Do not change Supabase, migrations, RLS, auth, payments, identity, push, emergency behavior, QA activation, or release configuration.

## Verification

Phase 2 requires deterministic widget tests for the background, reduced motion, logo semantics, scaffold/safe-area behavior, canonical component variants, minimum touch targets, form semantics, navigation state, and overlay layout. Focused tests run after each red-green cycle. Before the phase commit: format, analyze, full Flutter tests, Android debug build, a clean-scope diff audit, and an independent read-only review.
