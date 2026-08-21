# MORT Liquid Glass UI Implementation Report

> **UPDATE (2026-08-20)**: The rose-gold palette this report describes is
> still canonical (a same-night "Royal" rebrand was reverted after owner
> feedback). Separately, real backdrop blur (`allowAndroidBlur`) was
> enabled for `MortGlassHeader`/`MortGlassNavigationBar`/`MortGlassSheet`
> this same night -- those chrome surfaces had been requesting blur since
> this report but silently rendering flat translucency on Android instead.
> See `docs/MORT_DESIGN_SYSTEM.md`.

Updated: 2026-08-08

## Result

The authoritative Flutter application uses one shared, selective Liquid Glass
system rather than page-specific blur effects. The implementation translates
the supplied HTML/design references into production widgets, GoRouter routes,
role guards, repository-backed states, and accessibility preferences.

Key checkpoints:

- `91904ed` - shared Liquid Glass components and Samsung-safe fallback
- `a322e62` - routable Teen glass destinations
- `042116b` - Teen destinations connected to production flows
- `08684c5` - unified public authentication experience
- `6545efc` - Adult, Guardian, and Admin dashboard polish
- `d487135` - grouped settings and persisted experience preferences
- `ef1cbdd` - protected messaging context and recovery states
- `214ed2a` - Safety Center and route/action completion

## Shared System

`flutter_mort/lib/core/widgets/mort_liquid_glass.dart` owns the glass material,
border, shadow, blur, and reduced-transparency behavior. Shared controls and
states live in `mort_widgets.dart` and `mort_design_components.dart`; role
screens consume those components instead of creating independent visual rules.

The palette uses onyx/graphite content surfaces, rose-gold primary actions,
baby-blue information and safety states, emerald success/verification, amber
warnings, and red only for destructive or urgent actions. Spacing, radii,
typography, motion, and control dimensions remain centralized under
`lib/core/theme`.

## Performance And Accessibility

- Android uses a lower-cost frosted fallback instead of stacking expensive
  live blur across scrolling content.
- High-volume job, message, and dashboard lists use efficient opaque or lightly
  translucent surfaces.
- Reduced motion, reduced transparency, increased contrast, and haptic choices
  persist locally and are exposed in Settings.
- Practical touch targets are at least 48 logical pixels; icon-only controls
  carry tooltips and semantic labels.
- Narrow Samsung and large-text tests cover role dashboards, PIN entry, money,
  navigation, and core controls.
- Loading, empty, retry, confirmation, restricted, and failure states use shared
  components and truthful provider boundaries.

## Navigation And Functionality

The generated `0.9.14+104` route inventory contains 198 authoritative Flutter
routes with no unresolved builders. Teen primary destinations use a guarded
stateful shell with preserved branch state. Adult, Guardian, Admin, Support,
messages, settings, safety, legal, and account routes remain real destinations;
the visual system does not replace server authorization or RLS.

Static action auditing scans 160 Flutter files, 205 route patterns, 330 static
navigation targets, and nine action-widget types. No unresolved route target or
inert production action was reported by the current audit.

## Verification

- `flutter analyze`: zero issues
- `flutter test`: 349 passed, two intentional provider-gated skips, zero failed
- Liquid Glass focused tests: Android fallback, reduced transparency, reduced
  motion, centralized colors, narrow layouts, and finite animation matrices
- Role/navigation focused tests: state preservation, visible/system Back parity,
  dashboard grouping, and large-text layout

Automated tests do not prove visual smoothness on every GPU. Final signed-build
scrolling, TalkBack, font-scale, background/resume, and thermal performance must
still be checked on the Samsung SM-A146U and any additional target devices.

