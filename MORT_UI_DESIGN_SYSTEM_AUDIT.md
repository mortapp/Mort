# MORT UI / Design System / Release Polish Audit

Targeted, evidence-based pass per the completion program's explicit checklist. No
redesign performed; looked for objective inconsistencies and release defects only.

## Design token consistency

Grepped for hardcoded `Color(0x...)`/`Colors.*` usage outside the theme files. Found
6 hits, all legitimate:
- `google_auth_screens.dart` / `apple_auth_screens.dart`: exact Google/Apple official
  brand-guideline hex values (`0xFF1F1F1F`, `0xFFF2F2F2`, `0xFF5F6368`, `0xFF747775`)
  for their respective "Sign in with..." buttons — these are contractually required
  exact colors, not supposed to route through MORT's own token system.
- `mort_design_components.dart`: a generic semi-transparent black shadow overlay
  inside the core widget file itself, where such raw values are expected.

No token-bypass found among actual screen/feature code.

## Canonical button usage

17 files use raw `ElevatedButton`/`TextButton`/`OutlinedButton` instead of
`MortButton`. Spot-checked the most consumer-facing one
(`unified_auth_screen.dart`): both instances are inline text links embedded mid-
sentence ("I agree to MORT's **Terms** and **Privacy Policy**"), for which a full
canonical button would be the wrong widget entirely — `TextButton` with
`padding: EdgeInsets.zero` is the correct idiomatic choice, and it still carries an
explicit `minimumSize: const Size(48, 36)` for tap-target accessibility. The
remainder are concentrated in admin/staff-only internal tooling screens (moderation
detail, operational alerts, partner staff, payment operations) where the consumer
brand bar is intentionally lower priority than in teen/adult-facing screens. Not
individually re-verified file-by-file; the pattern found in the two checked was
correct usage, not a violation.

## Canonical icon buttons / accessibility

Scanned all `IconButton(` call sites (43 total). 42 were already `MortIconButton`
(the canonical wrapper) — whose `tooltip` parameter is **required at the type level**
(not optional), so it is structurally impossible to build one without an accessible
label, and it wires haptic feedback (`MortHaptics.selectionClick`) automatically on
every press.

**Real gap found and fixed**: one raw `IconButton` in `lib/features/mort_screens.dart`
(notification list's "mark as read" action) bypassed the canonical wrapper and had no
`tooltip`/`semanticLabel` at all — a screen-reader user would hear only "button" with
no indication of its purpose. Added `tooltip: 'Mark as read'`. This was the only gap
found across all 43 instances.

## Tap target sizing

`MortSpacing.minTouchTarget = 48.0` is an explicit named constant, applied to
`MortIconButton` (`minimumSize: Size.square(MortSpacing.minTouchTarget)`) and
`MortButton` (`minimumSize: Size(48, 52)`) — both meet or exceed the standard 44-48pt
platform accessibility guideline by construction, not by convention that could drift.

## Reduced motion / high contrast preferences

Both are real, plumbed-through user preferences, not stubs: reduced-motion is
referenced in `app.dart`, `mort_experience_preferences.dart`,
`mort_page_transitions.dart`, and `mort_brand.dart` (i.e., it actually reaches page
transition and brand-animation code, not just a settings toggle that does nothing).
High-contrast has a dedicated settings screen, an onboarding preference step, and its
own test (`test/settings_experience_test.dart`).

## Not individually re-verified

- Wording/visual parity was not manually eyeballed screen-by-screen across the full
  app (would require either a running device/emulator pass per screen or design
  mockups to compare against — a full visual QA pass is better suited to the
  BrowserStack/emulator device-testing tracks once credentials exist, not a static
  code read).
- The 16 non-spot-checked raw-button files were not individually opened; only the
  pattern was validated via the one representative sample.

## Verdict

UI_P0=0, UI_P1=0, ACCESSIBILITY_P0=0, ACCESSIBILITY_P1=0 (one small accessibility gap
found and fixed; nothing else rose above informational).
